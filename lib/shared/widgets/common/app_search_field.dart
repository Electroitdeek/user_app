import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class AppSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final FocusNode? focusNode;
  final bool autoFocus;
  final Widget? suffixIcon;

  const AppSearchField({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.focusNode,
    this.autoFocus = false,
    this.suffixIcon,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: kBorderColor.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        focusNode: widget.focusNode,
        autofocus: widget.autoFocus,
        style: kTextNormal(),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: kTextNormal(color: kTextHintColor),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: kTextHintColor.withValues(alpha: 0.8),
            size: 22.sp,
          ),
          suffixIcon: widget.suffixIcon ??
              (hasText
                  ? GestureDetector(
                      onTap: () {
                        widget.controller.clear();
                        FocusScope.of(context).unfocus();
                        if (widget.onClear != null) {
                          widget.onClear!();
                        } else if (widget.onChanged != null) {
                          widget.onChanged!('');
                        }
                      },
                      child: Icon(
                        Icons.close_rounded,
                        color: kTextHintColor,
                        size: 18.sp,
                      ),
                    )
                  : null),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 14.h),
        ),
      ),
    );
  }
}
