import 'package:flutter/material.dart';

import '../../../../core/widgets/network_connection/offline_banner.dart';

class NetworkWrapper extends StatelessWidget {
  final Widget child;

  const NetworkWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const OfflineBanner(),
        Expanded(child: child),
      ],
    );
  }
}
