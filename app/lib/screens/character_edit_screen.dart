import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/botanical.dart';
import '../theme/jf.dart';
import '../widgets/common.dart';
import '../widgets/page.dart';

/// ============================================================
///  角色卡编辑 —— 人物名称 / 人物设定 / 人物外在形象
///  （对话必须先有角色卡）
/// ============================================================
class CharacterEditScreen extends StatefulWidget {
  final AppStore store;
  final CharacterCard? card;

  const CharacterEditScreen({super.key, required this.store, this.card});

  @override
  State<CharacterEditScreen> createState() => _CharacterEditScreenState();
}

class _CharacterEditScreenState extends State<CharacterEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _persona;
  late final TextEditingController _appearance;
  late final TextEditingController _customAvatar;

  late String _avatar;
  late int _color;
  bool _isNew = false;

  bool get _isExisting => widget.card != null && !_isNew;

  @override
  void initState() {
    super.initState();
    final c = widget.card;
    _isNew = c == null;
    _name = TextEditingController(text: c?.name ?? '');
    _persona = TextEditingController(text: c?.persona ?? '');
    _appearance = TextEditingController(text: c?.appearance ?? '');
    _avatar = c?.avatar ?? '🌸';
    _color = c?.colorIndex ?? 0;
    _customAvatar = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _persona.dispose();
    _appearance.dispose();
    _customAvatar.dispose();
    super.dispose();
  }

  CharacterCard _build() {
    final c = widget.card?.clone() ?? CharacterCard();
    c.name = _name.text.trim();
    c.persona = _persona.text.trim();
    c.appearance = _appearance.text.trim();
    c.avatar = _avatar;
    c.colorIndex = _color;
    return c;
  }

  Future<bool> _save({bool activate = false}) async {
    if (_name.text.trim().isEmpty) {
      jfToast(context, '请先填写人物名称');
      return false;
    }
    final card = _build();
    await widget.store.upsertCard(card);
    if (activate) await widget.store.setActiveCharacter(card.id);
    return true;
  }

  Future<void> _saveOnly() async {
    if (await _save()) {
      if (mounted) {
        jfToast(context, '角色卡已保存');
        Navigator.of(context).maybePop();
      }
    }
  }

  Future<void> _saveAndChat() async {
    if (await _save(activate: true)) {
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    }
  }

  Future<void> _delete() async {
    final card = widget.card;
    if (card == null) return;
    final ok = await showJFConfirm(
      context,
      title: '删除角色卡',
      message: '「${card.name}」及其全部对话记录都会被删除，且无法恢复。',
      okLabel: '删除',
      danger: true,
    );
    if (!ok) return;
    await widget.store.deleteCard(card.id);
    if (mounted) {
      jfToast(context, '已删除');
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return JFPage(
      title: _isNew ? '创建角色卡' : '编辑角色卡',
      subtitle: _isExisting ? '人物设定与外在形象' : '填好三要素即可开始对话',
      trailing: JFButton(label: '保存', primary: true, dense: true, onPressed: _saveOnly),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- 预览 ----------
          Center(
            child: Column(
              children: [
                JFAvatar(emoji: _avatar, colorIndex: _color, size: 76),
                const SizedBox(height: 16),
                Text(
                  _name.text.trim().isEmpty ? '未命名角色' : _name.text.trim(),
                  style: JF.h1,
                ),
              ],
            ),
          ),
          const JFMa(38),
          Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
          const JFMa(34),

          JFField(
            label: '人物名称',
            hint: '角色的名字',
            controller: _name,
            onChanged: (_) => setState(() {}),
          ),
          const JFMa(32),
          JFField(
            label: '人物设定',
            hint: '性格、来历、说话方式、与用户的关系…',
            controller: _persona,
            maxLines: 10,
            minLines: 6,
            keyboardType: TextInputType.multiline,
          ),
          const JFMa(32),
          JFField(
            label: '人物外在形象',
            hint: '身高体型、发型发色、衣着、随身物件、气质…',
            controller: _appearance,
            maxLines: 8,
            minLines: 4,
            keyboardType: TextInputType.multiline,
          ),

          const JFMa(48),
          const JFSectionLabel('人物形象'),
          EmojiPicker(
            selected: _avatar,
            onChanged: (v) => setState(() {
              _avatar = v;
              _customAvatar.clear();
            }),
          ),
          const JFMa(20),
          JFField(
            label: '或自定义一个符号',
            hint: '任意 emoji 或单个汉字',
            controller: _customAvatar,
            onChanged: (v) {
              final t = v.trim();
              if (t.isNotEmpty) setState(() => _avatar = t);
            },
          ),
          const JFMa(34),
          const JFSectionLabel('色调'),
          ColorPicker(selected: _color, onChanged: (i) => setState(() => _color = i)),

          const JFMa(52),
          JFButton(
            label: _isExisting ? '保存并开始对话' : '创建并开始对话',
            primary: true,
            expand: true,
            icon: Icons.chat_bubble_outline,
            onPressed: _saveAndChat,
          ),
          const JFMa(12),
          JFButton(label: '仅保存', expand: true, onPressed: _saveOnly),
          if (_isExisting) ...[
            const JFMa(12),
            JFButton(
              label: '删除这张角色卡',
              expand: true,
              icon: Icons.delete_outline,
              onPressed: _delete,
            ),
          ],

          const JFMa(40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Botanical(size: 46, variant: 0, color: JF.mint),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '这三项会作为「角色卡」注入每次请求：\n'
                  '人物名称决定称谓，人物设定决定性格与语气，'
                  '外在形象让描写有具体的画面。',
                  style: JF.tiny.copyWith(height: 1.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
