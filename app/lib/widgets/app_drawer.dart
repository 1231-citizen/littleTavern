import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/api_screen.dart';
import '../screens/character_list_screen.dart';
import '../screens/user_screen.dart';
import '../screens/world_screen.dart';
import '../store.dart';
import '../theme/botanical.dart';
import '../theme/jf.dart';

/// ============================================================
///  左上角「栏」：世界背景 / API 接入 / 全局用户设定 / 酒馆人物管理
///  长按任意一行即可拖动，改变四者的先后次序（顺序会记住）
/// ============================================================
class AppDrawer extends StatelessWidget {
  final AppStore store;

  const AppDrawer({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 306,
      backgroundColor: JF.riceWhite,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(JF.rCard),
          bottomRight: Radius.circular(JF.rCard),
        ),
      ),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final order = store.drawerOrder;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- 头部：一株植物线描 ----------
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 20, 22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('小酒馆', style: JF.hero),
                            const SizedBox(height: 8),
                            Text('以「間」为骨，安静地讲故事', style: JF.tiny),
                          ],
                        ),
                      ),
                      const Botanical(size: 62, variant: 1, color: JF.mint),
                    ],
                  ),
                ),
                Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),

                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    itemCount: order.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final list = List<String>.of(order);
                      final moved = list.removeAt(oldIndex);
                      list.insert(newIndex, moved);
                      store.setDrawerOrder(list);
                    },
                    header: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                      child: Text('长按任意一行，可拖动改变次序', style: JF.tiny),
                    ),
                    footer: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                      child: Text(
                        '对话内容与角色卡仅保存在本机；\nAPI Key 也只写入本机存储。',
                        style: JF.tiny.copyWith(height: 1.9),
                      ),
                    ),
                    itemBuilder: (context, i) {
                      final key = order[i];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey<String>(key),
                        index: i,
                        child: _section(context, key),
                      );
                    },
                  ),
                ),

                Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
                  child: Text('v1.1 · 日系清新风', style: JF.tiny),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String key) {
    final card = store.activeCard;
    final world = store.activeWorld;
    final api = store.api;
    final u = store.user;

    switch (key) {
      case 'world':
        return _Item(
          icon: Icons.landscape_outlined,
          tint: JF.mint,
          title: '世界背景设定',
          subtitle: world == null ? '未设定 · 当前对话的前因后果' : '${world.displayName} · ${world.excerpt}',
          onTap: () => _push(context, WorldScreen(store: store)),
        );
      case 'api':
        return _Item(
          icon: Icons.hub_outlined,
          tint: JF.sky,
          title: 'API 接入',
          subtitle: api.apiKey.trim().isEmpty
              ? '未配置 · 模型 ${api.model}'
              : '${api.model} · 推理 ${reasoningLabel(api.reasoning)}',
          onTap: () => _push(context, ApiScreen(store: store)),
        );
      case 'user':
        return _Item(
          icon: Icons.person_outline,
          tint: JF.pink,
          title: '全局用户设定',
          subtitle: '${u.displayName} · ${u.personaExcerpt}',
          onTap: () => _push(context, UserScreen(store: store)),
        );
      default:
        return _Item(
          icon: Icons.groups_outlined,
          tint: JF.powder,
          title: '酒馆人物管理',
          subtitle: store.cards.isEmpty
              ? '还没有角色卡'
              : '${store.cards.length} 位角色'
                  '${card == null ? "" : " · 当前 ${card.name}"}',
          onTap: () => _push(context, CharacterListScreen(store: store)),
        );
    }
  }

  static void _push(BuildContext context, Widget page) {
    // 先取到 NavigatorState，再 pop 抽屉；否则 pop 之后 context 可能已失活
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => page));
  }
}

class _Item extends StatefulWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Item({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: JF.dur,
        curve: JF.ease,
        transform: Matrix4.translationValues(0, (_hover ? -0.5 : 0), 0),
        decoration: BoxDecoration(
          color: _hover ? widget.tint.withValues(alpha: 0.07) : Colors.transparent,
          borderRadius: BorderRadius.circular(JF.rBtn),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(JF.rBtn),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(JF.rBtn),
            splashColor: Colors.transparent,
            highlightColor: widget.tint.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.tint.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.tint.withValues(alpha: 0.40), width: 0.8),
                    ),
                    child: Icon(widget.icon, size: 16, color: JF.inkSecond),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.title, style: JF.body.copyWith(color: JF.ink)),
                        const SizedBox(height: 3),
                        Text(widget.subtitle, style: JF.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.drag_indicator, size: 15, color: JF.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
