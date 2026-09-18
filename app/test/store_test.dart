import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tavern/models.dart';
import 'package:tavern/store.dart';

/// 状态层的行为：历史对话 / 世界切换 / 用户切换 / 侧栏顺序
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppStore> freshStore([Map<String, Object> seed = const {}]) async {
    SharedPreferences.setMockInitialValues(seed);
    final store = AppStore();
    await store.load();
    return store;
  }

  Future<AppStore> storeWithCard() async {
    final store = await freshStore();
    await store.upsertCard(CharacterCard(name: '红叶'));
    return store;
  }

  test('一个角色可以有多段对话，开启新对话会保留旧的', () async {
    final store = await storeWithCard();
    final first = store.activeSession!.id;
    store.activeSession!.messages.add(ChatMessage(role: MsgRole.user, content: '第一句'));

    await store.newSession();

    expect(store.activeSession!.id, isNot(first));
    expect(store.activeHistories.length, 2);
    expect(store.activeHistories.first.id, store.activeSession!.id);

    // 切回去，内容还在
    await store.switchSession(first);
    expect(store.activeSession!.messages.single.content, '第一句');
    expect(store.activeSession!.title, '第一句');
  });

  test('删除一段历史后自动落到另一段上', () async {
    final store = await storeWithCard();
    final first = store.activeSession!.id;
    await store.newSession();
    final second = store.activeSession!.id;

    await store.deleteSession(second);
    expect(store.sessionById(second), isNull);
    expect(store.activeSession?.id, first);
  });

  test('改用户发言：清除后续并立刻重新接上对话', () async {
    final store = await storeWithCard();
    final s = store.activeSession!;
    s.messages.add(ChatMessage(role: MsgRole.user, content: '旧话'));
    s.messages.add(ChatMessage(role: MsgRole.assistant, content: '旧回答'));

    final removed = await store.editMessageAt(0, '新话');
    expect(removed, 1);
    expect(s.messages.length, 1);
    expect(s.messages.single.content, '新话');

    // 没配 API 时也会立刻走一次请求（落下一条提示气泡），说明续聊被触发了
    await store.replyAfterUserEdit();
    expect(s.messages.length, 2);
    expect(s.messages.last.role, MsgRole.assistant);
    expect(s.messages.last.error, 'noconfig');
  });

  test('思维链可以就地改，且不影响消息正文', () async {
    final store = await storeWithCard();
    final s = store.activeSession!;
    s.messages.add(ChatMessage(role: MsgRole.assistant, content: '（她抬起头）', reasoning: '先铺垫'));

    await store.editReasoningAt(0, '换一种想法');

    expect(s.messages.single.reasoning, '换一种想法');
    expect(s.messages.single.content, '（她抬起头）');
    expect(s.messages.single.showReasoning, isTrue);
  });

  test('世界背景可以有好几张，切换作用于当前对话', () async {
    final store = await storeWithCard();
    final a = WorldCard(name: '甲世界', content: '山间旅馆');
    final b = WorldCard(name: '乙世界', content: '海边小镇');
    await store.upsertWorld(a);
    await store.upsertWorld(b);

    await store.setActiveWorld(b.id);

    expect(store.activeWorld?.displayName, '乙世界');
    expect(store.activeSession!.worldId, b.id);
    expect(store.worldTextOf(store.activeSession), '海边小镇');

    await store.deleteWorld(b.id);
    expect(store.worlds.length, 1);
    // 当前世界被删掉时，自动落到还剩的那一张上
    expect(store.activeWorld?.id, store.worlds.single.id);
    expect(store.activeSession!.worldId, store.worlds.single.id);
  });

  test('用户设定可以有好几套，切换与删除都可用', () async {
    final store = await freshStore();
    final first = store.user.id;

    final second = UserProfile(name: '阿雪', persona: '常客');
    await store.upsertUserProfile(second);
    await store.setActiveUser(second.id);
    expect(store.user.displayName, '阿雪');

    await store.deleteUserProfile(second.id);
    expect(store.user.id, first);
    expect(store.userProfiles.length, 1);

    // 最后一套删不掉
    await store.deleteUserProfile(first);
    expect(store.userProfiles.length, 1);
  });

  test('侧栏顺序可以改，缺项与重复项会被收拾干净', () async {
    final store = await freshStore();
    expect(store.drawerOrder, kDrawerSections);

    await store.setDrawerOrder(<String>['characters', 'user', 'api', 'nope', 'characters']);
    expect(store.drawerOrder, <String>['characters', 'user', 'api', 'world']);
  });

  test('旧版数据能读进来：会话里的世界背景升级成一张世界卡', () async {
    final legacySessions = '[{"id":"c1","characterId":"c1","world":"明治四十四年的秋末",'
        '"messages":[{"id":"m1","role":"user","content":"有人在吗？","at":"2026-09-18T10:00:00.000"}],'
        '"updatedAt":"2026-09-18T10:00:00.000"}]';
    final store = await freshStore(<String, Object>{
      'tavern.cards.v1': '[{"id":"c1","name":"红叶","persona":"","appearance":"",'
          '"avatar":"🍁","colorIndex":0,"createdAt":"2026-09-18T09:00:00.000"}]',
      'tavern.sessions.v1': legacySessions,
      'tavern.user.v1': '{"name":"旅人","persona":"过路人","avatar":"🍃","colorIndex":1}',
    });

    expect(store.cards.single.name, '红叶');
    expect(store.activeSession!.messages.single.content, '有人在吗？');
    expect(store.worlds.single.content, contains('明治'));
    expect(store.activeSession!.worldId, store.worlds.single.id);
    expect(store.user.persona, '过路人');
  });
}
