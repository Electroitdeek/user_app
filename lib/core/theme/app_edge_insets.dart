import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppPadding {
  AppPadding._();

  // All sides padding
  static EdgeInsets get xs => EdgeInsets.all(4.w);

  static EdgeInsets get s => EdgeInsets.all(8.w);

  static EdgeInsets get m => EdgeInsets.all(12.w);

  static EdgeInsets get l => EdgeInsets.all(16.w);

  static EdgeInsets get xl => EdgeInsets.all(24.w);

  static EdgeInsets get xxl => EdgeInsets.all(32.w);

  static EdgeInsets get xxxl => EdgeInsets.all(48.w);

  // Horizontal padding
  static EdgeInsets get xsHorizontal => EdgeInsets.symmetric(horizontal: 4.w);

  static EdgeInsets get sHorizontal => EdgeInsets.symmetric(horizontal: 8.w);

  static EdgeInsets get mHorizontal => EdgeInsets.symmetric(horizontal: 16.w);

  static EdgeInsets get lHorizontal => EdgeInsets.symmetric(horizontal: 24.w);

  static EdgeInsets get xlHorizontal => EdgeInsets.symmetric(horizontal: 32.w);

  // Vertical padding
  static EdgeInsets get xsVertical => EdgeInsets.symmetric(vertical: 4.h);

  static EdgeInsets get sVertical => EdgeInsets.symmetric(vertical: 8.h);

  static EdgeInsets get mVertical => EdgeInsets.symmetric(vertical: 16.h);

  static EdgeInsets get lVertical => EdgeInsets.symmetric(vertical: 24.h);

  static EdgeInsets get xlVertical => EdgeInsets.symmetric(vertical: 32.h);

  // Custom padding
  static EdgeInsets all(double value) => EdgeInsets.all(value.w);

  static EdgeInsets symmetric({double h = 0, double v = 0}) =>
      EdgeInsets.symmetric(horizontal: h.w, vertical: v.h);

  static EdgeInsets only({double left = 0, double top = 0, double right = 0, double bottom = 0}) =>
      EdgeInsets.only(left: left.w, top: top.h, right: right.w, bottom: bottom.h);

  // Screen edge padding (standard app horizontal padding)
  static EdgeInsets get screenHorizontal => EdgeInsets.symmetric(horizontal: 20.w);

  static EdgeInsets get screenAll => EdgeInsets.all(16.w);
}

// Size helper - replaces your kSize() function
double kSize(double size) => size.w;

double kSizeWidth(double size) => size.w;

double kSizeHeight(double size) => size.h;

// Responsive EdgeInsets
EdgeInsets kPaddingAll(double value) => EdgeInsets.all(value.w);

EdgeInsets kPaddingSymmetric({double h = 0, double v = 0}) => EdgeInsets.symmetric(horizontal: h.w, vertical: v.h);

EdgeInsets kPaddingOnly({double left = 0, double top = 0, double right = 0, double bottom = 0}) =>
    EdgeInsets.only(left: left.w, top: top.h, right: right.w, bottom: bottom.h);

// Common padding values
EdgeInsets get kPaddingS => EdgeInsets.all(8.w);

EdgeInsets get kPaddingM => EdgeInsets.all(16.w);

EdgeInsets get kPaddingL => EdgeInsets.all(24.w);

EdgeInsets get kPaddingXL => EdgeInsets.all(32.w);

// Responsive SizedBox
SizedBox kSizedBox({double? height, double? width = 0.0, child}) =>
    SizedBox(height: height?.w, width: width?.w, child: child);

BorderRadius kBorderRadius(double d) => BorderRadius.circular(d.r);

// SizedBox kSizedBoxW(double width) => SizedBox(width: width.w);
// final _hBlock = SizeConfig.safeBlockHorizontal;
//
// EdgeInsets kPaddingSymmetric({double h = 0.0, double v = 0.0}) {
//   return EdgeInsets.symmetric(horizontal: _hBlock * h, vertical: _hBlock * v);
// }
//
// EdgeInsets kEdgeInsetsVertical({double v = 1.0}) {
//   return EdgeInsets.symmetric(vertical: _hBlock * v);
// }
//
// EdgeInsets kPaddingAll(double v) {
//   return EdgeInsets.all(_hBlock * v);
// }
//
// EdgeInsets kPaddingOnly({double left = 0.0, double top = 0.0, double right = 0.0, double bottom = 0.0}) {
//   return EdgeInsets.fromLTRB(_hBlock * left, _hBlock * top, _hBlock * right, _hBlock * bottom);
// }
//
// BorderRadius kBorderRadius10() => BorderRadius.circular(10);
//
// BorderRadius kBorderRadiusOnly({
//   double bottomLeft = 0.0,
//   double bottomRight = 0.0,
//   double topLeft = 0.0,
//   double topRight = 0.0,
// }) => BorderRadius.only(
//   bottomRight: Radius.circular(bottomRight),
//   bottomLeft: Radius.circular(bottomLeft),
//   topLeft: Radius.circular(topLeft),
//   topRight: Radius.circular(topRight),
// );
//
// BorderRadius kBorderRadius(double d) => BorderRadius.circular(d);
//
// double kHeight(double d) => _hBlock * d;
//
// double kSize(double d) => _hBlock * d;
//
// Widget kSizedBox({double height = 0.0, double width = 0.0, child}) {
//   return SizedBox(height: _hBlock * height, width: _hBlock * width, child: child);
// }
