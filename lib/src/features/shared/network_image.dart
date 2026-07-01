import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

/// Bounds every image fetch so a hanging request (dead CDN, stalled connection
/// on a weak network) falls back to the error placeholder instead of spinning
/// forever - important for the low-connectivity users this app targets.
class _TimeoutHttpClient extends http.BaseClient {
  _TimeoutHttpClient(this._inner, this._timeout);

  final http.Client _inner;
  final Duration _timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(_timeout);
}

/// Dedicated image cache with a request timeout (the default CacheManager has
/// none). 20s is generous for slow networks yet bounds the infinite spinner.
final BaseCacheManager _imageCacheManager = CacheManager(
  Config(
    'outalmaImageCache',
    stalePeriod: const Duration(days: 7),
    fileService: HttpFileService(
      httpClient: _TimeoutHttpClient(
        http.Client(),
        const Duration(seconds: 20),
      ),
    ),
  ),
);

/// A robust network image widget with persistent disk + memory caching.
/// Handles loading, errors, and iOS compatibility gracefully.
/// Use this instead of raw Image.network throughout the app.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final int? memCacheWidth;
  final int? memCacheHeight;

  /// Shown while loading. Defaults to a subtle shimmer container.
  final Widget? placeholder;

  /// Shown on error. Defaults to an icon placeholder.
  final Widget? errorWidget;

  /// If set, clips the image with this border radius.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    Widget image = CachedNetworkImage(
      imageUrl: url,
      cacheManager: _imageCacheManager,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      httpHeaders: const {'Accept': '*/*'},
      placeholder: (_, __) =>
          placeholder ??
          _DefaultLoadingPlaceholder(width: width, height: height),
      errorWidget: (_, __, error) {
        debugPrint('[AppNetworkImage] load failed: $url - $error');
        return errorWidget ??
            _DefaultErrorPlaceholder(width: width, height: height);
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

class _DefaultLoadingPlaceholder extends StatelessWidget {
  const _DefaultLoadingPlaceholder({this.width, this.height});
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      // Small centered spinner so loading is visible everywhere AppNetworkImage
      // is used (service cards, hero, thumbnails). Kept at 22px so it never
      // overflows the small list thumbnails.
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.primary.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _DefaultErrorPlaceholder extends StatelessWidget {
  const _DefaultErrorPlaceholder({this.width, this.height});
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Theme.of(context).colorScheme.outline,
          size: 32,
        ),
      ),
    );
  }
}
