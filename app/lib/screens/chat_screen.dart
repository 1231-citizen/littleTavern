import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/botanical.dart';
import '../theme/jf.dart';
import '../widgets/app_drawer.dart';
import '../widgets/common.dart';
import '../widgets/composer.dart';
import '../widgets/message_bubble.dart';
import 'api_screen.dart';
import 'character_edit_screen.dart';
import 'user_screen.dart';
import 'world_screen.dart';

/// ============================================================
///  对话主界面
///  顶栏（点击左上角展开「栏」） / 中部对话 / 下侧输入方框
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
    final n = widget.store.activeSession?.messages.length ?? 0;
    if (n != _lastCount || widget.store.busy) {
      _lastCount = n;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final max = _scroll.position.maxScrollExtent;
        if (widget.store.busy) {
          _scroll.jumpTo(max);
        } else {
          _scroll.animateTo(
            max,
            duration: JF.dur,
            curve: JF.ease,
          );
        }
      });
    }
  }

  // ---------------------------------------------------------- 交互
  Future<void> _editMessage(int index) async {
    final msgs = widget.store.activeSession?.messages;
    if (msgs == null || index < 0 || index >= msgs.length) return;
    final m = msgs[index];
    final after = msgs.length - index - 1;

    final text = await showJFTextEditor(
      context,
      title: m.role == MsgRole.user ? '修改你的发言' : '修改角色发言',
      initial: m.content,
      hint: '对话内容',
      note: after > 0
          ? '保存后，这条之后的 $after 条内容会被清除，并从这条重新开始对话。'
          : '保存后即更新这条对话。',
    );
    if (text == null) return;

    final removed = await widget.store.editMessageAt(index, text);
    if (!mounted) return;
    jfToast(context, removed > 0 ? '已更新，并清除了之后 $removed 条内容' : '已更新');
  }

  Future<void> _longPressMessage(int index) async {
    final msgs = widget.store.activeSession?.messages;
    if (msgs == null || index < 0 || index >= msgs.length) return;
    final m = msgs[index];
    final after = msgs.length - index - 1;

    final action = await showJFSheet<String>(
      context,
      title: '这条对话',
      maxHeightFactor: 0.52,
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
            subtitle: after > 0 ? '并清除之后的 $after 条对话' : '就地修改这条对话',
            onTap: () => Navigator.of(context).pop('edit'),
          ),
          if (m.hasReasoning) ...[
            Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
            JFRow(
              leading: Icon(
                m.showReasoning ? Icons.visibility_off_outlined : Icons.auto_awesome_outlined,
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

  Future<void> _headerMenu() async {
    final action = await showJFSheet<String>(
      context,
      title: '当前对话',
      maxHeightFactor: 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JFRow(
            leading: const Icon(Icons.landscape_outlined, size: 17, color: JF.inkSecond),
            title: '世界背景设定',
            subtitle: '当前对话的前因后果',
            onTap: () => Navigator.of(context).pop('world'),
          ),
          Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
          JFRow(
            leading: const Icon(Icons.badge_outlined, size: 17, color: JF.inkSecond),
            title: '编辑当前角色卡',
            onTap: () => Navigator.of(context).pop('card'),
          ),
          Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
          JFRow(
            leading: const Icon(Icons.restart_alt, size: 17, color: JF.inkSecond),
            title: '清空当前对话',
            subtitle: '保留世界背景与角色卡',
            onTap: () => Navigator.of(context).pop('clear'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'world':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => WorldScreen(store: widget.store)),
        );
        break;
      case 'card':
        final card = widget.store.activeCard;
        if (card == null) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CharacterEditScreen(store: widget.store, card: card)),
        );
        break;
      case 'clear':
        final ok = await showJFConfirm(
          context,
          title: '清空当前对话',
          message: '将删除与「${widget.store.activeCard?.name ?? ""}」的全部对话内容，角色卡与世界背景会保留。',
          okLabel: '清空',
          danger: true,
        );
        if (!ok) return;
        await widget.store.clearMessages();
        if (mounted) jfToast(context, '已清空');
        break;
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
              _topBar(store, card),
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
                    : (msgs.isEmpty ? _blankState(store, card) : _messageList(store, card, msgs)),
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

  Widget _topBar(AppStore store, CharacterCard? card) {
    final world = store.activeSession?.world.trim() ?? '';
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
            world.isEmpty ? '尚未设定世界背景' : _clip(world, 22),
            style: JF.tiny.copyWith(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: JFIconButton(
        icon: Icons.more_horiz,
        semanticLabel: '对话选项',
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
          ),
        );
      },
    );
  }

  Widget _blankState(AppStore store, CharacterCard card) {
    final world = store.activeSession?.world.trim() ?? '';
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
              world.isEmpty
                  ? '先写下世界背景，再开口第一句，角色会更容易入戏。'
                  : _clip(world, 60),
              style: JF.small,
              textAlign: TextAlign.center,
            ),
            if (world.isEmpty) ...[
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

  static String _clip(String s, int n) {
    final t = s.trim().replaceAll('\n', ' ');
    return t.length > n ? '${t.substring(0, n)}…' : t;
  }
}
