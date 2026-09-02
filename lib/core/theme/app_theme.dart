import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema DARK PREMIUM untuk aplikasi POS + Billiard.
///
/// Palet: navy pekat + emerald neon — modern ala SaaS dashboard,
/// nyaman di arena billiard yang redup. Material 3, rounded & airy.
/// Typography pakai Inter (google_fonts) supaya konsisten di semua platform.
class AppTheme {
  // ===== Brand & aksen =====
  static const Color billiardGreen = Color(0xFF10B981); // Emerald 500
  static const Color billiardGreenDark = Color(0xFF047857); // Emerald 700 — aksen teks di konten terang
  static const Color billiardGreenNeon = Color(0xFF34D399); // Emerald 400 — khusus elemen gelap (sidebar)

  // ===== Teks =====
  /// Teks utama di atas permukaan terang (konten).
  static const Color ink = Color(0xFF0F172A); // Rich Slate Dark
  /// Alias ink (semantik).
  static const Color inkOnLight = Color(0xFF0F172A);
  /// Teks utama di atas permukaan gelap (sidebar & elemen dark).
  static const Color inkOnDark = Color(0xFFEDF2FB);

  // ===== Permukaan (dark premium) =====
  static const Color surface = Color(0xFFF8FAFC); // scaffold tema light
  static const Color surfaceDark = Color(0xFF0B1220); // scaffold navy pekat
  static const Color panel = Color(0xFF0D1729); // panel / sidebar / bottom bar
  static const Color cardDark = Color(0xFF111C33); // kartu standar
  static const Color cardDarkHigh = Color(0xFF16233D); // kartu elevasi tinggi
  static const Color borderDark = Color(0xFF1E2C4C); // hairline
  static const Color borderDarkStrong = Color(0xFF2A3E66); // border input

  // ===== Warna status meja =====
  static const Color tableFree = Color(0xFF10B981); // Emerald 500
  static const Color tableUsed = Color(0xFFEF4444); // Red 500
  static const Color tableReserved = Color(0xFFF59E0B); // Amber 500
  static const Color tableTimeout = Color(0xFFDC2626); // Red 600

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

  // ===== Skema warna dark premium =====
  static const ColorScheme _darkScheme = ColorScheme.dark(
    brightness: Brightness.dark,
    primary: billiardGreenNeon,
    onPrimary: Color(0xFF06281D),
    primaryContainer: Color(0xFF064E3B),
    onPrimaryContainer: Color(0xFFA7F3D0),
    secondary: Color(0xFF22D3EE),
    onSecondary: Color(0xFF082F36),
    tertiary: Color(0xFFFBBF24),
    onTertiary: Color(0xFF451A03),
    error: Color(0xFFF87171),
    onError: Color(0xFF450A0A),
    surface: surfaceDark,
    onSurface: ink,
    onSurfaceVariant: Color(0xFF93A5C4),
    surfaceContainerLowest: Color(0xFF070E1C),
    surfaceContainerLow: cardDark,
    surfaceContainer: Color(0xFF13203C),
    surfaceContainerHigh: cardDarkHigh,
    surfaceContainerHighest: Color(0xFF1B2A49),
    outline: borderDarkStrong,
    outlineVariant: borderDark,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF050A14),
    inverseSurface: Color(0xFFEDF2FB),
    onInverseSurface: Color(0xFF0B1220),
    inversePrimary: Color(0xFF047857),
  );

  static ThemeData dark() {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkScheme,
      scaffoldBackgroundColor: surfaceDark,
      canvasColor: surfaceDark,
      fontFamily: GoogleFonts.inter().fontFamily,
      visualDensity: _density,
      splashFactory: InkSparkle.splashFactory,
      splashColor: billiardGreenNeon.withValues(alpha: 0.08),
      highlightColor: Colors.white.withValues(alpha: 0.04),
      hoverColor: Colors.white.withValues(alpha: 0.05),
      textTheme: baseTextTheme.copyWith(
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: const Color(0xFFF4F7FD),
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: const Color(0xFFF4F7FD),
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
        color: cardDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: const BorderSide(color: borderDark, width: 1),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: const Color(0xFFF4F7FD),
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0E1B33),
        hintStyle: const TextStyle(color: Color(0xFF5B6E93), fontWeight: FontWeight.w500),
        labelStyle: const TextStyle(color: Color(0xFF93A5C4), fontWeight: FontWeight.w600),
        prefixIconColor: const Color(0xFF7C90B4),
        suffixIconColor: const Color(0xFF7C90B4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderDarkStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: billiardGreenNeon, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: tableUsed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: tableUsed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(
          backgroundColor: billiardGreenNeon,
          foregroundColor: const Color(0xFF06281D),
          overlayColor: billiardGreen,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(
          backgroundColor: Colors.transparent,
          foregroundColor: ink,
          overlayColor: Colors.white,
          side: const BorderSide(color: borderDarkStrong),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: billiardGreenNeon,
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
        backgroundColor: cardDarkHigh,
        selectedColor: billiardGreenNeon.withValues(alpha: 0.16),
        side: const BorderSide(color: borderDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: ink),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF101B31),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: const Color(0xFFF4F7FD),
          fontWeight: FontWeight.w800,
          fontSize: 19,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF101B31),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        showDragHandle: true,
        dragHandleColor: borderDarkStrong,
        modalBarrierColor: Color(0x8A050A14),
      ),
      dividerTheme: const DividerThemeData(color: borderDark, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1B2947),
        contentTextStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600),
        actionTextColor: billiardGreenNeon,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Navigasi mobile (bottom bar)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 70,
        indicatorColor: billiardGreenNeon.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? billiardGreenNeon
                : const Color(0xFF93A5C4),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? billiardGreenNeon
                : const Color(0xFF93A5C4),
          ),
        ),
      ),
      // Navigasi tablet (rail)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: panel,
        indicatorColor: billiardGreenNeon.withValues(alpha: 0.18),
        selectedIconTheme: const IconThemeData(color: billiardGreenNeon),
        selectedLabelTextStyle:
            const TextStyle(color: billiardGreenNeon, fontWeight: FontWeight.w800, fontSize: 11),
        unselectedIconTheme: const IconThemeData(color: Color(0xFF93A5C4)),
        unselectedLabelTextStyle:
            const TextStyle(color: Color(0xFF93A5C4), fontWeight: FontWeight.w600, fontSize: 11),
        labelType: NavigationRailLabelType.all,
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: billiardGreenNeon,
        foregroundColor: const Color(0xFF06281D),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? billiardGreenNeon : const Color(0xFFB9C6DE),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? billiardGreenNeon.withValues(alpha: 0.15)
                : Colors.transparent,
          ),
          side: const WidgetStatePropertyAll(BorderSide(color: borderDarkStrong)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? const Color(0xFF06281D) : const Color(0xFF93A5C4),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? billiardGreenNeon
              : const Color(0xFF24365C),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardDarkHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: ink),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF1C2B4A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderDarkStrong),
        ),
        textStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600, fontSize: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: billiardGreenNeon),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0E1B33),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: borderDarkStrong),
          ),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      datePickerTheme: DatePickerThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: billiardGreenNeon,
        unselectedLabelColor: Color(0xFF93A5C4),
        indicatorColor: billiardGreenNeon,
        dividerColor: borderDark,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: const WidgetStatePropertyAll(borderDarkStrong),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(6),
      ),
    );
  }

  /// Tema terang (cadangan; aplikasi utama berjalan dark premium).
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
          color: inkOnLight,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: inkOnLight,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: inkOnLight,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: inkOnLight),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 16, color: inkOnLight),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: inkOnLight),
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
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: const Color(0xFFCBD5E1).withValues(alpha: 0.45), width: 1),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: inkOnLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: inkOnLight,
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
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: billiardGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: tableUsed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: tableUsed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
          foregroundColor: inkOnLight,
          overlayColor: Colors.grey,
          side: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: billiardGreenDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: billiardGreen.withValues(alpha: 0.15),
        side: BorderSide(color: Colors.grey.shade200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: inkOnLight),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: inkOnLight,
          fontWeight: FontWeight.w800,
          fontSize: 19,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        showDragHandle: true,
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inkOnLight,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
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
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: inkOnLight,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: billiardGreen),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Colors.grey.shade400),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(6),
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
            ? backgroundColor.withValues(alpha: 0.28)
            : backgroundColor,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? const Color(0xFF5B6E93)
            : foregroundColor,
      ),
      overlayColor: WidgetStatePropertyAll(overlayColor.withValues(alpha: 0.14)),
      side: side == null ? null : WidgetStatePropertyAll(side),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
    );
  }
}
