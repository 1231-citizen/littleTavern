import 'package:flutter/material.dart';

import '../store.dart';
import '../theme/botanical.dart';
import '../theme/jf.dart';
import '../widgets/common.dart';
import '../widgets/page.dart';
import 'character_edit_screen.dart';

/// ============================================================
///  世界背景设定 —— 当前对话的前因后果
/// ============================================================
class WorldScreen extends StatefulWidget {
  final AppStore store;
  const WorldScreen({super.key, required this.store});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.store.activeSession?.world ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.store.setWorld(_ctrl.text);
    if (mounted) {
      jfToast(context, '世界背景已保存');
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.store.activeCard;

    if (card == null) {
      return JFPage(
        title: '世界背景设定',
        scroll: false,
        child: JFEmpty(
          title: '还没有角色卡',
          desc: '世界背景依附于一段对话，请先创建角色卡，再回来写下这个故事发生的地方。',
          variant: 3,
          action: JFButton(
            label: '创建角色卡',
            primary: true,
            icon: Icons.add,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CharacterEditScreen(store: widget.store)),
            ),
          ),
        ),
      );
    }

    return JFPage(
      title: '世界背景设定',
      subtitle: '当前对话 · ${card.name}',
      trailing: JFButton(label: '保存', primary: true, dense: true, onPressed: _save),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Botanical(size: 56, variant: 0, color: JF.mint),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  '写下故事发生的时间、地点、规则与前因后果。\n它会作为「世界背景」注入每一次请求。',
                  style: JF.small.copyWith(height: 1.9),
                ),
              ),
            ],
          ),
          const JFMa(38),
          JFField(
            label: '世界背景 / 前因后果',
            hint: '例如：明治四十四年的秋末，山间温泉旅馆「红叶亭」…',
            controller: _ctrl,
            maxLines: 12,
            minLines: 8,
            keyboardType: TextInputType.multiline,
          ),
          const JFMa(40),
          JFButton(label: '保存世界背景', primary: true, expand: true, onPressed: _save),
        ],
      ),
    );
  }
}
