import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models.dart';

/// 一轮流式增量
class ChatDelta {
  final String? contentDelta;
  final String? reasoningDelta;
  final String? error;
  final bool done;

  const ChatDelta({this.contentDelta, this.reasoningDelta, this.error, this.done = false});

  static const ChatDelta finish = ChatDelta(done: true);
}

/// ============================================================
///  DeepSeek / OpenAI 兼容 流式客户端
///  - 只用 dart:io，不引入第三方依赖
///  - 原生直连，不存在浏览器 CORS 问题
///  - 自动解析 delta.content 与 delta.reasoning_content
/// ============================================================
class DeepSeekClient {
  static Stream<ChatDelta> stream({
    required ApiConfig cfg,
    required List<Map<String, String>> messages,
    bool singleShot = false,
  }) async* {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(minutes: 5)
      ..userAgent = 'TavernApp/1.0 (Android)';

    final useStream = cfg.stream && !singleShot;

    try {
      final HttpClientRequest req;
      try {
        req = await client.postUrl(cfg.endpoint);
      } catch (e) {
        yield ChatDelta(error: '无法连接接口：$e');
        return;
      }

      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      req.headers.set(HttpHeaders.acceptHeader, useStream ? 'text/event-stream' : 'application/json');
      final key = cfg.apiKey.trim();
      if (key.isNotEmpty) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      }

      final body = <String, dynamic>{
        'model': cfg.model.trim(),
        'messages': messages,
        'stream': useStream,
      };
      if (cfg.temperature >= 0) body['temperature'] = cfg.temperature;
      if (cfg.maxTokens > 0) body['max_tokens'] = cfg.maxTokens;
      if (cfg.reasoning != ReasoningLevel.off && cfg.sendReasoningEffort) {
        body['reasoning_effort'] = reasoningToName(cfg.reasoning);
      }
      body.addAll(cfg.extraParams());

      req.add(utf8.encode(jsonEncode(body)));

      final HttpClientResponse res;
      try {
        res = await req.close().timeout(const Duration(seconds: 120));
      } on TimeoutException {
        yield const ChatDelta(error: '请求超时，请检查网络或接口地址');
        return;
      } catch (e) {
        yield ChatDelta(error: '请求失败：$e');
        return;
      }

      if (res.statusCode != 200) {
        final raw = await res.transform(utf8.decoder).join();
        yield ChatDelta(error: '接口返回 ${res.statusCode}：${_brief(raw)}');
        return;
      }

      if (!useStream) {
        final raw = await res.transform(utf8.decoder).join();
        yield* _parseFull(raw);
        return;
      }

      final lines = res
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      var sawAny = false;
      await for (final line in lines) {
        final t = line.trim();
        if (t.isEmpty || t.startsWith(':')) continue;
        if (!t.startsWith('data:')) continue;
        final payload = t.substring(5).trim();
        if (payload == '[DONE]') break;
        Map<String, dynamic> j;
        try {
          final d = jsonDecode(payload);
          if (d is! Map) continue;
          j = Map<String, dynamic>.from(d);
        } catch (_) {
          continue;
        }
        if (j['error'] != null) {
          yield ChatDelta(error: '接口报错：${_brief(jsonEncode(j['error']))}');
          return;
        }
        final delta = _extract(j);
        if (delta.contentDelta != null || delta.reasoningDelta != null) {
          sawAny = true;
          yield delta;
        }
      }
      if (!sawAny) {
        yield const ChatDelta(error: '接口没有返回任何内容，请确认模型名称是否正确');
        return;
      }
      yield ChatDelta.finish;
    } catch (e) {
      yield ChatDelta(error: '异常：$e');
    } finally {
      client.close(force: true);
    }
  }

  // ---------------------------------------------------------- 解析
  static Stream<ChatDelta> _parseFull(String raw) async* {
    try {
      final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (j['error'] != null) {
        yield ChatDelta(error: '接口报错：${_brief(jsonEncode(j['error']))}');
        return;
      }
      final d = _extract(j);
      if (d.contentDelta == null && d.reasoningDelta == null) {
        yield const ChatDelta(error: '接口没有返回内容');
        return;
      }
      yield d;
      yield ChatDelta.finish;
    } catch (e) {
      yield ChatDelta(error: '返回内容无法解析：${_brief(raw)}');
    }
  }

  /// 同时兼容 OpenAI 标准结构与非流式结构
  static ChatDelta _extract(Map<String, dynamic> j) {
    String? content;
    String? reasoning;

    final choices = j['choices'];
    if (choices is List && choices.isNotEmpty) {
      final c0 = choices.first;
      if (c0 is Map) {
        final delta = c0['delta'];
        final msg = c0['message'];
        final src = delta is Map ? delta : (msg is Map ? msg : null);
        if (src != null) {
          content = _asString(src['content']);
          reasoning = _asString(src['reasoning_content']) ?? _asString(src['reasoning']);
        }
        // 个别兼容接口把思考内容放在 message.reasoning_content 下
        if (reasoning == null && msg is Map) {
          reasoning = _asString(msg['reasoning_content']) ?? _asString(msg['reasoning']);
        }
        if (content == null && msg is Map) content = _asString(msg['content']);
      }
    }
    return ChatDelta(
      contentDelta: (content == null || content.isEmpty) ? null : content,
      reasoningDelta: (reasoning == null || reasoning.isEmpty) ? null : reasoning,
    );
  }

  static String? _asString(Object? v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is List) {
      // 兼容 content 为分段数组的情况
      final sb = StringBuffer();
      for (final e in v) {
        if (e is Map && e['text'] != null) sb.write(e['text']);
      }
      return sb.toString();
    }
    return null;
  }

  static String _brief(String raw) {
    var t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length > 220) t = '${t.substring(0, 220)}…';
    return t;
  }
}
