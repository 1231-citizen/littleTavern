import 'package:flutter/material.dart';

import '../models.dart';
import '../pick_image.dart';
import '../store.dart';
import '../theme/botanical.dart';
import '../theme/jf.dart';
import '../widgets/common.dart';
import '../widgets/page.dart';

/// ============================================================
///  用户设定编辑 —— 一套「我」：名称 / 设定 / 形象
///  与角色卡一样可以有好几套，随时切换
/// ============================================================
class UserEditScreen extends StatefulWidget {
  final AppStore store;
  final UserProfile? profile;

  const UserEditScreen({super.key, required this.store, this.profile});

  @override
  State<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _persona;
  late final TextEditingController _customAvatar;

  late String _avatar;
  String? _avatarImage;
  late int _color;
  bool _isNew = false;
  bool _picking = false;

  bool get _isExisting => widget.profile != null && !_isNew;
  bool get _canDelete => _isExisting && widget.store.userProfiles.length > 1;

  @override
  void initState() {
    super.initState();
    final u = widget.profile;
    _isNew = u == null;
    _name = TextEditingController(text: u?.name ?? '');
    _persona = TextEditingController(text: u?.persona ?? '');
    _avatar = u?.avatar ?? '🍃';
    _avatarImage = u?.avatarImage;
    _color = u?.colorIndex ?? widget.store.userProfiles.length;
    _customAvatar = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _persona.dispose();
    _customAvatar.dispose();
    super.dispose();
  }

  UserProfile _build() {
    final u = widget.profile?.clone() ?? UserProfile();
    u.name = _name.text.trim().isEmpty ? '旅人' : _name.text.trim();
    u.persona = _persona.text.trim();
    u.avatar = _avatar;
    u.avatarImage = _avatarImage;
    u.colorIndex = _color;
    return u;
  }

  Future<void> _pickPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final path = await pickAvatarImage();
      if (!mounted) return;
      if (path != null) setState(() => _avatarImage = path);
    } catch (e) {
      if (mounted) jfToast(context, '$e');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<bool> _save({bool activate = false}) async {
    final profile = _build();
    await widget.store.upsertUserProfile(profile);
    if (activate) await widget.store.setActiveUser(profile.id);
    return true;
  }

  Future<void> _saveOnly() async {
    if (await _save()) {
      if (mounted) {
        jfToast(context, '用户设定已保存');
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
    final u = widget.profile;
    if (u == null) return;
    final ok = await showJFConfirm(
      context,
      title: '删除这套用户设定',
      message: '「${u.displayName}」会被删除，且无法恢复。',
      okLabel: '删除',
      danger: true,
    );
    if (!ok) return;
    await widget.store.deleteUserProfile(u.id);
    if (mounted) {
      jfToast(context, '已删除');
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return JFPage(
      title: _isNew ? '新增用户设定' : '编辑用户设定',
      subtitle: _isExisting ? '你的名称与设定' : '你就是故事里的这个人',
      trailing: JFButton(label: '保存', primary: true, dense: true, onPressed: _saveOnly),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                JFAvatar(
                  emoji: _avatar,
                  imagePath: _avatarImage,
                  colorIndex: _color,
                  size: 56,
                ),
                const SizedBox(width: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _name.text.trim().isEmpty ? '旅人' : _name.text.trim(),
                      style: JF.h2,
                    ),
                    const SizedBox(height: 6),
                    Text('这将显示在你的每条对话旁', style: JF.tiny),
                  ],
                ),
              ],
            ),
          ),
          const JFMa(40),
          Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
          const JFMa(34),

          JFField(
            label: '你的名称',
            hint: '旅人',
            controller: _name,
            onChanged: (_) => setState(() {}),
          ),
          const JFMa(30),
          JFField(
            label: '你的设定',
            hint: '身份、性格、与角色的关系…',
            controller: _persona,
            maxLines: 8,
            minLines: 5,
            keyboardType: TextInputType.multiline,
          ),

          const JFMa(46),
          const JFSectionLabel('形象'),
          EmojiPicker(
            selected: _avatar,
            onChanged: (v) => setState(() {
              _avatar = v;
              _customAvatar.clear();
            }),
          ),
          const JFMa(18),
          PhotoPicker(
            imagePath: _avatarImage,
            busy: _picking,
            onPick: _pickPhoto,
            onClear: () => setState(() => _avatarImage = null),
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

          const JFMa(38),
          const JFSectionLabel('色调'),
          ColorPicker(selected: _color, onChanged: (i) => setState(() => _color = i)),

          const JFMa(48),
          JFButton(
            label: _isExisting ? '保存并使用这套设定' : '创建并使用这套设定',
            primary: true,
            expand: true,
            icon: Icons.check,
            onPressed: _saveAndUse,
          ),
          const JFMa(12),
          JFButton(label: '仅保存', expand: true, onPressed: _saveOnly),
          if (_canDelete) ...[
            const JFMa(12),
            JFButton(
              label: '删除这套设定',
              expand: true,
              icon: Icons.delete_outline,
              onPressed: _delete,
            ),
          ],

          const JFMa(24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Botanical(size: 44, variant: 3, color: JF.powder),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '用户设定可以有好几套，像换角色卡一样随时切换。'
                  '因此你可以用不同的身份，走进不同的故事。',
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
