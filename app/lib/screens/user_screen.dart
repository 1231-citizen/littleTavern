import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/jf.dart';
import '../widgets/common.dart';
import '../widgets/page.dart';
import 'user_edit_screen.dart';

/// ============================================================
///  用户设定管理 —— 与「酒馆人物管理」同一套用法：
///  点击一行即切换，铅笔进编辑页，长按删除
/// ============================================================
class UserScreen extends StatelessWidget {
  final AppStore store;
  const UserScreen({super.key, required this.store});

  Future<void> _openEdit(BuildContext context, UserProfile? profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserEditScreen(store: store, profile: profile)),
    );
  }

  Future<void> _use(BuildContext context, UserProfile u) async {
    await store.setActiveUser(u.id);
    if (context.mounted) jfToast(context, '已切换到「${u.displayName}」');
  }

  Future<void> _delete(BuildContext context, UserProfile u) async {
    if (store.userProfiles.length <= 1) {
      jfToast(context, '至少要留一套用户设定');
      return;
    }
    final ok = await showJFConfirm(
      context,
      title: '删除这套用户设定',
      message: '「${u.displayName}」会被删除，且无法恢复。',
      okLabel: '删除',
      danger: true,
    );
    if (!ok) return;
    await store.deleteUserProfile(u.id);
    if (context.mounted) jfToast(context, '已删除「${u.displayName}」');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final list = store.userProfiles;

        return JFPage(
          title: '全局用户设定',
          subtitle: '${list.length} 套设定 · 点击即切换',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
                JFRow(
                  leading: JFAvatar(
                    emoji: list[i].avatar,
                    imagePath: list[i].avatarImage,
                    colorIndex: list[i].colorIndex,
                    size: 42,
                  ),
                  title: list[i].displayName,
                  subtitle: list[i].personaExcerpt,
                  onTap: () => _use(context, list[i]),
                  onLongPress: () => _delete(context, list[i]),
                  trailing: jfRowTail(
                    active: list[i].id == store.activeUserProfileId,
                    onEdit: () => _openEdit(context, list[i]),
                  ),
                ),
              ],
              const JFMa(44),
              JFButton(
                label: '新增一套用户设定',
                primary: true,
                expand: true,
                icon: Icons.add,
                onPressed: () => _openEdit(context, null),
              ),
              const JFMa(26),
              Text(
                '点击某一套设定即切换当前身份，铅笔可以修改它。'
                '用户设定会注入每次请求，并显示在你的每条对话旁。',
                style: JF.tiny.copyWith(height: 1.9),
              ),
            ],
          ),
        );
      },
    );
  }
}
