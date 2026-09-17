import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/jf.dart';
import '../widgets/common.dart';
import '../widgets/page.dart';
import 'character_edit_screen.dart';

/// ============================================================
///  酒馆人物管理 —— 管理 / 创建角色卡
/// ============================================================
class CharacterListScreen extends StatelessWidget {
  final AppStore store;
  const CharacterListScreen({super.key, required this.store});

  Future<void> _openEdit(BuildContext context, CharacterCard card) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CharacterEditScreen(store: store, card: card)),
    );
  }

  Future<void> _openNew(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CharacterEditScreen(store: store)),
    );
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
                onPressed: () => _openNew(context),
              ),
            ),
          );
        }

        return JFPage(
          title: '酒馆人物管理',
          subtitle: '${cards.length} 位角色 · 长按可删除',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
                JFRow(
                  leading: JFAvatar(
                    emoji: cards[i].avatar,
                    colorIndex: cards[i].colorIndex,
                    size: 42,
                  ),
                  title: cards[i].name,
                  subtitle: cards[i].personaExcerpt,
                  onTap: () => _openEdit(context, cards[i]),
                  onLongPress: () => _delete(context, cards[i]),
                  trailing: cards[i].id == store.activeCharacterId
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: JF.mint.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: JF.mint.withValues(alpha: 0.45),
                              width: 0.8,
                            ),
                          ),
                          child: Text('当前', style: JF.tiny.copyWith(fontSize: 10, color: JF.inkBody)),
                        )
                      : const Icon(Icons.chevron_right, size: 16, color: JF.muted),
                ),
              ],
              const JFMa(44),
              JFButton(
                label: '创建新角色卡',
                primary: true,
                expand: true,
                icon: Icons.add,
                onPressed: () => _openNew(context),
              ),
              const JFMa(26),
              Text(
                '角色卡保存在本机。切换角色卡即切换对话，历史记录互不干扰。',
                style: JF.tiny.copyWith(height: 1.9),
              ),
            ],
          ),
        );
      },
    );
  }
}
