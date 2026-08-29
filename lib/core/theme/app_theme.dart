import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema modern untuk aplikasi POS + Billiard.
/// Warna aksen hijau billiard, Material 3, rounded & airy.
/// Typography pakai Inter (google_fonts) supaya konsisten di semua platform.
class AppTheme {
  // Premium Emerald Colors
  static const Color billiardGreen = Color(0xFF10B981);
  static const Color billiardGreenDark = Color(0xFF047857);
  static const Color ink = Color(0xFF0F172A); // Rich Slate Dark
  static const Color surface = Color(0xFFF8FAFC); // Clean Slate Light
  static const Color surfaceDark = Color(0xFF0F172A); // Deep Slate

  static const Color tableFree = Color(0xFF10B981); // Emerald 500
  static const Color tableUsed = Color(0xFFEF4444); // Red 500
  static const Color tableReserved = Color(0xFFF59E0B); // Amber 500
  static const Color tableTimeout = Color(0xFF991B1B); // Red 800

  /// Ikon billiard (material tidak punya ikon bola 8 — pakai ikon esports).
  static const IconData billiardIcon = Icons.sports_esports_rounded;

  // ===== Breakpoints responsif =====
  /// Lebar layar < 900: bottom navigation (mobile/portrait tablet).
  static const double kMobileMaxWidth = 900;

  /// Lebar layar >= 900 & < 1200: compact rail (tablet landscape).
  static const double kRailMaxWidth = 1200;

  /// Lebar konten maksimal supaya layout tetap rapi di monitor lebar.
  static const double kContentMaxWidth = 1240;

  static VisualDensity get _density => switch (defaultTargetPlatform) {
        TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux =>
          VisualDensity.standard,
        _ => VisualDensity.adaptivePlatformDensity,
      };

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: billiardGreen,
      brightness: Brightness.light,
      surface: surface,
    );
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      fontFamily: GoogleFonts.inter().fontFamily,
      visualDensity: _density,
      splashFactory: InkSparkle.splashFactory,
      textTheme: baseTextTheme.copyWith(
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: ink,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: ink,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: ink,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: ink),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 16, color: ink),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: ink),
        labelLarge: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          side: BorderSide(color: const Color(0xFFCBD5E1).withValues(alpha: 0.45), width: 1),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
        labelStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
        prefixIconColor: Colors.grey.shade500,
        suffixIconColor: Colors.grey.shade500,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: billiardGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: tableUsed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: tableUsed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(
          backgroundColor: billiardGreen,
          foregroundColor: Colors.white,
          overlayColor: billiardGreenDark,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(
          backgroundColor: Colors.transparent,
          foregroundColor: ink,
          overlayColor: Colors.grey.shade100,
          side: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: billiardGreen,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: billiardGreen.withValues(alpha: 0.15),
        side: BorderSide(color: Colors.grey.shade200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: ink),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w800,
          fontSize: 19,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Navigasi mobile (bottom bar)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        height: 70,
        indicatorColor: billiardGreen.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? billiardGreenDark : Colors.grey.shade500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? billiardGreenDark : Colors.grey.shade500,
          ),
        ),
      ),
      // Navigasi tablet (rail)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: billiardGreen.withValues(alpha: 0.14),
        selectedIconTheme: const IconThemeData(color: billiardGreenDark),
        selectedLabelTextStyle:
            const TextStyle(color: billiardGreenDark, fontWeight: FontWeight.w800, fontSize: 11),
        unselectedIconTheme: IconThemeData(color: Colors.grey.shade500),
        unselectedLabelTextStyle:
            TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 11),
        labelType: NavigationRailLabelType.all,
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: billiardGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? billiardGreenDark : ink,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? billiardGreen.withValues(alpha: 0.12)
                : Colors.white,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: Colors.grey.shade300)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : Colors.grey.shade400,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? billiardGreen
              : Colors.grey.shade300,
        ),
        trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: billiardGreen),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      datePickerTheme: DatePickerThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Colors.grey.shade400),
        radius: const Radius.circular(8),
        thickness: WidgetStatePropertyAll(6),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: billiardGreen,
      brightness: Brightness.dark,
      surface: surfaceDark,
    );
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaceDark,
      fontFamily: GoogleFonts.inter().fontFamily,
      visualDensity: _density,
      textTheme: baseTextTheme.copyWith(
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E293B), // Slate 800
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(22))),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: surfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: billiardGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(
          backgroundColor: billiardGreen,
          foregroundColor: Colors.white,
          overlayColor: billiardGreenDark,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          overlayColor: Colors.white.withValues(alpha: 0.08),
          side: BorderSide(color: Colors.grey.shade700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: billiardGreen,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1E293B),
        selectedColor: billiardGreen.withValues(alpha: 0.25),
        side: BorderSide(color: Colors.grey.shade800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade800, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        height: 70,
        indicatorColor: billiardGreen.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? billiardGreen : Colors.grey.shade400,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? billiardGreen : Colors.grey.shade400,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: billiardGreen.withValues(alpha: 0.25),
        selectedIconTheme: const IconThemeData(color: billiardGreen),
        selectedLabelTextStyle:
            const TextStyle(color: billiardGreen, fontWeight: FontWeight.w800, fontSize: 11),
        unselectedIconTheme: IconThemeData(color: Colors.grey.shade400),
        unselectedLabelTextStyle:
            TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600, fontSize: 11),
        labelType: NavigationRailLabelType.all,
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: billiardGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: billiardGreen),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Colors.grey.shade600),
        radius: const Radius.circular(8),
        thickness: WidgetStatePropertyAll(6),
      ),
    );
  }

  /// Gaya tombol bersama: rounded, hover overlay (desktop), disabled lembut.
  static ButtonStyle _buttonStyle({
    required Color backgroundColor,
    required Color foregroundColor,
    required Color overlayColor,
    BorderSide? side,
  }) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? backgroundColor.withValues(alpha: 0.4)
            : backgroundColor,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? Colors.grey.shade500 : foregroundColor,
      ),
      overlayColor: WidgetStatePropertyAll(overlayColor.withValues(alpha: 0.12)),
      side: side == null ? null : WidgetStatePropertyAll(side),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
    );
  }
}
