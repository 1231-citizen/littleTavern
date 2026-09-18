import 'package:flutter/material.dart';

import '../theme/jf.dart';
import 'common.dart';

/// ============================================================
///  二级页骨架（发丝级顶栏 + 大量留白）
/// ============================================================
class JFPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final Widget? leading;
  final bool scroll;

  const JFPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.leading,
    this.scroll = true,
  });

  @override
  Widget build(BuildContext context) {
    final body = scroll
        ? SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              26,
              30,
              26,
              40 + MediaQuery.of(context).padding.bottom,
            ),
            child: child,
          )
        : Padding(
            padding: EdgeInsets.fromLTRB(
              26,
              24,
              26,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            child: child,
          );

    return Scaffold(
      backgroundColor: JF.riceWhite,
      body: Column(
        children: [
          JFHeader(
            leading: leading ??
                JFIconButton(
                  icon: Icons.arrow_back_ios_new,
                  size: 16,
                  semanticLabel: '返回',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: JF.h3, textAlign: TextAlign.center),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: JF.tiny, textAlign: TextAlign.center),
                ],
              ],
            ),
            trailing: trailing ?? const SizedBox(width: 40),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ================================================================ 单选项
class JFChips<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const JFChips({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: values.map((v) {
        final on = v == selected;
        return GestureDetector(
          onTap: () => onChanged(v),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: JF.dur,
            curve: JF.ease,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: on ? JF.sky.withValues(alpha: 0.14) : JF.paper,
              borderRadius: BorderRadius.circular(JF.rBtn),
              border: Border.all(
                color: on ? JF.sky.withValues(alpha: 0.45) : JF.hairline,
                width: 0.8,
              ),
            ),
            child: Text(
              label(v),
              style: JF.small.copyWith(color: on ? JF.ink : JF.inkSecond),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ================================================================ 开关行
class JFSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const JFSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: JF.body.copyWith(color: JF.ink)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: JF.tiny.copyWith(height: 1.7)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ================================================================ 滑动行
class JFSliderRow extends StatelessWidget {
  final String title;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const JFSliderRow({
    super.key,
    required this.title,
    required this.valueText,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 2,
    this.divisions = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: JF.body.copyWith(color: JF.ink))),
            Text(valueText, style: JF.small),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: JF.sky.withValues(alpha: 0.75),
            inactiveTrackColor: JF.hairlineFaint,
            thumbColor: JF.paper,
            overlayColor: JF.sky.withValues(alpha: 0.08),
            trackHeight: 1.4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ================================================================ 形象选择
const List<String> kEmojiSet = <String>[
  '🌸', '🍃', '🌙', '☁️', '🕊️', '🐈', '🦊', '🐇',
  '🍵', '📖', '🪷', '🌾', '❄️', '🕯️', '⭐', '🎐',
  '🏮', '🗡️', '🪶', '🌊', '🍂', '🫧', '🧧', '🎋',
];

/// 角色卡的符号形象（更改要求：由一整排减至五个）
const List<String> kEmojiSet5 = <String>['🌸', '🍃', '🌙', '🍵', '🕊️'];

class EmojiPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final List<String> emojis;

  const EmojiPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.emojis = kEmojiSet,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: emojis.map((e) {
        final on = e == selected;
        return GestureDetector(
          onTap: () => onChanged(e),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: JF.dur,
            curve: JF.ease,
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? JF.mint.withValues(alpha: 0.18) : JF.paper,
              borderRadius: BorderRadius.circular(JF.rBtn),
              border: Border.all(
                color: on ? JF.mint.withValues(alpha: 0.5) : JF.hairline,
                width: 0.8,
              ),
            ),
            child: Text(e, style: const TextStyle(fontSize: 18, height: 1.0)),
          ),
        );
      }).toList(),
    );
  }
}

/// ================================================================ 照片头像
/// 与符号形象并列的一栏：选一张照片当头像，或把照片去掉。
class PhotoPicker extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final bool busy;

  const PhotoPicker({
    super.key,
    required this.imagePath,
    required this.onPick,
    required this.onClear,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final has = imagePath != null && imagePath!.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        JFButton(
          label: busy
              ? '正在打开相册…'
              : (has ? '换一张照片' : '从相册选择照片'),
          icon: Icons.photo_camera_back_outlined,
          dense: true,
          onPressed: busy ? null : onPick,
        ),
        if (has) ...[
          const SizedBox(width: 10),
          JFButton(label: '移除照片', dense: true, onPressed: busy ? null : onClear),
        ],
      ],
    );
  }
}

class ColorPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const ColorPicker({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(kAvatarPalette.length, (i) {
        final c = kAvatarPalette[i];
        final on = i == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => onChanged(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: JF.dur,
              curve: JF.ease,
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: c.withValues(alpha: on ? 0.55 : 0.25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? c.withValues(alpha: 0.9) : c.withValues(alpha: 0.45),
                  width: on ? 1.0 : 0.8,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 区块之间的大留白
class JFMa extends StatelessWidget {
  final double height;
  const JFMa(this.height, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}
