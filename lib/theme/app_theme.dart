import 'package:flutter/material.dart';
import 'app_colors.dart';

ThemeData buildDirectFarmTheme() {
  final scheme = const ColorScheme.light(
    primary: AppColors.main,
    secondary: AppColors.sub,
    tertiary: AppColors.green,
    error: AppColors.red,
    background: AppColors.white,
    surface: AppColors.white,
    surfaceVariant: AppColors.grayBg,
    outline: AppColors.line,
    onPrimary: Colors.white,
    onSecondary: AppColors.text1,
    onTertiary: Colors.white,
    onError: Colors.white,
    onBackground: AppColors.text1,
    onSurface: AppColors.text1,
  );

  Color resolveBtnBg(Set<MaterialState> s) =>
      s.contains(MaterialState.disabled) ? AppColors.submitDisabled : AppColors.main;
  Color resolveBtnFg(Set<MaterialState> s) =>
      s.contains(MaterialState.disabled) ? AppColors.white : Colors.white;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.white,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.text1),
      bodyMedium: TextStyle(color: AppColors.text2),
      bodySmall: TextStyle(color: AppColors.text3),
      titleMedium: TextStyle(color: AppColors.text1, fontWeight: FontWeight.w600),
      labelLarge: TextStyle(color: AppColors.text2),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.text1,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.text1),
      titleTextStyle: TextStyle(
        color: AppColors.text1,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerColor: AppColors.line,
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
    iconTheme: const IconThemeData(color: AppColors.icon),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith(resolveBtnBg),
        foregroundColor: MaterialStateProperty.resolveWith(resolveBtnFg),
        overlayColor: MaterialStatePropertyAll(AppColors.main.withOpacity(0.08)),
        padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        shape: const MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
        elevation: const MaterialStatePropertyAll(0),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.disabled) ? AppColors.btnBg : AppColors.main),
        foregroundColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.disabled) ? AppColors.textDisabled : Colors.white),
        shape: const MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
        padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        elevation: const MaterialStatePropertyAll(0),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const MaterialStatePropertyAll(AppColors.main),
        overlayColor: MaterialStatePropertyAll(AppColors.main.withOpacity(0.08)),
        padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.input,
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.main, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: const TextStyle(color: AppColors.text3),
    ),
    extensions: const <ThemeExtension<dynamic>>[
      _ReadonlyFieldColors(readonlyFill: AppColors.inputReadonly),
    ],
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.text1,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.white,
      indicatorColor: Colors.transparent,
      labelTextStyle: MaterialStateProperty.resolveWith<TextStyle>((states) {
        if (states.contains(MaterialState.selected)) {
          return const TextStyle(color: AppColors.main);
        }
        return const TextStyle(color: AppColors.text2);
      }),
      iconTheme: MaterialStateProperty.resolveWith<IconThemeData>((states) {
        if (states.contains(MaterialState.selected)) {
          return const IconThemeData(color: AppColors.main);
        }
        return const IconThemeData(color: AppColors.icon);
      }),
    ),
  );
}

/// 읽기전용 인풋 배경 처리용 커스텀 확장
class _ReadonlyFieldColors extends ThemeExtension<_ReadonlyFieldColors> {
  final Color readonlyFill;
  const _ReadonlyFieldColors({required this.readonlyFill});

  @override
  _ReadonlyFieldColors copyWith({Color? readonlyFill}) =>
      _ReadonlyFieldColors(readonlyFill: readonlyFill ?? this.readonlyFill);

  @override
  ThemeExtension<_ReadonlyFieldColors> lerp(
    covariant ThemeExtension<_ReadonlyFieldColors>? other,
    double t,
  ) {
    if (other is! _ReadonlyFieldColors) return this;
    return _ReadonlyFieldColors(
      readonlyFill: Color.lerp(readonlyFill, other.readonlyFill, t) ?? readonlyFill,
    );
  }
}
