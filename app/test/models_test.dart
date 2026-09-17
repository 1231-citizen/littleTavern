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
        colorIndex: 2,
      );
      final back = CharacterCard.fromJson(c.toJson());
      expect(back.name, '红叶');
      expect(back.persona, contains('老板娘'));
      expect(back.appearance, contains('和服'));
      expect(back.avatar, '🍁');
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
    test('会话与角色一一对应并可序列化', () {
      final s = ChatSession(characterId: 'c1', world: '明治四十四年的秋末');
      s.messages.add(ChatMessage(role: MsgRole.user, content: '有人在吗？'));
      final back = ChatSession.fromJson(s.toJson());
      expect(back.characterId, 'c1');
      expect(back.world, contains('明治'));
      expect(back.messages.length, 1);
      expect(back.messages.first.content, '有人在吗？');
    });
  });
}
