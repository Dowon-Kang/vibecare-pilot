import 'package:flutter/material.dart';

/// Design tokens.
///
/// Visual language: gallery-white monochrome. Near-black ink on a white canvas,
/// structure carried by a ladder of neutral tints and 1px hairlines instead of
/// shadows or brand chroma. Every interactive element is a stadium pill,
/// containers sit at 24px, inputs and inner tiles at 16px.
///
/// Deviations kept on purpose for an assistive-device control screen used by
/// older participants: `danger` marks BLOCKED / stop actions and `warning`
/// marks cautions. Neither is ever the only carrier of state; text and icons
/// always accompany them.
abstract final class AppColors {
  static const ink = Color(0xFF141414);
  static const inkSoft = Color(0xFF262626);
  static const muted = Color(0xFF707070);
  static const faint = Color(0xFFADADAD);
  static const canvas = Color(0xFFFFFFFF);
  static const canvasSoft = Color(0xFFF3F3F3);
  static const field = Color(0xFFF0F0F0);
  static const hairlineSoft = Color(0xFFF0F0F0);
  static const hairline = Color(0xFFE0E0E0);

  /// Reserved: one chromatic accent for a single emphasized signal per screen.
  static const accent = Color(0xFF0066FF);

  static const warning = Color(0xFF9A5A00);
  static const danger = Color(0xFFB42318);
  static const dangerSoft = Color(0xFFFBEAE8);
}

abstract final class AppRadius {
  static const sm = 16.0;
  static const md = 24.0;
  static const full = 9999.0;

  static const smBorder = BorderRadius.all(Radius.circular(sm));
  static const mdBorder = BorderRadius.all(Radius.circular(md));
  static const fullBorder = BorderRadius.all(Radius.circular(full));

  /// iOS-style squircle: 30% of the tile size.
  static BorderRadius squircle(double size) =>
      BorderRadius.circular(size * 0.30);
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.ink,
          brightness: Brightness.light,
          surface: AppColors.canvas,
        ).copyWith(
          primary: AppColors.ink,
          onPrimary: AppColors.canvas,
          secondary: AppColors.inkSoft,
          onSecondary: AppColors.canvas,
          secondaryContainer: AppColors.ink,
          onSecondaryContainer: AppColors.canvas,
          surfaceContainerLow: AppColors.canvasSoft,
          surfaceContainerHighest: AppColors.field,
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.muted,
          outline: AppColors.hairline,
          outlineVariant: AppColors.hairlineSoft,
          error: AppColors.danger,
          errorContainer: AppColors.dangerSoft,
          onErrorContainer: AppColors.danger,
        );

    const stadium = StadiumBorder();
    const pillMinimumSize = Size(48, 48);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.canvas,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.md,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 21,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.ink,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.hairline,
        labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.canvas,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
          side: BorderSide(color: AppColors.hairlineSoft),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: AppColors.hairline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.md),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        hintStyle: TextStyle(color: AppColors.faint),
        labelStyle: TextStyle(color: AppColors.muted),
        floatingLabelStyle: TextStyle(color: AppColors.ink),
        prefixIconColor: AppColors.muted,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: AppColors.ink, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.canvas,
          disabledBackgroundColor: AppColors.canvasSoft,
          disabledForegroundColor: AppColors.faint,
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          shape: stadium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.canvas,
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.hairline),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: stadium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.faint,
          minimumSize: pillMinimumSize,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: stadium,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.faint,
          minimumSize: pillMinimumSize,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(stadium),
          side: const WidgetStatePropertyAll(BorderSide.none),
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.canvasSoft,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.faint
                : states.contains(WidgetState.selected)
                ? AppColors.canvas
                : AppColors.ink,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.canvas
                : AppColors.ink,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.canvas,
        selectedColor: AppColors.ink,
        side: const BorderSide(color: AppColors.hairline),
        shape: stadium,
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.canvas,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        showCheckmark: false,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.ink,
        thumbColor: AppColors.ink,
        inactiveTrackColor: AppColors.hairline,
        valueIndicatorColor: AppColors.ink,
        showValueIndicator: ShowValueIndicator.onDrag,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ink,
        linearTrackColor: AppColors.hairline,
        circularTrackColor: AppColors.hairline,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.ink,
        textColor: AppColors.ink,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AppColors.ink,
        collapsedIconColor: AppColors.muted,
        textColor: AppColors.ink,
        collapsedTextColor: AppColors.ink,
        shape: Border(),
        collapsedShape: Border(),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 32,
          height: 1.13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        headlineSmall: TextStyle(
          fontSize: 26,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        titleSmall: TextStyle(
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          height: 1.38,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          height: 1.38,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          height: 1.43,
          letterSpacing: 0,
          color: AppColors.muted,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          height: 1.38,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          height: 1.33,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
