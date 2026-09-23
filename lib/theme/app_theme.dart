import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Matches the RK Classes web app's own brand exactly (SchoolMS.Web/wwwroot/css/app.css :root — --p /
/// --p2), so the app reads as the same brand as the web portal, not a mismatched color slapped on top.
class AppColors {
  static const Color primary = Color(0xFFF40B12);
  static const Color primaryDark = Color(0xFFC20009);
  static const Color primaryLight = Color(0xFFFF5A54);
  static const Color primarySoft = Color(0xFFFFF0F0);
  static const Color background = Color(0xFFF5F5FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFFBFAFC);
  static const Color textPrimary = Color(0xFF1A1035);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFF5C6C6);
  static const Color borderNeutral = Color(0xFFEDEDF2);

  static const Color success = Color(0xFF059669);
  static const Color successSoft = Color(0xFFE7F7F1);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFDF3E4);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFCEAEA);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSoft = Color(0xFFE9F0FE);
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetSoft = Color(0xFFF1EAFE);
  static const Color teal = Color(0xFF0D9488);
  static const Color tealSoft = Color(0xFFE3F6F4);
  static const Color amber = Color(0xFFD97706);

  static const Color present = Color(0xFF059669);
  static const Color absent = Color(0xFFDC2626);
  static const Color late = Color(0xFFD97706);
}

class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 26;
  static const double pill = 999;
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppGradients {
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryDark],
  );

  static const LinearGradient primarySheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryLight, AppColors.primary, AppColors.primaryDark],
    stops: [0.0, 0.55, 1.0],
  );
}

class AppShadows {
  static List<BoxShadow> card = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> soft = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
  ];

  static List<BoxShadow> floating = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> header = [
    BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 10)),
  ];

  static List<BoxShadow> navBar = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 22, offset: const Offset(0, -4)),
  ];
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      splashFactory: InkRipple.splashFactory,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderNeutral),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.background,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        shape: StadiumBorder(side: const BorderSide(color: AppColors.border)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.borderNeutral, thickness: 1),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
