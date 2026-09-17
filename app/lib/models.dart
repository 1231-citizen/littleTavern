import 'dart:convert';
import 'dart:math' as math;

/// ============================================================
///  数据模型 —— 角色卡 / 消息 / 会话 / 用户设定 / API 配置
/// ============================================================

String newId() {
  final r = math.Random();
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return '$t${r.nextInt(1 << 32).toRadixString(36)}';
}

enum MsgRole { user, assistant }

MsgRole roleFromName(String? s) =>
    s == 'assistant' ? MsgRole.assistant : MsgRole.user;

String roleToName(MsgRole r) => r == MsgRole.assistant ? 'assistant' : 'user';

// ---------------------------------------------------------------- 角色卡
/// 角色卡：人物名称 / 人物设定 / 人物外在形象（要求.txt 指定三要素）
class CharacterCard {
  String id;
  String name;
  String persona; // 人物设定
  String appearance; // 人物外在形象
  String avatar; // 人物形象（emoji）
  int colorIndex; // 取自 JF 调色板
  DateTime createdAt;

  CharacterCard({
    String? id,
    this.name = '',
    this.persona = '',
    this.appearance = '',
    this.avatar = '🌸',
    this.colorIndex = 0,
    DateTime? createdAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now();

  bool get isReady => name.trim().isNotEmpty;

  String get personaExcerpt {
    final t = persona.trim().replaceAll('\n', ' ');
    if (t.isEmpty) return '尚未填写人物设定';
    return t.length > 42 ? '${t.substring(0, 42)}…' : t;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'persona': persona,
        'appearance': appearance,
        'avatar': avatar,
        'colorIndex': colorIndex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CharacterCard.fromJson(Map<String, dynamic> j) => CharacterCard(
        id: j['id'] as String?,
        name: (j['name'] ?? '') as String,
        persona: (j['persona'] ?? '') as String,
        appearance: (j['appearance'] ?? '') as String,
        avatar: (j['avatar'] ?? '🌸') as String,
        colorIndex: (j['colorIndex'] ?? 0) as int,
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      );

  CharacterCard clone() => CharacterCard.fromJson(toJson());
}

// ---------------------------------------------------------------- 消息
class ChatMessage {
  String id;
  MsgRole role;
  String content;
  String? reasoning; // 思维链（reasoning_content）
  bool showReasoning; // 该条是否展示思维链
  DateTime at;
  String? characterId; // assistant 消息所属角色卡
  String? error;

  ChatMessage({
    String? id,
    required this.role,
    this.content = '',
    this.reasoning,
    this.showReasoning = false,
    DateTime? at,
    this.characterId,
    this.error,
  })  : id = id ?? newId(),
        at = at ?? DateTime.now();

  bool get hasReasoning => (reasoning ?? '').trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': roleToName(role),
        'content': content,
        'reasoning': reasoning,
        'showReasoning': showReasoning,
        'at': at.toIso8601String(),
        'characterId': characterId,
        'error': error,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String?,
        role: roleFromName(j['role'] as String?),
        content: (j['content'] ?? '') as String,
        reasoning: j['reasoning'] as String?,
        showReasoning: (j['showReasoning'] ?? false) as bool,
        at: DateTime.tryParse('${j['at']}') ?? DateTime.now(),
        characterId: j['characterId'] as String?,
        error: j['error'] as String?,
      );

  /// 发给模型时只带正文 —— 思维链不回传（DeepSeek 要求 reasoning_content 不得回填）
  Map<String, String> toApiMessage() => {
        'role': roleToName(role),
        'content': content,
      };
}

// ---------------------------------------------------------------- 会话
class ChatSession {
  String id; // 与 characterId 一致：一个角色卡一条会话
  String characterId;
  String world; // 世界背景设定（当前对话的前因后果）
  List<ChatMessage> messages;
  DateTime updatedAt;

  ChatSession({
    String? id,
    required this.characterId,
    this.world = '',
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  })  : id = id ?? characterId,
        messages = messages ?? <ChatMessage>[],
        updatedAt = updatedAt ?? DateTime.now();

  void touch() => updatedAt = DateTime.now();

  String get lastSnippet {
    if (messages.isEmpty) return '还没有对话';
    final t = messages.last.content.trim().replaceAll('\n', ' ');
    if (t.isEmpty) return '还没有对话';
    return t.length > 30 ? '${t.substring(0, 30)}…' : t;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'characterId': characterId,
        'world': world,
        'messages': messages.map((m) => m.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: j['id'] as String?,
        characterId: (j['characterId'] ?? '') as String,
        world: (j['world'] ?? '') as String,
        messages: ((j['messages'] ?? <dynamic>[]) as List)
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        updatedAt: DateTime.tryParse('${j['updatedAt']}') ?? DateTime.now(),
      );
}

// ---------------------------------------------------------------- 用户设定
class UserProfile {
  String name;
  String persona;
  String avatar;
  int colorIndex;

  UserProfile({
    this.name = '旅人',
    this.persona = '',
    this.avatar = '🍃',
    this.colorIndex = 1,
  });

  Map<String, dynamic> toJson() =>
      {'name': name, 'persona': persona, 'avatar': avatar, 'colorIndex': colorIndex};

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: (j['name'] ?? '旅人') as String,
        persona: (j['persona'] ?? '') as String,
        avatar: (j['avatar'] ?? '🍃') as String,
        colorIndex: (j['colorIndex'] ?? 1) as int,
      );
}

// ---------------------------------------------------------------- API 配置
enum ReasoningLevel { off, low, medium, high }

ReasoningLevel reasoningFromName(String? s) {
  switch (s) {
    case 'low':
      return ReasoningLevel.low;
    case 'medium':
      return ReasoningLevel.medium;
    case 'high':
      return ReasoningLevel.high;
    default:
      return ReasoningLevel.off;
  }
}

String reasoningToName(ReasoningLevel r) => r.name;

String reasoningLabel(ReasoningLevel r) {
  switch (r) {
    case ReasoningLevel.off:
      return '关闭';
    case ReasoningLevel.low:
      return '低';
    case ReasoningLevel.medium:
      return '中';
    case ReasoningLevel.high:
      return '高';
  }
}

class ApiConfig {
  String baseUrl;
  String apiKey;
  String model;
  ReasoningLevel reasoning;
  bool sendReasoningEffort; // 是否真的把 reasoning_effort 发给接口
  double temperature;
  int maxTokens;
  bool stream;
  String extraJson; // 附加请求参数（JSON）

  ApiConfig({
    this.baseUrl = 'https://api.deepseek.com',
    this.apiKey = '',
    this.model = 'deepseek-chat',
    this.reasoning = ReasoningLevel.off,
    this.sendReasoningEffort = false,
    this.temperature = 1.1,
    this.maxTokens = 2048,
    this.stream = true,
    this.extraJson = '',
  });

  ApiConfig clone() => ApiConfig.fromJson(toJson());

  /// 拼接 /chat/completions，容忍用户填 /v1 或带尾斜杠
  Uri get endpoint {
    var b = baseUrl.trim();
    if (b.isEmpty) b = 'https://api.deepseek.com';
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    if (!b.endsWith('/chat/completions')) {
      // DeepSeek 官方同时接受 /chat/completions 与 /v1/chat/completions
      b = '$b/chat/completions';
    }
    return Uri.parse(b);
  }

  Map<String, dynamic> extraParams() {
    final t = extraJson.trim();
    if (t.isEmpty) return <String, dynamic>{};
    try {
      final d = jsonDecode(t);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return <String, dynamic>{};
  }

  String? get extraJsonError {
    final t = extraJson.trim();
    if (t.isEmpty) return null;
    try {
      final d = jsonDecode(t);
      if (d is! Map) return '附加参数必须是一个 JSON 对象';
      return null;
    } catch (e) {
      return 'JSON 格式有误';
    }
  }

  bool get ready => apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'reasoning': reasoningToName(reasoning),
        'sendReasoningEffort': sendReasoningEffort,
        'temperature': temperature,
        'maxTokens': maxTokens,
        'stream': stream,
        'extraJson': extraJson,
      };

  factory ApiConfig.fromJson(Map<String, dynamic> j) => ApiConfig(
        baseUrl: (j['baseUrl'] ?? 'https://api.deepseek.com') as String,
        apiKey: (j['apiKey'] ?? '') as String,
        model: (j['model'] ?? 'deepseek-chat') as String,
        reasoning: reasoningFromName(j['reasoning'] as String?),
        sendReasoningEffort: (j['sendReasoningEffort'] ?? false) as bool,
        temperature: ((j['temperature'] ?? 1.1) as num).toDouble(),
        maxTokens: (j['maxTokens'] ?? 2048) as int,
        stream: (j['stream'] ?? true) as bool,
        extraJson: (j['extraJson'] ?? '') as String,
      );
}
