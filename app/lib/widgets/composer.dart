import 'package:flutter/material.dart';

import '../theme/jf.dart';

/// ============================================================
///  下侧方框：左侧输入文字，右侧按钮发送
/// ============================================================
class Composer extends StatefulWidget {
  final bool busy;
  final bool enabled;
  final String characterName;
  final bool apiReady;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final VoidCallback onTapApiWarning;
  final VoidCallback onNeedCharacter;

  const Composer({
    super.key,
    required this.busy,
    required this.enabled,
    required this.characterName,
    required this.apiReady,
    required this.onSend,
    required this.onStop,
    required this.onTapApiWarning,
    required this.onNeedCharacter,
  });

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final h = _ctrl.text.trim().isNotEmpty;
      if (h != _hasText) setState(() => _hasText = h);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _ctrl.text.trim();
    if (t.isEmpty || widget.busy || !widget.enabled) return;
    _ctrl.clear();
    setState(() => _hasText = false);
    widget.onSend(t);
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText && !widget.busy && widget.enabled;

    return Container(
      decoration: BoxDecoration(
        color: JF.riceWhite,
        border: Border(top: BorderSide(color: JF.hairlineFaint, width: 0.8)),
      ),
      padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 状态行：当前角色 / 未配置提示
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.enabled ? '与「${widget.characterName}」对话中' : '尚未选择角色卡',
                    style: JF.tiny,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!widget.apiReady)
                  GestureDetector(
                    onTap: widget.onTapApiWarning,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 12, color: JF.inkSecond),
                        const SizedBox(width: 5),
                        Text('未配置 API', style: JF.tiny.copyWith(color: JF.inkSecond)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 方框本体
          AnimatedContainer(
            duration: JF.dur,
            curve: JF.ease,
            decoration: BoxDecoration(
              color: JF.paper,
              borderRadius: BorderRadius.circular(JF.rCard),
              border: Border.all(
                color: _focus.hasFocus ? JF.sky.withValues(alpha: 0.45) : JF.hairline,
                width: 0.8,
              ),
              boxShadow: _focus.hasFocus ? JF.liftHover : JF.liftSoft,
            ),
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    maxLines: 5,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: JF.body.copyWith(color: JF.ink),
                    cursorColor: JF.sky,
                    cursorWidth: 1.0,
                    onTap: widget.enabled ? null : widget.onNeedCharacter,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      hintText: widget.enabled ? '写点什么…' : '请先创建角色卡',
                      hintStyle: JF.small.copyWith(color: JF.muted),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _SendButton(
                  busy: widget.busy,
                  enabled: canSend,
                  onTap: widget.busy ? widget.onStop : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  const _SendButton({required this.busy, required this.enabled, required this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.busy ? JF.pink : JF.sky;
    final active = widget.busy || widget.enabled;

    return Semantics(
      button: true,
      label: widget.busy ? '停止生成' : '发送',
      child: MouseRegion(
        cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: JF.dur,
          curve: JF.ease,
          transform: Matrix4.translationValues(0, (_hover && active) ? -0.5 : 0, 0),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.90) : JF.hairlineFaint,
            borderRadius: BorderRadius.circular(JF.rBtn),
            border: Border.all(
              color: active ? accent.withValues(alpha: 0.35) : JF.hairlineFaint,
              width: 0.8,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(JF.rBtn),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: active ? widget.onTap : null,
              splashColor: Colors.transparent,
              highlightColor: Colors.white.withValues(alpha: 0.12),
              child: Icon(
                widget.busy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                size: 18,
                color: active ? JF.paper : JF.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
