import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/deepseek.dart';
import 'models.dart';

/// ============================================================
///  全局状态：角色卡 / 会话 / 用户设定 / API 配置 + 流式对话编排
/// ============================================================
class AppStore extends ChangeNotifier {
  static const _kCards = 'tavern.cards.v1';
  static const _kSessions = 'tavern.sessions.v1';
  static const _kUser = 'tavern.user.v1';
  static const _kApi = 'tavern.api.v1';
  static const _kActive = 'tavern.active.v1';

  SharedPreferences? _prefs;

  final List<CharacterCard> cards = <CharacterCard>[];
  final Map<String, ChatSession> sessions = <String, ChatSession>{};
  UserProfile user = UserProfile();
  ApiConfig api = ApiConfig();
  String? activeCharacterId;

  bool busy = false; // 正在生成
  String? streamingId; // 正在流式写入的消息 id
  String statusText = '';
  StreamSubscription<ChatDelta>? _sub;

  // ------------------------------------------------------------ 初始化
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;

    try {
      final rawCards = p.getString(_kCards);
      if (rawCards != null) {
        cards
          ..clear()
          ..addAll((jsonDecode(rawCards) as List)
              .map((e) => CharacterCard.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}

    try {
      final rawS = p.getString(_kSessions);
      if (rawS != null) {
        sessions.clear();
        for (final e in jsonDecode(rawS) as List) {
          final s = ChatSession.fromJson(Map<String, dynamic>.from(e as Map));
          sessions[s.characterId] = s;
        }
      }
    } catch (_) {}

    try {
      final rawU = p.getString(_kUser);
      if (rawU != null) user = UserProfile.fromJson(Map<String, dynamic>.from(jsonDecode(rawU) as Map));
    } catch (_) {}

    try {
      final rawA = p.getString(_kApi);
      if (rawA != null) api = ApiConfig.fromJson(Map<String, dynamic>.from(jsonDecode(rawA) as Map));
    } catch (_) {}

    activeCharacterId = p.getString(_kActive);
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kCards, jsonEncode(cards.map((c) => c.toJson()).toList()));
    await p.setString(
        _kSessions, jsonEncode(sessions.values.map((s) => s.toJson()).toList()));
    await p.setString(_kUser, jsonEncode(user.toJson()));
    await p.setString(_kApi, jsonEncode(api.toJson()));
    if (activeCharacterId != null) {
      await p.setString(_kActive, activeCharacterId!);
    } else {
      await p.remove(_kActive);
    }
  }

  Future<void> saveAll() => _persist();

  // ------------------------------------------------------------ 角色卡
  CharacterCard? get activeCard {
    final id = activeCharacterId;
    if (id == null) return null;
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  CharacterCard? cardById(String? id) {
    if (id == null) return null;
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> upsertCard(CharacterCard card) async {
    final i = cards.indexWhere((c) => c.id == card.id);
    if (i >= 0) {
      cards[i] = card;
    } else {
      cards.add(card);
    }
    activeCharacterId ??= card.id;
    await _persist();
    notifyListeners();
  }

  Future<void> deleteCard(String id) async {
    cards.removeWhere((c) => c.id == id);
    sessions.remove(id);
    if (activeCharacterId == id) {
      activeCharacterId = cards.isEmpty ? null : cards.first.id;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setActiveCharacter(String id) async {
    activeCharacterId = id;
    await _persist();
    notifyListeners();
  }

  // ------------------------------------------------------------ 会话
  ChatSession sessionFor(String characterId) {
    return sessions.putIfAbsent(characterId, () => ChatSession(characterId: characterId));
  }

  ChatSession? get activeSession {
    final id = activeCharacterId;
    if (id == null) return null;
    return sessionFor(id);
  }

  Future<void> setWorld(String text) async {
    final s = activeSession;
    if (s == null) return;
    s.world = text;
    s.touch();
    await _persist();
    notifyListeners();
  }

  Future<void> clearMessages() async {
    final s = activeSession;
    if (s == null) return;
    s.messages.clear();
    s.touch();
    await _persist();
    notifyListeners();
  }

  // ------------------------------------------------------------ 设定
  Future<void> updateUser(UserProfile u) async {
    user = u;
    await _persist();
    notifyListeners();
  }

  Future<void> updateApi(ApiConfig a) async {
    api = a;
    await _persist();
    notifyListeners();
  }

  // ------------------------------------------------------------ 消息编辑 / 删除
  /// 修改某条消息，并清除它之后的全部内容（从该对话框重新开始对话）
  Future<int> editMessageAt(int index, String newContent) async {
    final s = activeSession;
    if (s == null || index < 0 || index >= s.messages.length) return 0;
    final removed = s.messages.length - index - 1;
    s.messages[index].content = newContent;
    s.messages[index].error = null;
    if (removed > 0) s.messages.removeRange(index + 1, s.messages.length);
    s.touch();
    await _persist();
    notifyListeners();
    return removed;
  }

  /// 删除某条消息，并清除它之后的全部内容
  Future<int> deleteMessageAt(int index) async {
    final s = activeSession;
    if (s == null || index < 0 || index >= s.messages.length) return 0;
    final removed = s.messages.length - index - 1;
    s.messages.removeRange(index, s.messages.length);
    s.touch();
    await _persist();
    notifyListeners();
    return removed;
  }

  Future<void> toggleReasoningAt(int index) async {
    final s = activeSession;
    if (s == null || index < 0 || index >= s.messages.length) return;
    s.messages[index].showReasoning = !s.messages[index].showReasoning;
    await _persist();
    notifyListeners();
  }

  // ------------------------------------------------------------ 提示词组装
  List<Map<String, String>> buildPrompt(ChatSession s, CharacterCard card) {
    final sys = StringBuffer()
      ..writeln('你正在进行沉浸式角色扮演，请始终以指定角色的身份说话。')
      ..writeln()
      ..writeln('【世界背景】')
      ..writeln(s.world.trim().isEmpty ? '（未特别设定，请依据角色设定自然展开。）' : s.world.trim())
      ..writeln()
      ..writeln('【你扮演的角色】')
      ..writeln('名称：${card.name.trim()}')
      ..writeln('人物设定：${card.persona.trim().isEmpty ? '（未填写）' : card.persona.trim()}')
      ..writeln('外在形象：${card.appearance.trim().isEmpty ? '（未填写）' : card.appearance.trim()}')
      ..writeln()
      ..writeln('【对话者（用户）】')
      ..writeln('名称：${user.name.trim().isEmpty ? '旅人' : user.name.trim()}')
      ..writeln('设定：${user.persona.trim().isEmpty ? '（未填写）' : user.persona.trim()}')
      ..writeln()
      ..writeln('【扮演要求】')
      ..writeln('1. 全程使用第一人称，保持角色的语气、性格与知识边界。')
      ..writeln('2. 动作、神态与环境描写放在中文括号（）内，对白直接书写。')
      ..writeln('3. 绝不代替用户发言、行动或做决定。')
      ..writeln('4. 不要输出任何解释、旁白、元信息，也不要提及自己是模型或 AI。')
      ..writeln('5. 回复长度贴合情境，自然收束，不要刻意冗长。');

    return <Map<String, String>>[
      {'role': 'system', 'content': sys.toString()},
      ...s.messages
          .where((m) => m.error == null && m.content.trim().isNotEmpty)
          .map((m) => m.toApiMessage()),
    ];
  }

  // ------------------------------------------------------------ 发送 / 流式接收
  Future<void> send(String text) async {
    final card = activeCard;
    final s = activeSession;
    if (card == null || s == null || busy) return;
    final content = text.trim();
    if (content.isEmpty) return;

    if (!api.ready) {
      s.messages.add(ChatMessage(
        role: MsgRole.assistant,
        content: '尚未配置 API Key。请在左上角「栏」中的「API 接入」里填入 DeepSeek 的 API Key 后再试。',
        error: 'noconfig',
        characterId: card.id,
      ));
      await _persist();
      notifyListeners();
      return;
    }

    s.messages.add(ChatMessage(role: MsgRole.user, content: content));
    final reply = ChatMessage(
      role: MsgRole.assistant,
      content: '',
      characterId: card.id,
      showReasoning: true,
    );
    s.messages.add(reply);
    s.touch();
    busy = true;
    streamingId = reply.id;
    statusText = api.reasoning == ReasoningLevel.off ? '正在回应…' : '正在思考…';
    notifyListeners();

    final prompt = buildPrompt(s, card);
    final completer = Completer<void>();

    _sub = DeepSeekClient.stream(cfg: api, messages: prompt).listen(
      (d) {
        if (d.error != null) {
          reply.error = d.error;
          if (reply.content.isEmpty) reply.content = '';
          statusText = '出错了';
        } else {
          if (d.reasoningDelta != null && d.reasoningDelta!.isNotEmpty) {
            reply.reasoning = (reply.reasoning ?? '') + d.reasoningDelta!;
            statusText = '正在思考…';
          }
          if (d.contentDelta != null && d.contentDelta!.isNotEmpty) {
            reply.content += d.contentDelta!;
            statusText = '正在回应…';
          }
          if (d.done) statusText = '';
        }
        // 流式期间只刷新，不落盘（避免高频写）
        notifyListeners();
      },
      onError: (Object e) {
        reply.error = '$e';
        statusText = '出错了';
        notifyListeners();
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    await completer.future;
    _sub = null;
    if (reply.content.trim().isEmpty && reply.error == null) {
      reply.content = '（模型没有返回内容，请检查模型名称或稍后重试。）';
    }
    busy = false;
    streamingId = null;
    statusText = '';
    s.touch();
    await _persist();
    notifyListeners();
  }

  /// 终止当前生成
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    final s = activeSession;
    if (s != null && s.messages.isNotEmpty && streamingId != null) {
      final m = s.messages.firstWhere(
        (x) => x.id == streamingId,
        orElse: () => ChatMessage(role: MsgRole.assistant),
      );
      if (m.content.trim().isEmpty && !m.hasReasoning) {
        s.messages.removeWhere((x) => x.id == streamingId);
      }
    }
    busy = false;
    streamingId = null;
    statusText = '';
    await _persist();
    notifyListeners();
  }

  /// 测试 API 连通性（设置页「测试连接」）
  Future<String> testApi(ApiConfig cfg) async {
    try {
      final buf = StringBuffer();
      await for (final d in DeepSeekClient.stream(
        cfg: cfg.clone()
          ..stream = false
          ..maxTokens = 32,
        messages: const [
          {'role': 'user', 'content': '请只回复两个字：连接成功'}
        ],
        singleShot: true,
      )) {
        if (d.error != null) return d.error!;
        if (d.contentDelta != null) buf.write(d.contentDelta);
      }
      final t = buf.toString().trim();
      return t.isEmpty ? '已连通，但模型未返回内容' : '连接成功：$t';
    } catch (e) {
      return '连接失败：$e';
    }
  }
}
