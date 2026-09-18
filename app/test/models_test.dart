import 'package:flutter_test/flutter_test.dart';
import 'package:tavern/models.dart';

void main() {
  group('角色卡', () {
    test('三要素可 JSON 往返', () {
      final c = CharacterCard(
        name: '红叶',
        persona: '温泉旅馆的老板娘，语气温和',
        appearance: '墨色长发，藏青和服',
        avatar: '🍁',
        avatarImage: '/tmp/avatar.jpg',
        colorIndex: 2,
      );
      final back = CharacterCard.fromJson(c.toJson());
      expect(back.name, '红叶');
      expect(back.persona, contains('老板娘'));
      expect(back.appearance, contains('和服'));
      expect(back.avatar, '🍁');
      expect(back.avatarImage, '/tmp/avatar.jpg');
      expect(back.colorIndex, 2);
      expect(back.id, c.id);
    });

    test('未填设定时给出占位摘要', () {
      final c = CharacterCard(name: '无名');
      expect(c.isReady, isTrue);
      expect(c.personaExcerpt, '尚未填写人物设定');
    });
  });

  group('消息', () {
    test('思维链不回传给模型', () {
      final m = ChatMessage(
        role: MsgRole.assistant,
        content: '（她抬起头）你来了。',
        reasoning: '先铺垫场景，再开口。',
      );
      final api = m.toApiMessage();
      expect(api['role'], 'assistant');
      expect(api['content'], contains('你来了'));
      expect(api.containsKey('reasoning'), isFalse);
      expect(api.containsKey('reasoning_content'), isFalse);
      expect(m.hasReasoning, isTrue);
    });
  });

  group('API 配置', () {
    test('接口地址拼接 chat/completions', () {
      expect(
        ApiConfig(baseUrl: 'https://api.deepseek.com').endpoint.toString(),
        'https://api.deepseek.com/chat/completions',
      );
      expect(
        ApiConfig(baseUrl: 'https://api.deepseek.com/').endpoint.toString(),
        'https://api.deepseek.com/chat/completions',
      );
      expect(
        ApiConfig(baseUrl: 'https://api.deepseek.com/v1').endpoint.toString(),
        'https://api.deepseek.com/v1/chat/completions',
      );
    });

    test('附加参数 JSON 校验', () {
      expect(ApiConfig(extraJson: '').extraJsonError, isNull);
      expect(ApiConfig(extraJson: '{"thinking":{"type":"enabled"}}').extraJsonError, isNull);
      expect(ApiConfig(extraJson: '{oops').extraJsonError, isNotNull);
      expect(ApiConfig(extraJson: '[1,2]').extraJsonError, isNotNull);
      expect(ApiConfig(extraJson: '{"a":1}').extraParams()['a'], 1);
    });

    test('未填 Key 时 ready 为 false', () {
      expect(ApiConfig(apiKey: '').ready, isFalse);
      expect(ApiConfig(apiKey: 'sk-x').ready, isTrue);
    });
  });

  group('会话', () {
    test('会话记录角色、世界与消息，可序列化', () {
      final w = WorldCard(name: '红叶亭', content: '明治四十四年的秋末');
      final s = ChatSession(characterId: 'c1', worldId: w.id);
      s.messages.add(ChatMessage(role: MsgRole.user, content: '有人在吗？'));
      final back = ChatSession.fromJson(s.toJson());
      expect(back.characterId, 'c1');
      expect(back.worldId, w.id);
      expect(back.messages.length, 1);
      expect(back.messages.first.content, '有人在吗？');
      expect(back.title, '有人在吗？');
    });

    test('旧版把世界背景存在会话里的数据可以读出来', () {
      final legacy = <String, dynamic>{
        'id': 'c1',
        'characterId': 'c1',
        'world': '明治四十四年的秋末',
        'messages': <dynamic>[],
        'updatedAt': DateTime.now().toIso8601String(),
      };
      final s = ChatSession.fromJson(legacy);
      expect(s.legacyWorld, contains('明治'));
      expect(s.worldId, isNull);
    });

    test('一个角色可以有多段对话，各自带时间', () {
      final a = ChatSession(characterId: 'c1');
      final b = ChatSession(characterId: 'c1');
      expect(a.id, isNot(b.id));
      expect(a.title, '空白对话');
    });
  });

  group('世界背景', () {
    test('名称与正文可 JSON 往返', () {
      final w = WorldCard(name: '红叶亭', content: '山间温泉旅馆，秋末多雾。');
      final back = WorldCard.fromJson(w.toJson());
      expect(back.displayName, '红叶亭');
      expect(back.content, contains('温泉'));
      expect(back.excerpt, contains('山间'));
    });
  });

  group('用户设定', () {
    test('可以有好几套，且带得上头像照片', () {
      final u = UserProfile(name: '阿雪', persona: '常客', avatarImage: '/tmp/a.jpg');
      final back = UserProfile.fromJson(u.toJson());
      expect(back.id, u.id);
      expect(back.displayName, '阿雪');
      expect(back.avatarImage, '/tmp/a.jpg');
      expect(UserProfile(name: '  ').displayName, '旅人');
    });
  });
}
