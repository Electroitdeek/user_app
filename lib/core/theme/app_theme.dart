import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_input_theme.dart';
import 'app_text_theme.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      primaryColor: kPrimaryColor,
      scaffoldBackgroundColor: kWhiteColor,

      textTheme: appTextTheme,

      appBarTheme: const AppBarTheme(
        backgroundColor: kWhiteColor,
        elevation: 0.5,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
      ),

      inputDecorationTheme: AppInputTheme.standard(),
    );
  }
}
