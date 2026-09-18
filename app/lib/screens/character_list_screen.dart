import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/jf.dart';
import '../widgets/common.dart';
import '../widgets/page.dart';
import 'character_edit_screen.dart';

/// ============================================================
///  酒馆人物管理 —— 管理 / 创建角色卡
///  点击一行即切换到这个人物，铅笔进编辑页，长按删除
/// ============================================================
class CharacterListScreen extends StatelessWidget {
  final AppStore store;
  const CharacterListScreen({super.key, required this.store});

  Future<void> _openEdit(BuildContext context, CharacterCard? card) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CharacterEditScreen(store: store, card: card)),
    );
  }

  Future<void> _use(BuildContext context, CharacterCard card) async {
    await store.setActiveCharacter(card.id);
    if (!context.mounted) return;
    jfToast(context, '已切换到「${card.name}」');
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _delete(BuildContext context, CharacterCard card) async {
    final ok = await showJFConfirm(
      context,
      title: '删除角色卡',
      message: '「${card.name}」及其全部对话记录都会被删除，且无法恢复。',
      okLabel: '删除',
      danger: true,
    );
    if (!ok) return;
    await store.deleteCard(card.id);
    if (context.mounted) jfToast(context, '已删除「${card.name}」');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final cards = store.cards;

        if (cards.isEmpty) {
          return JFPage(
            title: '酒馆人物管理',
            scroll: false,
            child: JFEmpty(
              title: '还没有角色卡',
              desc: '角色卡是对话的前提。写下名字、设定与外在形象，故事才能开始。',
              variant: 2,
              action: JFButton(
                label: '创建第一张角色卡',
                primary: true,
                icon: Icons.add,
                onPressed: () => _openEdit(context, null),
              ),
            ),
          );
        }

        return JFPage(
          title: '酒馆人物管理',
          subtitle: '${cards.length} 位角色 · 点击即切换',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
                JFRow(
                  leading: JFAvatar(
                    emoji: cards[i].avatar,
                    imagePath: cards[i].avatarImage,
                    colorIndex: cards[i].colorIndex,
                    size: 42,
                  ),
                  title: cards[i].name,
                  subtitle: cards[i].personaExcerpt,
                  onTap: () => _use(context, cards[i]),
                  onLongPress: () => _delete(context, cards[i]),
                  trailing: jfRowTail(
                    active: cards[i].id == store.activeCharacterId,
                    onEdit: () => _openEdit(context, cards[i]),
                  ),
                ),
              ],
              const JFMa(44),
              JFButton(
                label: '创建新角色卡',
                primary: true,
                expand: true,
                icon: Icons.add,
                onPressed: () => _openEdit(context, null),
              ),
              const JFMa(26),
              Text(
                '角色卡保存在本机。点击某一行即切换到这个人物，'
                '每个角色各自保留自己的历史对话；铅笔可以修改它。',
                style: JF.tiny.copyWith(height: 1.9),
              ),
            ],
          ),
        );
      },
    );
  }
}
