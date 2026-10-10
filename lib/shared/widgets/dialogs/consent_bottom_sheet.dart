import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../buttons/custom_button.dart';

class ConsentBottomSheet extends StatefulWidget {
  final String title;
  final String content;
  final VoidCallback? onAgree;

  /// When true, sheet is read-only: no scroll-to-agree gate and a single
  /// "Close" button instead of "Agree & Proceed".
  final bool viewOnly;

  const ConsentBottomSheet({
    super.key,
    required this.title,
    required this.content,
    this.onAgree,
    this.viewOnly = false,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String content,
    VoidCallback? onAgree,
    bool viewOnly = false,
  }) {
    return showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConsentBottomSheet(
        title: title,
        content: content,
        onAgree: onAgree,
        viewOnly: viewOnly,
      ),
    );
  }

  @override
  State<ConsentBottomSheet> createState() => _ConsentBottomSheetState();
}

class _ConsentBottomSheetState extends State<ConsentBottomSheet> {
  late final WebViewController _controller;
  bool _isAtBottom = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'ScrollStatus',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'bottom') {
            if (!_isAtBottom) {
              setState(() {
                _isAtBottom = true;
              });
            }
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              // Initial check for short content
              _controller.runJavaScript('''
                if (document.body.scrollHeight <= window.innerHeight) {
                  ScrollStatus.postMessage("bottom");
                }
              ''');
            }
          },
        ),
      )
      ..loadHtmlString(_getHtmlWrapper(widget.content));
  }

  String _getHtmlWrapper(String content) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            font-size: 15px;
            line-height: 1.65;
            color: #424242;
            padding: 4px 2px;
            margin: 0;
            background-color: transparent;
        }
        h1, h2, h3 {
            margin: 0 0 10px;
            color: #0B3D91;
            font-weight: 700;
            line-height: 1.3;
        }
        h1 { font-size: 19px; }
        h2 { font-size: 17px; }
        h3 { font-size: 15px; }
        p { margin: 0 0 14px; }
        ul, ol { padding-left: 20px; margin: 0 0 14px; }
        li { margin-bottom: 6px; }
        strong, b { color: #212121; }
        a { color: #1F63A2; }
    </style>
</head>
<body>
    $content
    <script>
        window.onscroll = function(ev) {
            if ((window.innerHeight + window.scrollY) >= document.body.scrollHeight - 20) {
                ScrollStatus.postMessage("bottom");
            }
        };
    </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: kGreyColor3,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 18.h),

            // ── Header: icon badge + title + close ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.10), shape: BoxShape.circle),
                  child: Icon(Icons.verified_user_rounded, color: kPrimaryColor, size: 22.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: kTextBold1(color: kTextPrimaryColor).copyWith(fontSize: 18.sp),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Please review the details below',
                        style: kTextNormal0(color: kTextSecondaryColor).copyWith(fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(color: kGreyColor3.withValues(alpha: 0.25), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 18.sp, color: kTextSecondaryColor),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Divider(height: 1, thickness: 1, color: kGreyColor3.withValues(alpha: 0.4)),
            SizedBox(height: 12.h),

            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(
                    controller: _controller,
                    gestureRecognizers: {
                      Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
                    },
                  ),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator.adaptive()),
                ],
              ),
            ),
            
            if (widget.viewOnly)
              Column(
                children: [
                  SizedBox(height: 20.h),
                  CustomButton(
                    title: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              )
            else
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: _isAtBottom
                    ? Column(
                        children: [
                          SizedBox(height: 24.h),
                          CustomButton(
                            title: 'Agree & Proceed',
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onAgree?.call();
                            },
                          ),
                        ],
                      )
                    : Column(
                      children: [
                        SizedBox(height: 12.h),
                        Text(
                          'Please scroll down to the bottom to agree',
                          style: kTextNormal(color: kTextHintColor).copyWith(fontSize: 12.sp),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
