import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/botanical.dart';
import '../theme/jf.dart';

/// 头像可用色调（全部落在日系清新风的柔和区间内）
const List<Color> kAvatarPalette = <Color>[
  JF.sky,
  JF.mint,
  JF.pink,
  JF.powder,
  Color(0xFFD9C7A7), // 亚麻
  Color(0xFFC7B9E0), // 淡藤
];

Color avatarColor(int i) => kAvatarPalette[i.abs() % kAvatarPalette.length];

// ================================================================ 头像
class JFAvatar extends StatelessWidget {
  final String emoji;
  final int colorIndex;
  final double size;
  final VoidCallback? onTap;
  final bool ring;

  const JFAvatar({
    super.key,
    required this.emoji,
    this.colorIndex = 0,
    this.size = 34,
    this.onTap,
    this.ring = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = avatarColor(colorIndex);
    final box = AnimatedContainer(
      duration: JF.dur,
      curve: JF.ease,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.22),
        shape: BoxShape.circle,
        border: ring ? Border.all(color: c.withValues(alpha: 0.45), width: 0.8) : null,
      ),
      child: Text(
        emoji,
        style: TextStyle(
          fontSize: size * 0.46,
          height: 1.0,
          fontFamily: JF.family,
          fontFamilyFallback: JF.fallback,
        ),
      ),
    );
    if (onTap == null) return box;
    return Semantics(
      button: true,
      label: '编辑人物设定',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: box,
      ),
    );
  }
}

// ================================================================ 按钮
class JFButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool primary;
  final bool expand;
  final bool dense;
  final VoidCallback? onPressed;

  const JFButton({
    super.key,
    required this.label,
    this.icon,
    this.primary = false,
    this.expand = false,
    this.dense = false,
    this.onPressed,
  });

  @override
  State<JFButton> createState() => _JFButtonState();
}

class _JFButtonState extends State<JFButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final primary = widget.primary;
    final bg = primary ? JF.sky.withValues(alpha: enabled ? 0.90 : 0.35) : JF.paper;
    final fg = primary ? JF.paper : JF.inkSecond;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: widget.dense ? 14 : 16, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: JF.btn.copyWith(color: fg),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: JF.dur,
        curve: JF.ease,
        transform: Matrix4.translationValues(0, (_hover && enabled) ? -0.5 : 0, 0),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(JF.rBtn),
          border: Border.all(
            color: primary ? JF.sky.withValues(alpha: 0.30) : JF.hairlineStrong,
            width: 0.8,
          ),
          boxShadow: (_hover && enabled) ? JF.liftHover : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(JF.rBtn),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onPressed,
            splashColor: Colors.transparent,
            highlightColor: primary
                ? Colors.white.withValues(alpha: 0.10)
                : JF.sky.withValues(alpha: 0.06),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.dense ? 12 : 18,
                vertical: widget.dense ? 8 : 12,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================ 输入框（仅底线 + 浮动标签）
class JFField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final int maxLines;
  final int minLines;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? errorText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  const JFField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.maxLines = 1,
    this.minLines = 1,
    this.obscure = false,
    this.keyboardType,
    this.errorText,
    this.suffix,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: obscure ? 1 : maxLines,
      minLines: obscure ? 1 : minLines,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: JF.body,
      cursorColor: JF.sky,
      cursorWidth: 1.0,
      decoration: JF.underline(label, hint: hint, suffix: suffix).copyWith(
        errorText: errorText,
        errorStyle: JF.tiny.copyWith(color: JF.pink),
      ),
    );
  }
}

// ================================================================ 分区标题
class JFSectionLabel extends StatelessWidget {
  final String text;
  final String? trailing;

  const JFSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(text, style: JF.h3)),
          if (trailing != null) Text(trailing!, style: JF.tiny),
        ],
      ),
    );
  }
}

// ================================================================ 列表行
class JFRow extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const JFRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<JFRow> createState() => _JFRowState();
}

class _JFRowState extends State<JFRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: JF.dur,
        curve: JF.ease,
        color: _hover ? JF.sky.withValues(alpha: 0.04) : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          splashColor: Colors.transparent,
          highlightColor: JF.sky.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            child: Row(
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.title, style: JF.body.copyWith(color: JF.ink)),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle!,
                          style: JF.small,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                widget.trailing ??
                    const Icon(Icons.chevron_right, size: 16, color: JF.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================ 空状态
class JFEmpty extends StatelessWidget {
  final String title;
  final String desc;
  final int variant;
  final Widget? action;

  const JFEmpty({
    super.key,
    required this.title,
    required this.desc,
    this.variant = 0,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Botanical(size: 92, variant: variant, color: JF.mint),
            const SizedBox(height: 32),
            Text(title, style: JF.h2, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(desc, style: JF.small, textAlign: TextAlign.center),
            ),
            if (action != null) ...[
              const SizedBox(height: 32),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ================================================================ 底部弹栏（适中的栏）
Future<T?> showJFSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  bool scrollable = true,
  double maxHeightFactor = 0.78,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: JF.ink.withValues(alpha: 0.18),
    builder: (ctx) {
      final h = MediaQuery.of(ctx).size.height * maxHeightFactor;
      return AnimatedPadding(
        duration: JF.dur,
        curve: JF.ease,
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: h),
          decoration: BoxDecoration(
            color: JF.paper,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(JF.rCard)),
            border: Border(top: BorderSide(color: JF.hairline, width: 0.8)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 34,
                height: 2,
                decoration: BoxDecoration(
                  color: JF.hairlineStrong,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 14, 14),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: JF.h2)),
                    _SheetClose(onTap: () => Navigator.of(ctx).pop()),
                  ],
                ),
              ),
              Divider(height: 0.8, thickness: 0.8, color: JF.hairlineFaint),
              Flexible(
                child: scrollable
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
                        child: child,
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
                        child: child,
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SheetClose extends StatelessWidget {
  final VoidCallback onTap;
  const _SheetClose({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.close, size: 17, color: JF.muted),
      ),
    );
  }
}

// ================================================================ 确认框
Future<bool> showJFConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String okLabel = '确定',
  String cancelLabel = '取消',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierColor: JF.ink.withValues(alpha: 0.16),
    builder: (ctx) => Dialog(
      backgroundColor: JF.paper,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JF.rCard),
        side: BorderSide(color: JF.hairline, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 26, 26, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: JF.h3),
            const SizedBox(height: 14),
            Text(message, style: JF.bodySoft),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                JFButton(label: cancelLabel, dense: true, onPressed: () => Navigator.of(ctx).pop(false)),
                const SizedBox(width: 10),
                JFButton(
                  label: okLabel,
                  dense: true,
                  primary: true,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return r ?? false;
}

// ================================================================ 多行文本编辑器
Future<String?> showJFTextEditor(
  BuildContext context, {
  required String title,
  required String initial,
  String hint = '',
  String? note,
  int maxLines = 12,
}) async {
  final ctrl = TextEditingController(text: initial);
  final result = await showJFSheet<String>(
    context,
    title: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note != null) ...[
          Text(note, style: JF.small),
          const SizedBox(height: 20),
        ],
        JFField(
          label: hint.isEmpty ? '内容' : hint,
          controller: ctrl,
          maxLines: maxLines,
          minLines: 4,
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: JFButton(
                label: '保存',
                primary: true,
                expand: true,
                onPressed: () => Navigator.of(context).pop(ctrl.text),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result;
}

// ================================================================ 杂项
void jfToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1800),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      ),
    );
}

Future<void> jfCopy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) jfToast(context, '已复制');
}

/// 顶部发丝级分隔的标题栏
class JFHeader extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? trailing;

  const JFHeader({super.key, this.leading, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: JF.riceWhite,
        border: Border(bottom: BorderSide(color: JF.hairlineFaint, width: 0.8)),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        bottom: 10,
        left: 8,
        right: 8,
      ),
      child: Row(
        children: [
          if (leading != null) leading! else const SizedBox(width: 40),
          Expanded(child: title),
          if (trailing != null) trailing! else const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class JFIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;

  const JFIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.semanticLabel = '',
    this.size = 19,
  });

  @override
  State<JFIconButton> createState() => _JFIconButtonState();
}

class _JFIconButtonState extends State<JFIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: JF.dur,
          curve: JF.ease,
          decoration: BoxDecoration(
            color: _hover ? JF.sky.withValues(alpha: 0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(22),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(widget.icon, size: widget.size, color: JF.inkSecond),
            ),
          ),
        ),
      ),
    );
  }
}
