import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/jf.dart';
import '../widgets/common.dart';
import '../widgets/page.dart';
import 'world_edit_screen.dart';

/// ============================================================
///  世界背景管理 —— 与「酒馆人物管理」同一套用法：
///  点击一行即切换，铅笔进编辑页，长按删除
/// ============================================================
class WorldScreen extends StatelessWidget {
  final AppStore store;
  const WorldScreen({super.key, required this.store});

  Future<void> _openEdit(BuildContext context, WorldCard? world) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorldEditScreen(store: store, world: world)),
    );
  }

  Future<void> _use(BuildContext context, WorldCard w) async {
    await store.setActiveWorld(w.id);
    if (context.mounted) jfToast(context, '已切换到「${w.displayName}」');
  }

  Future<void> _delete(BuildContext context, WorldCard w) async {
    final ok = await showJFConfirm(
      context,
      title: '删除这张世界背景',
      message: '「${w.displayName}」会被删除，且无法恢复。',
      okLabel: '删除',
      danger: true,
    );
    if (!ok) return;
    await store.deleteWorld(w.id);
    if (context.mounted) jfToast(context, '已删除「${w.displayName}」');
  }

  Widget _leading() {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: JF.mint.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: JF.mint.withValues(alpha: 0.40), width: 0.8),
      ),
      child: const Icon(Icons.landscape_outlined, size: 17, color: JF.inkSecond),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final list = store.worlds;

        if (list.isEmpty) {
          return JFPage(
            title: '世界背景设定',
            subtitle: '当前对话的前因后果',
            scroll: false,
            child: JFEmpty(
              title: '还是一张白纸',
              desc: '写下故事发生的地方与前因后果，角色会更容易入戏。\n世界背景可以有好几张，随时更换。',
              variant: 0,
              action: JFButton(
                label: '写下第一个世界',
                primary: true,
                icon: Icons.add,
                onPressed: () => _openEdit(context, null),
              ),
            ),
          );
        }

        return JFPage(
          title: '世界背景设定',
          subtitle: '${list.length} 张世界 · 点击即切换',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
                JFRow(
                  leading: _leading(),
                  title: list[i].displayName,
                  subtitle: list[i].excerpt,
                  onTap: () => _use(context, list[i]),
                  onLongPress: () => _delete(context, list[i]),
                  trailing: jfRowTail(
                    active: list[i].id == store.activeWorldId,
                    onEdit: () => _openEdit(context, list[i]),
                  ),
                ),
              ],
              const JFMa(44),
              JFButton(
                label: '新增一张世界背景',
                primary: true,
                expand: true,
                icon: Icons.add,
                onPressed: () => _openEdit(context, null),
              ),
              const JFMa(26),
              Text(
                '点击某一张即切换当前世界，铅笔可以修改它。'
                '切换会同时作用于当前这段对话；每一段历史对话各自记得自己用的世界。',
                style: JF.tiny.copyWith(height: 1.9),
              ),
            ],
          ),
        );
      },
    );
  }
}
