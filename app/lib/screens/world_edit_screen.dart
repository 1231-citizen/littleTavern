import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/botanical.dart';
import '../theme/jf.dart';
import '../widgets/common.dart';
import '../widgets/page.dart';

/// ============================================================
///  世界背景编辑 —— 一张「世界」：名字 + 正文
///  与角色卡一样可以有好几张，随时切换
/// ============================================================
class WorldEditScreen extends StatefulWidget {
  final AppStore store;
  final WorldCard? world;

  const WorldEditScreen({super.key, required this.store, this.world});

  @override
  State<WorldEditScreen> createState() => _WorldEditScreenState();
}

class _WorldEditScreenState extends State<WorldEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _content;
  late bool _isNew;

  bool get _isExisting => widget.world != null && !_isNew;

  @override
  void initState() {
    super.initState();
    final w = widget.world;
    _isNew = w == null;
    _name = TextEditingController(text: w?.name ?? '');
    _content = TextEditingController(text: w?.content ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _content.dispose();
    super.dispose();
  }

  WorldCard _build() {
    final w = widget.world?.clone() ?? WorldCard();
    w.name = _name.text.trim();
    w.content = _content.text.trim();
    return w;
  }

  Future<bool> _save({bool activate = false}) async {
    if (_name.text.trim().isEmpty) {
      jfToast(context, '请先给这个世界起个名字');
      return false;
    }
    final w = _build();
    await widget.store.upsertWorld(w);
    if (activate) await widget.store.setActiveWorld(w.id);
    return true;
  }

  Future<void> _saveOnly() async {
    if (await _save()) {
      if (mounted) {
        jfToast(context, '世界背景已保存');
        Navigator.of(context).maybePop();
      }
    }
  }

  Future<void> _saveAndUse() async {
    if (await _save(activate: true)) {
      if (mounted) {
        jfToast(context, '已切换到「${_build().displayName}」');
        Navigator.of(context).maybePop();
      }
    }
  }

  Future<void> _delete() async {
    final w = widget.world;
    if (w == null) return;
    final ok = await showJFConfirm(
      context,
      title: '删除这张世界背景',
      message: '「${w.displayName}」会被删除，且无法恢复。',
      okLabel: '删除',
      danger: true,
    );
    if (!ok) return;
    await widget.store.deleteWorld(w.id);
    if (mounted) {
      jfToast(context, '已删除');
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return JFPage(
      title: _isNew ? '新增世界背景' : '编辑世界背景',
      subtitle: _isExisting ? '这张世界的名字与前因后果' : '给这个世界起个名字',
      trailing: JFButton(label: '保存', primary: true, dense: true, onPressed: _saveOnly),
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
                  '写下故事发生的时间、地点、规则与前因后果。\n'
                  '它会作为「世界背景」注入每一次请求。',
                  style: JF.small.copyWith(height: 1.9),
                ),
              ),
            ],
          ),
          const JFMa(38),
          JFField(
            label: '世界名称',
            hint: '例如：红叶亭的秋天',
            controller: _name,
            onChanged: (_) => setState(() {}),
          ),
          const JFMa(32),
          JFField(
            label: '世界背景 / 前因后果',
            hint: '例如：明治四十四年的秋末，山间温泉旅馆「红叶亭」…',
            controller: _content,
            maxLines: 12,
            minLines: 8,
            keyboardType: TextInputType.multiline,
          ),
          const JFMa(44),
          JFButton(
            label: _isExisting ? '保存并使用这个世界' : '创建并使用这个世界',
            primary: true,
            expand: true,
            icon: Icons.check,
            onPressed: _saveAndUse,
          ),
          const JFMa(12),
          JFButton(label: '仅保存', expand: true, onPressed: _saveOnly),
          if (_isExisting) ...[
            const JFMa(12),
            JFButton(
              label: '删除这张世界背景',
              expand: true,
              icon: Icons.delete_outline,
              onPressed: _delete,
            ),
          ],
        ],
      ),
    );
  }
}
