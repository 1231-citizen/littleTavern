import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'jf.dart';

/// ============================================================
///  植物线描（botanical line drawing）
///  每个主要区块只放一株，绝不堆砌 —— 日系清新风的签名元素
/// ============================================================
class Botanical extends StatelessWidget {
  final double size;
  final Color? color;
  final int variant; // 0 叶枝 / 1 竹 / 2 花枝 / 3 草

  const Botanical({
    super.key,
    this.size = 64,
    this.color,
    this.variant = 0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _BotanicalPainter(
        color: (color ?? JF.mint).withValues(alpha: 0.55),
        variant: variant,
      ),
    );
  }
}

class _BotanicalPainter extends CustomPainter {
  final Color color;
  final int variant;

  _BotanicalPainter({required this.color, required this.variant});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fine = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;

    switch (variant % 4) {
      case 0:
        _leafBranch(canvas, w, h, p, fine);
        break;
      case 1:
        _bamboo(canvas, w, h, p, fine);
        break;
      case 2:
        _flowerBranch(canvas, w, h, p, fine);
        break;
      default:
        _grass(canvas, w, h, p, fine);
    }
  }

  void _leafBranch(Canvas c, double w, double h, Paint p, Paint fine) {
    // 主枝：从右下向左上舒展
    final stem = Path()
      ..moveTo(w * 0.12, h * 0.94)
      ..cubicTo(w * 0.30, h * 0.72, w * 0.42, h * 0.46, w * 0.78, h * 0.14);
    c.drawPath(stem, p);

    // 叶片
    _leaf(c, Offset(w * 0.30, h * 0.70), 0.42, -0.75, w * 0.22, fine);
    _leaf(c, Offset(w * 0.44, h * 0.52), 0.40, -2.35, w * 0.19, fine);
    _leaf(c, Offset(w * 0.56, h * 0.34), 0.38, -0.85, w * 0.16, fine);
    _leaf(c, Offset(w * 0.68, h * 0.22), 0.36, -2.5, w * 0.12, fine);

    // 芽尖
    c.drawCircle(Offset(w * 0.78, h * 0.14), 1.1, fine);
  }

  void _bamboo(Canvas c, double w, double h, Paint p, Paint fine) {
    for (var i = 0; i < 3; i++) {
      final x = w * (0.28 + i * 0.22);
      final topY = h * (0.12 + i * 0.10);
      final path = Path()
        ..moveTo(x, h * 0.95)
        ..cubicTo(x - w * 0.02, h * 0.66, x + w * 0.01, h * 0.40, x + w * 0.04, topY);
      c.drawPath(path, p);

      // 竹节
      for (var k = 1; k <= 3; k++) {
        final t = k / 4.0;
        final y = h * 0.95 + (topY - h * 0.95) * t;
        c.drawLine(Offset(x - 2.6, y), Offset(x + 2.6, y), fine);
      }
      // 细叶
      _leaf(c, Offset(x, topY + h * 0.06), 0.34, -0.9 + i * 0.3, w * 0.15, fine);
      _leaf(c, Offset(x, topY + h * 0.14), 0.32, -2.3 - i * 0.2, w * 0.13, fine);
    }
  }

  void _flowerBranch(Canvas c, double w, double h, Paint p, Paint fine) {
    final stem = Path()
      ..moveTo(w * 0.86, h * 0.92)
      ..cubicTo(w * 0.62, h * 0.78, w * 0.46, h * 0.58, w * 0.30, h * 0.26);
    c.drawPath(stem, p);

    // 小枝
    final twig = Path()
      ..moveTo(w * 0.52, h * 0.62)
      ..cubicTo(w * 0.62, h * 0.54, w * 0.72, h * 0.50, w * 0.80, h * 0.44);
    c.drawPath(twig, fine);

    _fivePetal(c, Offset(w * 0.30, h * 0.24), w * 0.11, fine);
    _fivePetal(c, Offset(w * 0.79, h * 0.43), w * 0.08, fine);
    _leaf(c, Offset(w * 0.62, h * 0.72), 0.40, -2.2, w * 0.17, fine);
  }

  void _grass(Canvas c, double w, double h, Paint p, Paint fine) {
    final rnd = math.Random(7);
    for (var i = 0; i < 5; i++) {
      final x = w * (0.18 + i * 0.16);
      final bend = (rnd.nextDouble() - 0.5) * w * 0.30;
      final top = h * (0.24 + rnd.nextDouble() * 0.18);
      final path = Path()
        ..moveTo(x, h * 0.94)
        ..quadraticBezierTo(x + bend * 0.5, h * 0.60, x + bend, top);
      c.drawPath(path, i.isEven ? p : fine);
    }
  }

  /// 一片叶子：以 base 为叶柄起点，angle 为指向，len 为长度
  void _leaf(Canvas c, Offset base, double angle, double _, double len, Paint p) {
    final a = angle;
    final tip = Offset(base.dx + math.cos(a) * len, base.dy + math.sin(a) * len);
    final mid = Offset((base.dx + tip.dx) / 2, (base.dy + tip.dy) / 2);
    final nx = -math.sin(a) * len * 0.32;
    final ny = math.cos(a) * len * 0.32;

    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(mid.dx + nx, mid.dy + ny, tip.dx, tip.dy)
      ..quadraticBezierTo(mid.dx - nx, mid.dy - ny, base.dx, base.dy);
    c.drawPath(path, p);

    // 叶脉（独立画笔，避免污染传入的 Paint）
    final vein = Paint()
      ..color = color.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.round;
    c.drawLine(base, tip, vein);
  }

  void _fivePetal(Canvas c, Offset center, double r, Paint p) {
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5 - math.pi / 2;
      final t = Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          center.dx + math.cos(a - 1.0) * r * 0.9,
          center.dy + math.sin(a - 1.0) * r * 0.9,
          t.dx,
          t.dy,
        )
        ..quadraticBezierTo(
          center.dx + math.cos(a + 1.0) * r * 0.9,
          center.dy + math.sin(a + 1.0) * r * 0.9,
          center.dx,
          center.dy,
        );
      c.drawPath(path, p);
    }
    c.drawCircle(center, r * 0.2, p);
  }

  @override
  bool shouldRepaint(covariant _BotanicalPainter old) =>
      old.color != color || old.variant != variant;
}
