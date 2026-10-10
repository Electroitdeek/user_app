import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 📐 Screen Dimensions
class ScreenDimensions {
  ScreenDimensions._();

  // Full dimensions
  static double get width => 1.sw;

  static double get height => 1.sh;

  // Safe area dimensions
  static double get safeWidth => 1.sw - ScreenUtil().statusBarHeight - ScreenUtil().bottomBarHeight;

  static double get safeHeight => 1.sh - ScreenUtil().statusBarHeight - ScreenUtil().bottomBarHeight;

  // Minimum height for scrollable screens (most common use case)
  static double get minHeight => 1.sh - ScreenUtil().statusBarHeight - ScreenUtil().bottomBarHeight;

  // Fractional dimensions
  static double get halfWidth => 0.5.sw;

  static double get halfHeight => 0.5.sh;

  static double get quarterWidth => 0.25.sw;

  static double get quarterHeight => 0.25.sh;

  static double get thirdWidth => 0.33.sw;

  static double get thirdHeight => 0.33.sh;

  // Status & Navigation bar heights
  static double get statusBarHeight => ScreenUtil().statusBarHeight;

  static double get bottomBarHeight => ScreenUtil().bottomBarHeight;

  static double get navigationBarHeight => ScreenUtil().bottomBarHeight;

  // Device type checks
  static bool get isMobile => width < 650;

  static bool get isTablet => width >= 650 && width < 1100;

  static bool get isDesktop => width >= 1100;
}

/// 📦 Common size tokens + dynamic responsive helpers
class AppSize {
  AppSize._();

  // Base size tokens
  static double get xxs => 2.w;

  static double get xs => 4.w;

  static double get s => 8.w;

  static double get sm => 12.w;

  static double get m => 16.w;

  static double get l => 24.w;

  static double get xl => 32.w;

  static double get xxl => 48.w;

  static double get xxxl => 64.w;

  // Common component sizes
  static double get buttonSmall => 40.h;

  static double get buttonMedium => 48.h;

  static double get buttonLarge => 56.h;

  static double get inputHeight => 52.h;

  static double get iconSmall => 16.sp;

  static double get iconMedium => 24.sp;

  static double get iconLarge => 32.sp;

  static double get avatarSmall => 32.r;

  static double get avatarMedium => 44.r;

  static double get avatarLarge => 56.r;

  static double get cardRadius => 16.r;

  static double get sheetRadius => 20.r;

  // Dynamic size helpers using ScreenUtil scaling
  static double width(double value) => value.w;

  static double height(double value) => value.h;

  static double radius(double value) => value.r;

  static double font(double value) => value.sp;

  // Dynamic size helpers using screen percentages
  static double screenWidth(double percent) => ScreenDimensions.width * percent;

  static double screenHeight(double percent) => ScreenDimensions.height * percent;

  static double safeScreenWidth(double percent) => ScreenDimensions.safeWidth * percent;

  static double safeScreenHeight(double percent) => ScreenDimensions.safeHeight * percent;

  // Responsive value selection for mobile / tablet / desktop
  static double responsive({required double mobile, double? tablet, double? desktop}) {
    if (ScreenDimensions.isDesktop && desktop != null) return desktop;
    if (ScreenDimensions.isTablet && tablet != null) return tablet;
    return mobile;
  }

  // Handy aliases for layouts that need quick width / height constraints
  static double get fullWidth => ScreenDimensions.width;

  static double get fullHeight => ScreenDimensions.height;

  static double get halfWidth => ScreenDimensions.halfWidth;

  static double get halfHeight => ScreenDimensions.halfHeight;

  static double maxContentWidth({double mobile = 1, double tablet = 0.82, double desktop = 0.6}) {
    return responsive(
      mobile: ScreenDimensions.width * mobile,
      tablet: ScreenDimensions.width * tablet,
      desktop: ScreenDimensions.width * desktop,
    );
  }
}

/// 📏 Common Spacing Values
class AppSpacing {
  AppSpacing._();

  // Horizontal spacing
  static SizedBox get xsHorizontal => SizedBox(width: 4.w);

  static SizedBox get sHorizontal => SizedBox(width: 8.w);

  static SizedBox get mHorizontal => SizedBox(width: 12.w);

  static SizedBox get lHorizontal => SizedBox(width: 16.w);

  static SizedBox get xlHorizontal => SizedBox(width: 24.w);

  static SizedBox get xxlHorizontal => SizedBox(width: 32.w);

  static SizedBox get xxxlHorizontal => SizedBox(width: 48.w);

  // Vertical spacing
  static SizedBox get xsVertical => SizedBox(height: 4.h);

  static SizedBox get sVertical => SizedBox(height: 8.h);

  static SizedBox get mVertical => SizedBox(height: 12.h);

  static SizedBox get lVertical => SizedBox(height: 16.h);

  static SizedBox get xlVertical => SizedBox(height: 24.h);

  static SizedBox get xxlVertical => SizedBox(height: 32.h);

  static SizedBox get xxxlVertical => SizedBox(height: 48.h);

  // Custom spacing
  static SizedBox width(double value) => SizedBox(width: value.w);

  static SizedBox height(double value) => SizedBox(height: value.h);

  // Raw values (for use in calculations)
  static double get xsValue => 4.w;

  static double get sValue => 8.w;

  static double get mValue => 16.w;

  static double get lValue => 24.w;

  static double get xlValue => 32.w;

  static double get xxlValue => 48.w;
}

/// 🎨 Common Border Radius Values
class AppRadius {
  AppRadius._(); // no instance

  static BorderRadius get xs => BorderRadius.circular(4.r);

  static BorderRadius get s => BorderRadius.circular(8.r);

  static BorderRadius get m => BorderRadius.circular(12.r);

  static BorderRadius get l => BorderRadius.circular(16.r);

  static BorderRadius get xl => BorderRadius.circular(20.r);

  static BorderRadius get xxl => BorderRadius.circular(24.r);

  // Custom radius
  static BorderRadius circular(double value) => BorderRadius.circular(value.r);

  // Specific corners
  static BorderRadius topOnly(double value) =>
      BorderRadius.only(topLeft: Radius.circular(value.r), topRight: Radius.circular(value.r));

  static BorderRadius bottomOnly(double value) =>
      BorderRadius.only(bottomLeft: Radius.circular(value.r), bottomRight: Radius.circular(value.r));
}

/// 📱 Responsive Helpers Extension on BuildContext
extension ResponsiveContext on BuildContext {
  // Quick access to screen dimensions
  double get screenWidth => ScreenDimensions.width;

  double get screenHeight => ScreenDimensions.height;

  double get safeHeight => ScreenDimensions.safeHeight;

  double get minHeight => ScreenDimensions.minHeight;

  // Device type
  bool get isMobile => ScreenDimensions.isMobile;

  bool get isTablet => ScreenDimensions.isTablet;

  bool get isDesktop => ScreenDimensions.isDesktop;

  // Orientation
  bool get isPortrait => MediaQuery.of(this).orientation == Orientation.portrait;

  bool get isLandscape => MediaQuery.of(this).orientation == Orientation.landscape;

  // Responsive value based on device type
  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }
}

/// 🎯 Common Icon Sizes
class AppIconSize {
  AppIconSize._();

  static double get xss => 14.sp;

  static double get xs => 16.sp;

  static double get s => 20.sp;

  static double get m => 24.sp;

  static double get l => 32.sp;

  static double get xl => 40.sp;

  static double get xxl => 48.sp;
}

/// 🔤 Common Font Sizes (if not using text style helpers)
class AppFontSize {
  static double get xs => 10.sp;

  static double get s => 12.sp;

  static double get m => 14.sp;

  static double get l => 16.sp;

  static double get xl => 18.sp;

  static double get xxl => 20.sp;

  static double get h1 => 32.sp;

  static double get h2 => 28.sp;

  static double get h3 => 24.sp;

  static double get h4 => 20.sp;
}

/// 🔘 Common Button Heights
class AppButtonHeight {
  AppButtonHeight._();

  static double get xs => 36.h; // Small chips/tags
  static double get s => 40.h; // Compact buttons
  static double get m => 48.h; // Standard buttons
  static double get l => 56.h; // Primary CTA buttons (most common)
  static double get xl => 64.h; // Large hero buttons

  // Minimum button size (Material Design)
  static Size get minSize => Size(88.w, 36.h);

  static Size get standardSize => Size(double.infinity, 56.h);

  static Size get compactSize => Size(double.infinity, 48.h);
}
