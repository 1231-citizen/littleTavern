import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/deepseek.dart';
import 'models.dart';

/// 左侧栏的四个栏目（顺序可由用户长按拖动改变，见 AppDrawer）
const List<String> kDrawerSections = <String>['world', 'api', 'user', 'characters'];

/// ============================================================
///  全局状态：角色卡 / 会话 / 用户设定 / 世界背景 / API 配置
///  + 流式对话编排
/// ============================================================
class AppStore extends ChangeNotifier {
  // 新版键（v2）
  static const _kCards = 'tavern.cards.v1';
  static const _kSessions = 'tavern.sessions.v2';
  static const _kUsers = 'tavern.users.v1';
  static const _kWorlds = 'tavern.worlds.v1';
  static const _kDrawer = 'tavern.drawer.v1';
  static const _kApi = 'tavern.api.v1';
  static const _kActiveCard = 'tavern.active.v1';
  static const _kActiveSession = 'tavern.activeSession.v1';
  static const _kActiveUser = 'tavern.activeUser.v1';
  static const _kActiveWorld = 'tavern.activeWorld.v1';

  // 旧版键（仅用于迁移）
  static const _kSessionsOld = 'tavern.sessions.v1';
  static const _kUserOld = 'tavern.user.v1';

  SharedPreferences? _prefs;

  final List<CharacterCard> cards = <CharacterCard>[];

  /// 全部对话，按 session.id 索引。一个角色卡可以有多段对话。
  final Map<String, ChatSession> sessions = <String, ChatSession>{};

  final List<UserProfile> userProfiles = <UserProfile>[];
  final List<WorldCard> worlds = <WorldCard>[];

  ApiConfig api = ApiConfig();

  String? activeCharacterId;
  String? activeSessionId;
  String? activeUserProfileId;
  String? activeWorldId;

  List<String> drawerOrder = List<String>.of(kDrawerSections);

  bool busy = false; // 正在生成
  String? streamingId; // 正在流式写入的消息 id
  String statusText = '';
  StreamSubscription<ChatDelta>? _sub;

  // ------------------------------------------------------------ 初始化
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;

    try {
      final raw = p.getString(_kCards);
      if (raw != null) {
        cards
          ..clear()
          ..addAll((jsonDecode(raw) as List)
              .map((e) => CharacterCard.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}

    try {
      final raw = p.getString(_kWorlds);
      if (raw != null) {
        worlds
          ..clear()
          ..addAll((jsonDecode(raw) as List)
              .map((e) => WorldCard.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}

    try {
      final raw = p.getString(_kSessions);
      if (raw != null) {
        sessions.clear();
        for (final e in jsonDecode(raw) as List) {
          final s = ChatSession.fromJson(Map<String, dynamic>.from(e as Map));
          sessions[s.id] = s;
        }
      } else {
        // 从 v1 迁移：那时一个角色只有一段对话，世界背景直接存在会话里
        final old = p.getString(_kSessionsOld);
        if (old != null) {
          for (final e in jsonDecode(old) as List) {
            final s = ChatSession.fromJson(Map<String, dynamic>.from(e as Map));
            final text = s.legacyWorld.trim();
            if (text.isNotEmpty && worlds.every((w) => w.content.trim() != text)) {
              final w = WorldCard(name: '默认世界', content: text);
              worlds.add(w);
              s.worldId = w.id;
            }
            s.legacyWorld = '';
            sessions[s.id] = s;
          }
        }
      }
    } catch (_) {}

    try {
      final raw = p.getString(_kUsers);
      if (raw != null) {
        userProfiles
          ..clear()
          ..addAll((jsonDecode(raw) as List)
              .map((e) => UserProfile.fromJson(Map<String, dynamic>.from(e as Map))));
      } else {
        final old = p.getString(_kUserOld);
        if (old != null) {
          userProfiles.add(UserProfile.fromJson(Map<String, dynamic>.from(jsonDecode(old) as Map)));
        }
      }
    } catch (_) {}

    if (userProfiles.isEmpty) userProfiles.add(UserProfile());

    try {
      final raw = p.getString(_kApi);
      if (raw != null) api = ApiConfig.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {}

    try {
      final raw = p.getString(_kDrawer);
      if (raw != null) {
        final cleaned = <String>[];
        for (final k in (jsonDecode(raw) as List).map((e) => '$e')) {
          if (kDrawerSections.contains(k) && !cleaned.contains(k)) cleaned.add(k);
        }
        for (final k in kDrawerSections) {
          if (!cleaned.contains(k)) cleaned.add(k);
        }
        drawerOrder = cleaned;
      }
    } catch (_) {}

    // ---- 当前选中项
    activeCharacterId = p.getString(_kActiveCard);
    if (cardById(activeCharacterId) == null) {
      activeCharacterId = cards.isEmpty ? null : cards.first.id;
    }

    activeWorldId = p.getString(_kActiveWorld);
    if (worldById(activeWorldId) == null) {
      activeWorldId = worlds.isEmpty ? null : worlds.first.id;
    }

    activeUserProfileId = p.getString(_kActiveUser);
    if (userById(activeUserProfileId) == null) {
      activeUserProfileId = userProfiles.first.id;
    }

    activeSessionId = p.getString(_kActiveSession);
    if (activeSession == null) activeSessionId = null;
    if (activeCharacterId != null) _ensureSessionFor(activeCharacterId!);

    notifyListeners();
  }

  Future<void> _persist() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kCards, jsonEncode(cards.map((c) => c.toJson()).toList()));
    await p.setString(_kSessions, jsonEncode(sessions.values.map((s) => s.toJson()).toList()));
    await p.setString(_kUsers, jsonEncode(userProfiles.map((u) => u.toJson()).toList()));
    await p.setString(_kWorlds, jsonEncode(worlds.map((w) => w.toJson()).toList()));
    await p.setString(_kDrawer, jsonEncode(drawerOrder));
    await p.setString(_kApi, jsonEncode(api.toJson()));
    await _writeOrRemove(p, _kActiveCard, activeCharacterId);
    await _writeOrRemove(p, _kActiveSession, activeSessionId);
    await _writeOrRemove(p, _kActiveUser, activeUserProfileId);
    await _writeOrRemove(p, _kActiveWorld, activeWorldId);
  }

  Future<void> _writeOrRemove(SharedPreferences p, String key, String? value) async {
    if (value == null) {
      await p.remove(key);
    } else {
      await p.setString(key, value);
    }
  }

  Future<void> saveAll() => _persist();

  // ------------------------------------------------------------ 角色卡
  CharacterCard? get activeCard => cardById(activeCharacterId);

  CharacterCard? cardById(String? id) {
    if (id == null) return null;
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 头像照片换掉或被移除之后，把旧文件从磁盘上清掉
  void _dropAvatarFile(String? path) {
    if (path == null || path.trim().isEmpty) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      // 删不掉就算了，不影响使用
    }
  }

  Future<void> upsertCard(CharacterCard card) async {
    final i = cards.indexWhere((c) => c.id == card.id);
    if (i >= 0) {
      final old = cards[i].avatarImage;
      cards[i] = card;
      if (old != card.avatarImage) _dropAvatarFile(old);
    } else {
      cards.add(card);
    }
    if (activeCharacterId == null) {
      activeCharacterId = card.id;
      _ensureSessionFor(card.id);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deleteCard(String id) async {
    _dropAvatarFile(cardById(id)?.avatarImage);
    cards.removeWhere((c) => c.id == id);
    sessions.removeWhere((_, s) => s.characterId == id);
    if (activeCharacterId == id) {
      activeCharacterId = cards.isEmpty ? null : cards.first.id;
      activeSessionId = null;
      if (activeCharacterId != null) _ensureSessionFor(activeCharacterId!);
    }
    await _persist();
    notifyListeners();
  }

  /// 切换当前角色卡。会自动落到这张卡的最近一段对话上。
  Future<void> setActiveCharacter(String id) async {
    if (cardById(id) == null) return;
    activeCharacterId = id;
    _ensureSessionFor(id);
    await _persist();
    notifyListeners();
  }

  // ------------------------------------------------------------ 会话 / 历史对话
  /// 某个角色的全部对话，最近的排在前面
  List<ChatSession> sessionsOf(String characterId) {
    final list = sessions.values.where((s) => s.characterId == characterId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<ChatSession> get activeHistories {
    final id = activeCharacterId;
    return id == null ? const <ChatSession>[] : sessionsOf(id);
  }

  ChatSession? get activeSession {
    final id = activeSessionId;
    if (id == null) return null;
    final s = sessions[id];
    if (s == null) return null;
    if (activeCharacterId != null && s.characterId != activeCharacterId) return null;
    return s;
  }

  ChatSession? sessionById(String? id) => id == null ? null : sessions[id];

  /// 已有对话 → 取最近的一段；一段都没有 → 新建一段
  ChatSession? _ensureSessionFor(String characterId) {
    if (cardById(characterId) == null) return null;
    final list = sessionsOf(characterId);
    final s = list.isNotEmpty ? list.first : _createSession(characterId);
    activeSessionId = s.id;
    return s;
  }

  ChatSession _createSession(String characterId) {
    final s = ChatSession(
      characterId: characterId,
      worldId: activeSession?.worldId ?? activeWorldId,
    );
    sessions[s.id] = s;
    return s;
  }

  /// 「开启新对话」：旧的那段自动留在历史对话里
  /// 正在生成时不允许（否则回复会落进已经切走的那段对话）
  Future<ChatSession?> newSession() async {
    if (busy) return null;
    final id = activeCharacterId;
    if (id == null) return null;
    final s = _createSession(id);
    activeSessionId = s.id;
    if (s.worldId != null) activeWorldId = s.worldId;
    await _persist();
    notifyListeners();
    return s;
  }

  Future<bool> switchSession(String sessionId) async {
    if (busy) return false;
    final s = sessions[sessionId];
    if (s == null) return false;
    activeCharacterId = s.characterId;
    activeSessionId = s.id;
    if (s.worldId != null && worldById(s.worldId) != null) activeWorldId = s.worldId;
    await _persist();
    notifyListeners();
    return true;
  }

  Future<bool> deleteSession(String sessionId) async {
    if (busy && sessionId == activeSessionId) return false;
    final s = sessions.remove(sessionId);
    if (s == null) return false;
    if (activeSessionId == sessionId) {
      activeSessionId = null;
      _ensureSessionFor(s.characterId);
    }
    await _persist();
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------ 世界背景
  WorldCard? worldById(String? id) {
    if (id == null) return null;
    for (final w in worlds) {
      if (w.id == id) return w;
    }
    return null;
  }

  WorldCard? get activeWorld => worldById(activeWorldId);

  /// 当前这段对话使用的世界背景正文
  String worldTextOf(ChatSession? s) => worldById(s?.worldId)?.content.trim() ?? '';

  Future<void> upsertWorld(WorldCard world) async {
    final i = worlds.indexWhere((w) => w.id == world.id);
    if (i >= 0) {
      worlds[i] = world;
    } else {
      worlds.add(world);
    }
    activeWorldId ??= world.id;
    await _persist();
    notifyListeners();
  }

  /// 切换当前世界背景：当前这段对话也跟着换
  Future<void> setActiveWorld(String? id) async {
    activeWorldId = worldById(id) == null ? null : id;
    final s = activeSession;
    if (s != null) {
      s.worldId = activeWorldId;
      s.touch();
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deleteWorld(String id) async {
    final s = activeSession;
    if (s != null && s.worldId == id) s.worldId = null;
    worlds.removeWhere((w) => w.id == id);
    for (final x in sessions.values) {
      if (x.worldId == id) x.worldId = null;
    }
    if (activeWorldId == id) {
      activeWorldId = worlds.isEmpty ? null : worlds.first.id;
      if (s != null && s.worldId == null) s.worldId = activeWorldId;
    }
    await _persist();
    notifyListeners();
  }

  // ------------------------------------------------------------ 用户设定
  UserProfile? userById(String? id) {
    if (id == null) return null;
    for (final u in userProfiles) {
      if (u.id == id) return u;
    }
    return null;
  }

  /// 当前用户设定（永远有值）
  UserProfile get user => userById(activeUserProfileId) ?? userProfiles.first;

  Future<void> upsertUserProfile(UserProfile profile) async {
    final i = userProfiles.indexWhere((u) => u.id == profile.id);
    if (i >= 0) {
      final old = userProfiles[i].avatarImage;
      userProfiles[i] = profile;
      if (old != profile.avatarImage) _dropAvatarFile(old);
    } else {
      userProfiles.add(profile);
    }
    activeUserProfileId ??= profile.id;
    await _persist();
    notifyListeners();
  }

  Future<void> setActiveUser(String id) async {
    if (userById(id) == null) return;
    activeUserProfileId = id;
    await _persist();
    notifyListeners();
  }

  Future<void> deleteUserProfile(String id) async {
    if (userProfiles.length <= 1) return; // 至少留一套
    _dropAvatarFile(userById(id)?.avatarImage);
    userProfiles.removeWhere((u) => u.id == id);
    if (activeUserProfileId == id) activeUserProfileId = userProfiles.first.id;
    await _persist();
    notifyListeners();
  }

  // ------------------------------------------------------------ 左侧栏顺序
  Future<void> setDrawerOrder(List<String> order) async {
    final cleaned = <String>[];
    for (final k in order) {
      if (kDrawerSections.contains(k) && !cleaned.contains(k)) cleaned.add(k);
    }
    for (final k in kDrawerSections) {
      if (!cleaned.contains(k)) cleaned.add(k);
    }
    drawerOrder = cleaned;
    await _persist();
    notifyListeners();
  }

  // ------------------------------------------------------------ API
  Future<void> updateApi(ApiConfig a) async {
    api = a;
    await _persist();
    notifyListeners();
  }

  // ------------------------------------------------------------ 消息编辑 / 删除
  /// 修改某条消息的正文，并清除它之后的全部内容（从该对话框重新开始对话）
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

  /// 修改思维链。思维链不回传给模型，所以只就地改写，不影响后续对话。
  Future<void> editReasoningAt(int index, String text) async {
    final s = activeSession;
    if (s == null || index < 0 || index >= s.messages.length) return;
    s.messages[index].reasoning = text;
    if (text.trim().isNotEmpty) s.messages[index].showReasoning = true;
    await _persist();
    notifyListeners();
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
    final world = worldTextOf(s);
    final u = user;
    final sys = StringBuffer()
      ..writeln('你正在进行沉浸式角色扮演，请始终以指定角色的身份说话。')
      ..writeln()
      ..writeln('【世界背景】')
      ..writeln(world.isEmpty ? '（未特别设定，请依据角色设定自然展开。）' : world)
      ..writeln()
      ..writeln('【你扮演的角色】')
      ..writeln('名称：${card.name.trim()}')
      ..writeln('人物设定：${card.persona.trim().isEmpty ? '（未填写）' : card.persona.trim()}')
      ..writeln('外在形象：${card.appearance.trim().isEmpty ? '（未填写）' : card.appearance.trim()}')
      ..writeln()
      ..writeln('【对话者（用户）】')
      ..writeln('名称：${u.displayName}')
      ..writeln('设定：${u.persona.trim().isEmpty ? '（未填写）' : u.persona.trim()}')
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
  /// 用户发言
  Future<void> send(String text) async {
    final s = activeSession;
    if (s == null || busy) return;
    final content = text.trim();
    if (content.isEmpty) return;

    s.messages.add(ChatMessage(role: MsgRole.user, content: content));
    s.touch();
    notifyListeners();
    await _requestReply();
  }

  /// 修改完用户的发言之后，用这条内容直接接上后续对话
  Future<void> replyAfterUserEdit() => _requestReply();

  /// 请求一次模型回复（新增一条 assistant 占位气泡并流式写入）
  Future<void> _requestReply() async {
    final card = activeCard;
    final s = activeSession;
    if (card == null || s == null || busy) return;

    if (!api.ready) {
      s.messages.add(ChatMessage(
        role: MsgRole.assistant,
        content: '尚未配置 API Key。请在左上角「栏」中的「API 接入」里填入 DeepSeek 的 API Key 后再试。',
        error: 'noconfig',
        characterId: card.id,
      ));
      s.touch();
      await _persist();
      notifyListeners();
      return;
    }

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
