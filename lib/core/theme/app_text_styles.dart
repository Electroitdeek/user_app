import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

typedef FontBuilder = TextStyle Function({Color? color, double? fontSize, FontWeight? fontWeight});

/// Default font (change once, whole app updates)
final FontBuilder appFont = GoogleFonts.dmSans;

TextStyle appTextStyle({double? fontSize, FontWeight fontWeight = FontWeight.w400, Color? color}) {
  return appFont(fontSize: fontSize, fontWeight: fontWeight, color: color ?? kTextPrimaryColor);
}

// 🔹 Normal Text
TextStyle kTextNormal0({Color? color}) => appFont(fontSize: 12.sp, fontWeight: FontWeight.w400, color: color);

TextStyle kTextNormal({Color? color}) => appFont(fontSize: 14.sp, fontWeight: FontWeight.w400, color: color);

TextStyle kTextNormal1({Color? color}) => appFont(fontSize: 15.sp, fontWeight: FontWeight.w400, color: color);

TextStyle kTextNormal2({Color? color}) => appFont(fontSize: 16.sp, fontWeight: FontWeight.w400, color: color);

TextStyle kTextNormal3({Color? color}) => appFont(fontSize: 18.sp, fontWeight: FontWeight.w400, color: color);

// 🔹 Medium Weight
TextStyle kTextMedium0({Color? color}) => appFont(fontSize: 12.sp, fontWeight: FontWeight.w500, color: color);

TextStyle kTextMedium({Color? color}) => appFont(fontSize: 14.sp, fontWeight: FontWeight.w500, color: color);

TextStyle kTextMedium1({Color? color}) => appFont(fontSize: 15.sp, fontWeight: FontWeight.w500, color: color);

TextStyle kTextMedium2({Color? color}) => appFont(fontSize: 16.sp, fontWeight: FontWeight.w500, color: color);

TextStyle kTextMedium3({Color? color}) => appFont(fontSize: 18.sp, fontWeight: FontWeight.w500, color: color);

// 🔹 SemiBold
TextStyle kTextSemiBold0({Color? color}) => appFont(fontSize: 12.sp, fontWeight: FontWeight.w600, color: color);

TextStyle kTextSemiBold({Color? color}) => appFont(fontSize: 14.sp, fontWeight: FontWeight.w600, color: color);

TextStyle kTextSemiBold1({Color? color}) => appFont(fontSize: 15.sp, fontWeight: FontWeight.w600, color: color);

TextStyle kTextSemiBold2({Color? color}) => appFont(fontSize: 16.sp, fontWeight: FontWeight.w600, color: color);

TextStyle kTextSemiBold3({Color? color}) => appFont(fontSize: 17.sp, fontWeight: FontWeight.w600, color: color);

// 🔹 Bold
TextStyle kTextBold0({Color? color}) => appFont(fontSize: 12.sp, fontWeight: FontWeight.w700, color: color);

TextStyle kTextBold({Color? color}) => appFont(fontSize: 14.sp, fontWeight: FontWeight.w700, color: color);

TextStyle kTextBold1({Color? color}) => appFont(fontSize: 16.sp, fontWeight: FontWeight.w700, color: color);

TextStyle kTextBold2({Color? color}) => appFont(fontSize: 18.sp, fontWeight: FontWeight.w700, color: color);

TextStyle kTextBold3({Color? color}) => appFont(fontSize: 20.sp, fontWeight: FontWeight.w700, color: color);

// 🔹 Headings (ExtraBold)
TextStyle kHeadingSmall({Color? color}) => appFont(fontSize: 20.sp, fontWeight: FontWeight.w800, color: color);

TextStyle kHeadingMedium({Color? color}) => appFont(fontSize: 22.sp, fontWeight: FontWeight.w800, color: color);

TextStyle kHeadingLarge({Color? color}) => appFont(fontSize: 28.sp, fontWeight: FontWeight.w800, color: color);
/*

//Normal
TextStyle kTextNormal0({Color? color}) => appTextStyle(fontSize: SizeConfig.body0FontSize, color: color);

TextStyle kTextNormal({Color? color}) => appTextStyle(fontSize: SizeConfig.bodyFontSize, color: color);

TextStyle kTextNormal1({Color? color}) => appTextStyle(fontSize: SizeConfig.body1FontSize, color: color);

TextStyle kTextNormal2({Color? color}) => appTextStyle(fontSize: SizeConfig.body2FontSize, color: color);

//Medium
TextStyle kTextMedium0({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.body0FontSize, fontWeight: FontWeight.w500, color: color);

TextStyle kTextMedium({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.bodyFontSize, fontWeight: FontWeight.w500, color: color);

TextStyle kTextMedium1({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.body1FontSize, fontWeight: FontWeight.w500, color: color);

TextStyle kTextMedium2({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.body2FontSize, fontWeight: FontWeight.w500, color: color);

//SemiBold
TextStyle kTextSemiBold({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.bodyFontSize, fontWeight: FontWeight.w600, color: color);

TextStyle kTextSemiBold1({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.body1FontSize, fontWeight: FontWeight.w600, color: color);

TextStyle kTextSemiBold2({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.body2FontSize, fontWeight: FontWeight.w600, color: color);

TextStyle kTextSemiBold3({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.body3FontSize, fontWeight: FontWeight.w600, color: color);

// Bold
TextStyle kTextBold({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.bodyFontSize, fontWeight: FontWeight.w700, color: color);

TextStyle kTextBold1({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.body1FontSize, fontWeight: FontWeight.w700, color: color);

TextStyle kTextBold2({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.body2FontSize, fontWeight: FontWeight.w700, color: color);

TextStyle kTextBold3({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.body3FontSize, fontWeight: FontWeight.w700, color: color);

//🔹 ExtraBold (Headings)
TextStyle kHeadingSmall({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.body2FontSize, fontWeight: FontWeight.w800, color: color);

TextStyle kHeadingMedium({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.body3FontSize, fontWeight: FontWeight.w800, color: color);

TextStyle kHeadingLarge({Color? color}) =>
    appTextStyle(fontSize: SizeConfig.body4FontSize, fontWeight: FontWeight.w800, color: color);
*/
