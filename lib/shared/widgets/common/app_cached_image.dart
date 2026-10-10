import 'package:adhisaat_health_care/core/assets/app_assets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppCachedImage extends StatelessWidget {
  final String? imageUrl;
  final String urlPrefix;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final String? placeholderPath;
  final bool showProgress;
  final BorderRadiusGeometry? borderRadius;
  final bool isOval;
  final Widget? errorWidgetBuilder;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.urlPrefix = '',
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholderPath,
    this.showProgress = true,
    this.borderRadius,
    this.isOval = false,
    this.errorWidgetBuilder,
  });

  bool get _hasValidUrl => imageUrl != null && imageUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final image = _hasValidUrl
        ? CachedNetworkImage(
            // Encode so URLs with spaces (e.g. ".../Hip Surgery Rehab.png") load instead of failing.
            imageUrl: Uri.encodeFull('$urlPrefix$imageUrl'),
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: memCacheWidth,
            memCacheHeight: memCacheHeight,

            // ---------- LOADING ----------
            progressIndicatorBuilder: showProgress
                ? (_, _, progress) => _Loader(size: width, progress: progress.progress)
                : null,

            // ---------- ERROR ----------
            errorWidget: (context, url, error) => _placeholderImage(),
          )
        : _placeholderImage();

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    } else if (isOval) {
      return ClipOval(child: image);
    }

    return image;
  }

  Widget _placeholderImage() {
    if (errorWidgetBuilder != null) {
      return errorWidgetBuilder!;
    }
    return Image.asset(placeholderPath ?? AppAssets.placeholder, width: width, height: height, fit: BoxFit.cover);
  }
}

class _Loader extends StatelessWidget {
  final double? size;
  final double? progress;

  const _Loader({this.size, this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(child: CircularProgressIndicator(value: progress, strokeWidth: 2)),
    );
  }
}
