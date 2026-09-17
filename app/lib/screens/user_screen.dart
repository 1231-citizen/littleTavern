import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/botanical.dart';
import '../theme/jf.dart';
import '../widgets/common.dart';
import '../widgets/page.dart';

/// ============================================================
///  全局用户设定 —— 用户在当前对话中的名称与设定
/// ============================================================
class UserScreen extends StatefulWidget {
  final AppStore store;
  const UserScreen({super.key, required this.store});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  late final TextEditingController _name;
  late final TextEditingController _persona;
  late String _avatar;
  late int _color;
  late final TextEditingController _customAvatar;

  @override
  void initState() {
    super.initState();
    final u = widget.store.user;
    _name = TextEditingController(text: u.name);
    _persona = TextEditingController(text: u.persona);
    _avatar = u.avatar;
    _color = u.colorIndex;
    _customAvatar = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _persona.dispose();
    _customAvatar.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.store.updateUser(UserProfile(
      name: _name.text.trim().isEmpty ? '旅人' : _name.text.trim(),
      persona: _persona.text,
      avatar: _avatar,
      colorIndex: _color,
    ));
    if (mounted) {
      jfToast(context, '用户设定已保存');
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return JFPage(
      title: '全局用户设定',
      subtitle: '你在故事中的身份',
      trailing: JFButton(label: '保存', primary: true, dense: true, onPressed: _save),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 预览
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                JFAvatar(emoji: _avatar, colorIndex: _color, size: 56),
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
          JFButton(label: '保存用户设定', primary: true, expand: true, onPressed: _save),
          const JFMa(24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Botanical(size: 44, variant: 3, color: JF.powder),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '用户设定是全局的：切换角色卡时依然沿用，'
                  '因此你可以用同一个人身份，走进不同的故事。',
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
