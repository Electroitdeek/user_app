import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';

class TransparentLoader extends StatelessWidget {
  final String? title;

  const TransparentLoader({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(title ?? 'Loading...', style: kTextMedium()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
