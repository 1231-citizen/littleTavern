import 'package:flutter/material.dart';

/// ============================================================
///  日系清新风 (Japanese Fresh) 设计系统
///  Ma(間) / 侘寂 / 发丝级边框 / 植物线描 / 极轻字重
///  —— 所有页面只允许从这里取 token，禁止硬编码。
/// ============================================================
class JF {
  JF._();

  // ---------- 色板 ----------
  static const riceWhite = Color(0xFFFAFAF8); // 背景主色
  static const paper = Color(0xFFFFFFFF); // 背景辅色
  static const sky = Color(0xFF64B5F6); // 天空蓝
  static const mint = Color(0xFF98D8C8); // 薄荷绿
  static const pink = Color(0xFFFFB7C5); // 淡粉
  static const powder = Color(0xFFB8D4E3); // 粉蓝

  static const ink = Color(0xFF4A5568); // 正文主色
  static const inkBody = Color(0xFF6B7280); // 正文
  static const inkSecond = Color(0xFF7A8A9E); // 正文辅色（仅次要信息）
  static const muted = Color(0xFFB0B8C4); // 弱化（仅装饰/占位）
  static const border = Color(0xFFD4D4CF); // 温暖中性边框色

  // ---------- 发丝级边框 ----------
  /// 30% 不透明度 —— 卡片/容器描边
  static Color get hairline => border.withValues(alpha: 0.30);

  /// 40% 不透明度 —— 按钮描边
  static Color get hairlineStrong => border.withValues(alpha: 0.40);

  /// 分隔线（比边框更轻）
  static Color get hairlineFaint => border.withValues(alpha: 0.20);

  // ---------- 极轻阴影（绝不使用可见阴影） ----------
  static const List<BoxShadow> liftSoft = [
    BoxShadow(color: Color(0x08000000), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> liftHover = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  // ---------- 动效：慢而静（一律 500ms，禁止 <200ms） ----------
  static const Duration dur = Duration(milliseconds: 500);
  static const Duration durFast = Duration(milliseconds: 300); // 仅用于次要反馈
  static const Curve ease = Curves.easeInOut;

  // ---------- 圆角 ----------
  static const double rCard = 16; // rounded-xl
  static const double rBtn = 12; // rounded-lg
  static const double rChip = 12;

  // ---------- 字号 ----------
  static const double fsHero = 26;
  static const double fsH1 = 21;
  static const double fsH2 = 17;
  static const double fsH3 = 15;
  static const double fsBody = 14.5;
  static const double fsSmall = 12.5;
  static const double fsTiny = 11;

  // ---------- 字体族 ----------
  /// 由 main.dart 在启动时按资产是否可用决定是否注入
  static String? family;
  /// 中文回退族（系统内置，避免豆腐块）
  static const List<String> fallback = <String>[
    'Noto Sans SC',
    'Source Han Sans SC',
    'PingFang SC',
    'Microsoft YaHei',
  ];

  static TextStyle _base(double size, FontWeight w, Color c, {double? h, double? ls}) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: size,
      fontWeight: w,
      color: c,
      height: h,
      letterSpacing: ls,
      decoration: TextDecoration.none,
    );
  }

  /// 标题：font-extralight / tracking-wide
  static TextStyle get hero => _base(fsHero, FontWeight.w200, ink, h: 1.45, ls: 0.6);
  static TextStyle get h1 => _base(fsH1, FontWeight.w200, ink, h: 1.5, ls: 0.5);
  static TextStyle get h2 => _base(fsH2, FontWeight.w200, ink, h: 1.5, ls: 0.4);
  static TextStyle get h3 => _base(fsH3, FontWeight.w200, ink, h: 1.5, ls: 0.3);

  /// 正文：font-light / leading-relaxed
  static TextStyle get body => _base(fsBody, FontWeight.w300, ink, h: 1.75);
  static TextStyle get bodySoft => _base(fsBody, FontWeight.w300, inkBody, h: 1.75);
  static TextStyle get small => _base(fsSmall, FontWeight.w300, inkSecond, h: 1.6);
  static TextStyle get tiny => _base(fsTiny, FontWeight.w300, muted, h: 1.5, ls: 0.2);
  static TextStyle get mono => _base(fsSmall, FontWeight.w300, inkSecond, h: 1.6);

  /// 按钮文字
  static TextStyle get btn => _base(fsBody, FontWeight.w300, ink, ls: 0.3);
  static TextStyle get btnOnColor => _base(fsBody, FontWeight.w300, paper, ls: 0.3);

  // ---------- 常用装饰 ----------
  /// 卡片：bg-white + rounded-xl + hairline border，无可见阴影
  static BoxDecoration card({Color? color, bool hover = false}) => BoxDecoration(
        color: color ?? paper,
        borderRadius: BorderRadius.circular(rCard),
        border: Border.all(color: hairline, width: 0.8),
        boxShadow: hover ? liftHover : liftSoft,
      );

  /// 容器：更轻的描边
  static BoxDecoration panel({Color? color}) => BoxDecoration(
        color: color ?? riceWhite,
        borderRadius: BorderRadius.circular(rCard),
        border: Border.all(color: hairlineFaint, width: 0.8),
      );

  /// 底部单线输入框（floating label 由 JFUnderlineField 实现）
  static InputDecoration underline(String label, {String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: tiny,
      labelStyle: small,
      floatingLabelStyle: small.copyWith(color: inkSecond),
      suffixIcon: suffix,
      isDense: true,
      contentPadding: const EdgeInsets.only(top: 18, bottom: 8),
      border: UnderlineInputBorder(borderSide: BorderSide(color: border, width: 0.8)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: border, width: 0.8)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: sky, width: 0.8)),
      errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: pink, width: 0.8)),
      focusedErrorBorder: UnderlineInputBorder(borderSide: BorderSide(color: pink, width: 0.8)),
    );
  }

  // ---------- 主题 ----------
  static ThemeData theme() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: riceWhite,
      canvasColor: riceWhite,
      colorScheme: base.colorScheme.copyWith(
        primary: sky,
        secondary: mint,
        surface: paper,
        onSurface: ink,
        error: pink,
      ),
      dividerTheme: DividerThemeData(color: hairlineFaint, thickness: 0.8, space: 0.8),
      splashFactory: InkSparkle.splashFactory,
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
        fontFamily: family,
        fontFamilyFallback: fallback,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(rCard)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: _base(fsSmall, FontWeight.w300, riceWhite, h: 1.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rBtn)),
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: sky,
        linearTrackColor: Color(0x1464B5F6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? paper : riceWhite,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? sky.withValues(alpha: 0.75) : border.withValues(alpha: 0.35),
        ),
        trackOutlineColor: WidgetStateProperty.all(hairlineStrong),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: sky,
        selectionColor: sky.withValues(alpha: 0.18),
        selectionHandleColor: sky,
      ),
    );
  }
}
