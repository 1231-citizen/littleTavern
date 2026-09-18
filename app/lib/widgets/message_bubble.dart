import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/jf.dart';
import 'common.dart';

/// ============================================================
///  对话气泡（紧凑）
///  · 人物形象固定在气泡左上侧，点击即改人物设定
///  · 点击气泡本体 → 修改内容（并清除该条之后的对话）
///  · 长按 → 弹出「适中」的操作栏
/// ============================================================
class MessageBubble extends StatelessWidget {
  final ChatMessage m;
  final CharacterCard? card;
  final UserProfile user;
  final bool streaming;
  final String statusText;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onAvatarTap;
  final VoidCallback onToggleReasoning;
  final VoidCallback onEditReasoning;

  const MessageBubble({
    super.key,
    required this.m,
    required this.card,
    required this.user,
    required this.onTap,
    required this.onLongPress,
    required this.onAvatarTap,
    required this.onToggleReasoning,
    required this.onEditReasoning,
    this.streaming = false,
    this.statusText = '',
  });

  bool get _isUser => m.role == MsgRole.user;

  String get _name {
    if (_isUser) {
      final n = user.name.trim();
      return n.isEmpty ? '旅人' : n;
    }
    final n = (card?.name ?? '').trim();
    return n.isEmpty ? '角色' : n;
  }

  String get _avatar => _isUser ? user.avatar : (card?.avatar ?? '🌸');

  String? get _avatarImage => _isUser ? user.avatarImage : card?.avatarImage;

  int get _colorIndex => _isUser ? user.colorIndex : (card?.colorIndex ?? 0);

  bool get _pending => streaming && m.content.isEmpty && !m.hasReasoning;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth * 0.87;
        return Align(
          alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: AnimatedContainer(
              duration: JF.durFast,
              curve: JF.ease,
              decoration: _bubbleDecoration(),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(JF.rCard),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  splashColor: Colors.transparent,
                  highlightColor: (_isUser ? JF.sky : JF.mint).withValues(alpha: 0.06),
                  child: Padding(
                    // 紧凑：小内边距 + 发丝级留白
                    padding: const EdgeInsets.fromLTRB(10, 9, 13, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _header(context),
                        if (m.hasReasoning && m.showReasoning) ...[
                          const SizedBox(height: 8),
                          _reasoningBlock(context),
                        ],
                        if (m.error != null) ...[
                          const SizedBox(height: 8),
                          _errorBlock(context),
                        ],
                        const SizedBox(height: 5),
                        if (_pending)
                          _ThinkingLine(text: statusText.isEmpty ? '正在落笔…' : statusText, reasoning: false)
                        else
                          Text(m.content, style: JF.body.copyWith(color: JF.ink)),
                        if (streaming && !_pending) ...[
                          const SizedBox(height: 8),
                          _ThinkingLine(
                            text: statusText.isEmpty ? '正在书写…' : statusText,
                            reasoning: statusText.contains('思考'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _bubbleDecoration() {
    if (m.error != null) {
      return BoxDecoration(
        color: JF.pink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(JF.rCard),
        border: Border.all(color: JF.pink.withValues(alpha: 0.35), width: 0.8),
      );
    }
    if (_isUser) {
      return BoxDecoration(
        color: JF.sky.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(JF.rCard),
        border: Border.all(color: JF.sky.withValues(alpha: 0.28), width: 0.8),
      );
    }
    return BoxDecoration(
      color: JF.paper,
      borderRadius: BorderRadius.circular(JF.rCard),
      border: Border.all(color: JF.hairline, width: 0.8),
      boxShadow: JF.liftSoft,
    );
  }

  // ------------------------------------------------------------ 头部（人物形象在左上）
  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        JFAvatar(
          emoji: _avatar,
          imagePath: _avatarImage,
          colorIndex: _colorIndex,
          size: 30,
          onTap: onAvatarTap,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _name,
            style: JF.tiny.copyWith(color: JF.inkSecond),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (m.hasReasoning) ...[
          const SizedBox(width: 6),
          _ReasoningToggle(active: m.showReasoning, onTap: onToggleReasoning),
        ],
        const SizedBox(width: 10),
        Text(_hhmm(m.at), style: JF.tiny.copyWith(fontSize: 10)),
      ],
    );
  }

  // ------------------------------------------------------------ 思维链
  Widget _reasoningBlock(BuildContext context) {
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
      decoration: BoxDecoration(
        color: JF.mint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(JF.rBtn),
        border: Border.all(color: JF.mint.withValues(alpha: 0.28), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 12, color: JF.inkSecond),
              const SizedBox(width: 6),
              Text('思维链', style: JF.tiny.copyWith(color: JF.inkSecond)),
              const Spacer(),
              // 思维链也可以像对话正文一样改
              Semantics(
                button: true,
                label: '修改思维链',
                child: InkWell(
                  onTap: onEditReasoning,
                  borderRadius: BorderRadius.circular(10),
                  splashColor: Colors.transparent,
                  highlightColor: JF.mint.withValues(alpha: 0.10),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(Icons.edit_outlined, size: 13, color: JF.inkSecond),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            (m.reasoning ?? '').trim(),
            style: JF.small.copyWith(color: JF.inkBody, height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _errorBlock(BuildContext context) {
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
      decoration: BoxDecoration(
        color: JF.paper,
        borderRadius: BorderRadius.circular(JF.rBtn),
        border: Border.all(color: JF.pink.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 13, color: JF.inkSecond),
          const SizedBox(width: 8),
          Expanded(child: Text(m.error!, style: JF.small.copyWith(color: JF.inkBody))),
        ],
      ),
    );
  }

  static String _hhmm(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ================================================================ 思维链开关
class _ReasoningToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _ReasoningToggle({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: active ? '隐藏思维链' : '显示思维链',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: JF.dur,
          curve: JF.ease,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: active ? JF.mint.withValues(alpha: 0.20) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active ? JF.mint.withValues(alpha: 0.45) : JF.hairline,
              width: 0.8,
            ),
          ),
          child: Text(
            active ? '思维链 · 开' : '思维链',
            style: JF.tiny.copyWith(fontSize: 10, color: active ? JF.inkBody : JF.muted),
          ),
        ),
      ),
    );
  }
}

// ================================================================ 流式呼吸提示
class _ThinkingLine extends StatefulWidget {
  final String text;
  final bool reasoning;

  const _ThinkingLine({required this.text, required this.reasoning});

  @override
  State<_ThinkingLine> createState() => _ThinkingLineState();
}

class _ThinkingLineState extends State<_ThinkingLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final color = widget.reasoning ? JF.mint : JF.sky;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!reduce)
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = ((_c.value + i * 0.18) % 1.0);
                final o = 0.25 + 0.75 * (1 - (t * 2 - 1).abs());
                return Container(
                  margin: const EdgeInsets.only(right: 3),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: o),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          )
        else
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 4),
        Text(widget.text, style: JF.tiny.copyWith(color: JF.inkSecond)),
      ],
    );
  }
}
