// DeliveryFlow's visual language, ported verbatim into Delivery
// Management so the two apps look like siblings: the default (blue)
// preset — seed 0xFF0A84FF, light gradient background, translucent
// white cards, Cairo typeface — plus the floating glass nav bar and
// the static aurora background (DeliveryFlow's aurora is static, not
// animated: pre-blurred blobs cached behind a RepaintBoundary).
//
// Source of truth: DeliveryFlow lib/theme/app_theme.dart (preset 0)
// and lib/theme/design_system.dart (AuroraBackground, GlassNavBar).
// This file copies the values; it does not invent a new style.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// DeliveryFlow's palette (default preset).
class DmPalette {
  static const Color primaryBlue = Color(0xFF0A84FF);
  static const Color skyBlue = Color(0xFF5AC8FA);
  static const Color glassTint = Color(0xFFE5F1FF);
  static const Color darkSurface = Color(0xFF1C1C1E);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, skyBlue],
  );
}

/// Material 3 themes matching DeliveryFlow's AppTheme (preset 0).
class DmTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: DmPalette.primaryBlue,
      brightness: Brightness.light,
    ).copyWith(
      surface: DmPalette.glassTint,
      surfaceContainerHighest: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
      // Transparent so the aurora background behind every screen shows.
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DmPalette.primaryBlue, width: 1.6),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? DmPalette.primaryBlue
                : null),
      ),
      textTheme: _textTheme(),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: DmPalette.primaryBlue,
      brightness: Brightness.dark,
    ).copyWith(
      surface: DmPalette.darkSurface,
      surfaceContainerHighest: const Color(0xFF2C2C2E),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DmPalette.primaryBlue, width: 1.6),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? DmPalette.primaryBlue
                : null),
      ),
      textTheme: _textTheme(),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme() {
    // Cairo: DeliveryFlow's Arabic-first typeface, same weights.
    const family = 'Cairo';
    return const TextTheme(
      displayLarge: TextStyle(fontFamily: family, fontWeight: FontWeight.w800),
      displayMedium: TextStyle(fontFamily: family, fontWeight: FontWeight.w800),
      headlineSmall: TextStyle(fontFamily: family, fontWeight: FontWeight.w800),
      headlineMedium:
          TextStyle(fontFamily: family, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(fontFamily: family, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontFamily: family, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontFamily: family, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontFamily: family),
      bodyMedium: TextStyle(fontFamily: family),
      bodySmall: TextStyle(fontFamily: family),
      labelLarge: TextStyle(fontFamily: family, fontWeight: FontWeight.w700),
    );
  }
}

/// DeliveryFlow's static aurora background (default preset): a light
/// gradient with four pre-blurred color blobs. Dark mode keeps the
/// blobs very subtle so the background reads as true near-black.
class DmAuroraBackground extends StatelessWidget {
  const DmAuroraBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blobs = isDark
        ? const [
            Color(0xFF0A84FF),
            Color(0xFF5AC8FA),
            Color(0xFF004FC4),
            Color(0xFF7DD3FC),
          ]
        : const [
            Color(0xFF9ECDFF),
            Color(0xFFBDE3FF),
            Color(0xFF5AC8FA),
            Color(0xFFD6EBFF),
          ];
    final bg = isDark
        ? const [Color(0xFF1C1C1E), Color(0xFF101012)]
        : const [Color(0xFFE5F1FF), Color(0xFFFFFFFF)];
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bg,
          ),
        ),
        child: Stack(
          children: [
            _blob(
              top: -70,
              left: -70,
              size: 330,
              color: blobs[0],
              opacity: isDark ? 0.14 : 0.55,
            ),
            _blob(
              top: 130,
              right: -90,
              size: 290,
              color: blobs[1],
              opacity: isDark ? 0.10 : 0.5,
            ),
            _blob(
              bottom: -70,
              left: 30,
              size: 310,
              color: blobs[2],
              opacity: isDark ? 0.08 : 0.45,
            ),
            _blob(
              bottom: 90,
              right: 50,
              size: 240,
              color: blobs[3],
              opacity: isDark ? 0.06 : 0.38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color color,
    required double opacity,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 72, sigmaY: 72),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}

/// DeliveryFlow's floating glass nav bar (GlassNavBar, without the
/// liquid-glass trial overlay): a blurred translucent pill floating
/// above the content, with a gradient pill on the selected item.
class DmGlassNavBar extends StatelessWidget {
  const DmGlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.icons,
    required this.labels,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<IconData> icons;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: 0.14),
                          Colors.white.withValues(alpha: 0.06),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.8),
                          Colors.white.withValues(alpha: 0.55),
                        ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.7),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < labels.length; i++) _item(context, i),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int i) {
    final selected = i == selectedIndex;
    final scheme = Theme.of(context).colorScheme;
    return _PressScale(
      onTap: () => onDestinationSelected(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding:
            EdgeInsets.symmetric(horizontal: selected ? 16 : 10, vertical: 8),
        decoration: selected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: DmPalette.brandGradient,
                boxShadow: [
                  BoxShadow(
                    color: DmPalette.primaryBlue.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icons[i],
              size: 24,
              color: selected
                  ? Colors.white
                  : scheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 2),
            Text(
              labels[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Press scale (DeliveryFlow's Pressable pressedScale 0.9 behaviour).
class _PressScale extends StatefulWidget {
  const _PressScale({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}
