import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/botanical.dart';
import '../theme/jf.dart';
import '../widgets/app_drawer.dart';
import '../widgets/common.dart';
import '../widgets/composer.dart';
import '../widgets/message_bubble.dart';
import '../widgets/page.dart';
import 'api_screen.dart';
import 'character_edit_screen.dart';
import 'user_screen.dart';
import 'world_screen.dart';

/// ============================================================
///  对话主界面
///  顶栏（点击左上角展开「栏」） / 中部对话 / 下侧输入方框
///  右上角 = 当前人物的历史对话 + 开启新对话
/// ============================================================
class ChatScreen extends StatefulWidget {
  final AppStore store;
  const ChatScreen({super.key, required this.store});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  int _lastCount = -1;
  String? _lastSessionId;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _scroll.dispose();
    super.dispose();
  }

  void _onStore() {
    final session = widget.store.activeSession;
    final n = session?.messages.length ?? 0;
    final switched = session?.id != _lastSessionId;
    if (n != _lastCount || widget.store.busy || switched) {
      _lastCount = n;
      _lastSessionId = session?.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final max = _scroll.position.maxScrollExtent;
        if (widget.store.busy || switched) {
          _scroll.jumpTo(max);
        } else {
          // 改完一条要立刻看到下文，滚动也跟着快一点
          _scroll.animateTo(max, duration: JF.durFast, curve: JF.ease);
        }
      });
    }
  }

  // ---------------------------------------------------------- 交互
  Future<void> _editMessage(int index) async {
    final msgs = widget.store.activeSession?.messages;
    if (msgs == null || index < 0 || index >= msgs.length) return;
    final m = msgs[index];
    final isUser = m.role == MsgRole.user;
    final after = msgs.length - index - 1;

    final note = isUser
        ? (after > 0
            ? '保存后，这条之后的 $after 条内容会被清除，并立刻用这条发言重新接上后续对话。'
            : '保存后会立刻用这条发言继续对话。')
        : (after > 0 ? '保存后，这条之后的 $after 条内容会被清除。' : '保存后即更新这条对话。');

    final text = await showJFTextEditor(
      context,
      title: isUser ? '修改你的发言' : '修改角色发言',
      initial: m.content,
      hint: '对话内容',
      note: note,
    );
    if (text == null) return;
    if (text.trim().isEmpty) {
      if (mounted) jfToast(context, '内容不能为空');
      return;
    }

    final removed = await widget.store.editMessageAt(index, text);
    if (!mounted) return;

    if (isUser) {
      // 改的是自己的话：立刻把后续对话接上
      jfToast(context, removed > 0 ? '已更新，清除了之后 $removed 条，正在继续对话' : '已更新，正在继续对话');
      await widget.store.replyAfterUserEdit();
    } else {
      // 改的是角色的回答：只更新，不触发
      jfToast(context, removed > 0 ? '已更新，并清除了之后 $removed 条内容' : '已更新');
    }
  }

  Future<void> _editReasoning(int index) async {
    final msgs = widget.store.activeSession?.messages;
    if (msgs == null || index < 0 || index >= msgs.length) return;
    final text = await showJFTextEditor(
      context,
      title: '修改思维链',
      initial: msgs[index].reasoning ?? '',
      hint: '思维链内容',
      note: '思维链不会回传给模型，改它只影响这里的显示。',
    );
    if (text == null) return;
    await widget.store.editReasoningAt(index, text);
    if (mounted) jfToast(context, '思维链已更新');
  }

  Future<void> _longPressMessage(int index) async {
    final msgs = widget.store.activeSession?.messages;
    if (msgs == null || index < 0 || index >= msgs.length) return;
    final m = msgs[index];
    final after = msgs.length - index - 1;
    final isUser = m.role == MsgRole.user;

    final action = await showJFSheet<String>(
      context,
      title: '这条对话',
      maxHeightFactor: 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JFRow(
            leading: const Icon(Icons.content_copy, size: 17, color: JF.inkSecond),
            title: '复制内容',
            subtitle: '把这条对话的文字复制到剪贴板',
            onTap: () => Navigator.of(context).pop('copy'),
          ),
          Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
          JFRow(
            leading: const Icon(Icons.edit_outlined, size: 17, color: JF.inkSecond),
            title: '修改内容',
            subtitle: isUser
                ? (after > 0 ? '清除之后的 $after 条，并自动续上对话' : '保存后自动续上对话')
                : (after > 0 ? '并清除之后的 $after 条对话' : '就地修改这条对话'),
            onTap: () => Navigator.of(context).pop('edit'),
          ),
          if (m.hasReasoning) ...[
            Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
            JFRow(
              leading: const Icon(Icons.auto_awesome_outlined, size: 17, color: JF.inkSecond),
              title: '修改思维链',
              subtitle: '这条回复的思考过程也可以改',
              onTap: () => Navigator.of(context).pop('editReasoning'),
            ),
            Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
            JFRow(
              leading: Icon(
                m.showReasoning ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 17,
                color: JF.inkSecond,
              ),
              title: m.showReasoning ? '隐藏思维链' : '显示思维链',
              subtitle: '这条回复的思考过程',
              onTap: () => Navigator.of(context).pop('reasoning'),
            ),
          ],
          Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
          JFRow(
            leading: const Icon(Icons.delete_outline, size: 17, color: JF.inkSecond),
            title: '删除这条对话',
            subtitle: after > 0 ? '并清除之后的 $after 条内容' : '仅删除这一条',
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'copy':
        await jfCopy(context, m.content);
        break;
      case 'edit':
        await _editMessage(index);
        break;
      case 'editReasoning':
        await _editReasoning(index);
        break;
      case 'reasoning':
        await widget.store.toggleReasoningAt(index);
        break;
      case 'delete':
        final ok = await showJFConfirm(
          context,
          title: '删除这条对话',
          message: after > 0
              ? '这条之后的 $after 条内容也会一并清除，从这条之前重新开始对话。'
              : '将删除这条对话。',
          okLabel: '删除',
          danger: true,
        );
        if (!ok) return;
        final removed = await widget.store.deleteMessageAt(index);
        if (!mounted) return;
        jfToast(context, removed > 0 ? '已删除，并清除了之后 $removed 条内容' : '已删除');
        break;
    }
  }

  Future<void> _tapAvatar(ChatMessage m) async {
    if (m.role == MsgRole.user) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserScreen(store: widget.store)),
      );
      return;
    }
    final card = widget.store.cardById(m.characterId) ?? widget.store.activeCard;
    if (card == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CharacterEditScreen(store: widget.store, card: card)),
    );
  }

  /// 右上角：当前人物的历史对话 + 开启新对话
  Future<void> _headerMenu() async {
    final store = widget.store;
    final card = store.activeCard;
    if (card == null) return;

    final histories = store.activeHistories;
    final action = await showJFSheet<String>(
      context,
      title: '当前对话',
      maxHeightFactor: 0.76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JFRow(
            leading: const Icon(Icons.add_comment_outlined, size: 17, color: JF.inkSecond),
            title: '开启新对话',
            subtitle: '当前这段会自动存进「${card.name}」的历史对话',
            onTap: () => Navigator.of(context).pop('new'),
          ),
          Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
          JFRow(
            leading: const Icon(Icons.badge_outlined, size: 17, color: JF.inkSecond),
            title: '编辑当前角色卡',
            subtitle: '名称 · 设定 · 外在形象',
            onTap: () => Navigator.of(context).pop('card'),
          ),
          const JFMa(30),
          JFSectionLabel('历史对话', trailing: '${histories.length} 段'),
          for (var i = 0; i < histories.length; i++) ...[
            if (i > 0) Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
            JFRow(
              leading: const Icon(Icons.chat_bubble_outline, size: 16, color: JF.inkSecond),
              title: histories[i].title,
              subtitle: '${histories[i].messages.length} 条 · '
                  '${jfTimeLabel(histories[i].updatedAt)} · ${histories[i].lastSnippet}',
              trailing: histories[i].id == store.activeSessionId
                  ? const JFBadge('当前')
                  : const Icon(Icons.chevron_right, size: 16, color: JF.muted),
              onTap: () => Navigator.of(context).pop('open:${histories[i].id}'),
              onLongPress: () => Navigator.of(context).pop('del:${histories[i].id}'),
            ),
          ],
        ],
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'new') {
      final created = await store.newSession();
      if (!mounted) return;
      jfToast(context, created == null ? '正在生成回复，请稍候再试' : '已开启新对话，原来那段已存入历史对话');
      return;
    }
    if (action == 'card') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CharacterEditScreen(store: store, card: card)),
      );
      return;
    }
    if (action.startsWith('open:')) {
      final id = action.substring(5);
      final ok = await store.switchSession(id);
      if (!mounted) return;
      jfToast(context, ok ? '已切换到这对话' : '正在生成回复，请稍候再试');
      return;
    }
    if (action.startsWith('del:')) {
      final id = action.substring(4);
      final s = store.sessionById(id);
      if (s == null) return;
      final ok = await showJFConfirm(
        context,
        title: '删除这段对话',
        message: '「${s.title}」共 ${s.messages.length} 条内容会被删除，且无法恢复。',
        okLabel: '删除',
        danger: true,
      );
      if (!ok) return;
      final done = await store.deleteSession(id);
      if (!mounted) return;
      jfToast(context, done ? '已删除这段对话' : '正在生成回复，请稍候再试');
    }
  }

  // ---------------------------------------------------------- 构建
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final card = store.activeCard;
        final session = store.activeSession;
        final msgs = session?.messages ?? const <ChatMessage>[];

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: JF.riceWhite,
          drawer: AppDrawer(store: store),
          body: Column(
            children: [
              _topBar(store, card, session),
              Expanded(
                child: card == null
                    ? JFEmpty(
                        title: '先写一张角色卡',
                        desc: '角色卡需要人物名称、人物设定与外在形象。\n写完之后，才能开始这段对话。',
                        variant: 1,
                        action: JFButton(
                          label: '创建角色卡',
                          primary: true,
                          icon: Icons.add,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CharacterEditScreen(store: store),
                            ),
                          ),
                        ),
                      )
                    : (msgs.isEmpty
                        ? _blankState(store, card, session)
                        : _messageList(store, card, msgs)),
              ),
              Composer(
                busy: store.busy,
                enabled: card != null,
                characterName: card?.name ?? '',
                apiReady: store.api.ready,
                onSend: store.send,
                onStop: store.stop,
                onNeedCharacter: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CharacterEditScreen(store: store)),
                ),
                onTapApiWarning: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ApiScreen(store: store)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar(AppStore store, CharacterCard? card, ChatSession? session) {
    final world = store.worldById(session?.worldId);
    return JFHeader(
      leading: JFIconButton(
        icon: Icons.menu,
        semanticLabel: '展开栏目',
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            card?.name ?? '小酒馆',
            style: JF.h3,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            world == null ? '尚未设定世界背景' : world.displayName,
            style: JF.tiny.copyWith(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: JFIconButton(
        icon: Icons.history,
        semanticLabel: '历史对话',
        onPressed: _headerMenu,
      ),
    );
  }

  Widget _messageList(AppStore store, CharacterCard card, List<ChatMessage> msgs) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 26),
      itemCount: msgs.length,
      itemBuilder: (context, i) {
        final m = msgs[i];
        final prev = i > 0 ? msgs[i - 1] : null;
        final tight = prev != null && prev.role == m.role;
        return Padding(
          padding: EdgeInsets.only(bottom: tight ? 6 : 14),
          child: MessageBubble(
            m: m,
            card: store.cardById(m.characterId) ?? card,
            user: store.user,
            streaming: store.streamingId == m.id,
            statusText: store.statusText,
            onTap: () => _editMessage(i),
            onLongPress: () => _longPressMessage(i),
            onAvatarTap: () => _tapAvatar(m),
            onToggleReasoning: () => store.toggleReasoningAt(i),
            onEditReasoning: () => _editReasoning(i),
          ),
        );
      },
    );
  }

  Widget _blankState(AppStore store, CharacterCard card, ChatSession? session) {
    final world = store.worldById(session?.worldId);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Botanical(size: 88, variant: 2, color: JF.powder),
            const SizedBox(height: 30),
            Text('与「${card.name}」的故事尚未开始', style: JF.h2, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Text(
              world == null
                  ? '先写下世界背景，再开口第一句，角色会更容易入戏。'
                  : '世界背景：${world.displayName}',
              style: JF.small,
              textAlign: TextAlign.center,
            ),
            if (world == null) ...[
              const SizedBox(height: 26),
              JFButton(
                label: '写下世界背景',
                icon: Icons.landscape_outlined,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WorldScreen(store: store)),
                ),
              ),
            ],
            if (!store.api.ready) ...[
              const SizedBox(height: 16),
              JFButton(
                label: '配置 API Key',
                icon: Icons.hub_outlined,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ApiScreen(store: store)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
