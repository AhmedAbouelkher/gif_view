import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

///
/// Created by
///
/// ─▄▀─▄▀
/// ──▀──▀
/// █▀▀▀▀▀█▄
/// █░░░░░█─█
/// ▀▄▄▄▄▄▀▀
///
/// Rafaelbarbosatec
/// on 23/09/21

//TODO: the user can choose to cache or not

class CacheConfigs {
  final String? cacheKey;
  final BaseCacheManager? cacheManager;
  final bool cache;

  const CacheConfigs({
    this.cacheKey,
    this.cache = true,
    this.cacheManager,
  });

  @override
  String toString() => 'CacheConfigs(cacheKey: $cacheKey, cache: $cache)';
}

final Map<String, List<ImageInfo>> _cache = {};

class GifView extends StatefulWidget {
  final int frameRate;
  final VoidCallback? onFinish;
  final VoidCallback? onStart;
  final ValueChanged<int>? onFrame;
  final ImageProvider image;
  final bool loop;
  final double? height;
  final double? width;
  final Widget? progress;
  final BoxFit? fit;
  final Color? color;
  final BlendMode? colorBlendMode;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final bool matchTextDirection;
  final bool invertColors;
  final FilterQuality filterQuality;
  final bool isAntiAlias;
  final CacheConfigs? _cacheConfigs;

  GifView.network(
    String url, {
    Key? key,
    this.frameRate = 15,
    this.loop = true,
    this.height,
    this.width,
    this.progress,
    this.fit,
    this.color,
    this.colorBlendMode,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.invertColors = false,
    this.filterQuality = FilterQuality.low,
    this.isAntiAlias = false,
    this.onFinish,
    this.onStart,
    this.onFrame,
    CacheConfigs? cacheConfigs,
  })  : image = NetworkImage(url),
        _cacheConfigs = cacheConfigs,
        super(key: key);

  GifView.asset(
    String asset, {
    Key? key,
    this.frameRate = 15,
    this.loop = true,
    this.height,
    this.width,
    this.progress,
    this.fit,
    this.color,
    this.colorBlendMode,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.invertColors = false,
    this.filterQuality = FilterQuality.low,
    this.isAntiAlias = false,
    this.onFinish,
    this.onStart,
    this.onFrame,
  })  : image = AssetImage(asset),
        _cacheConfigs = null,
        super(key: key);

  GifView.memory(
    Uint8List bytes, {
    Key? key,
    this.frameRate = 15,
    this.loop = true,
    this.height,
    this.width,
    this.progress,
    this.fit,
    this.color,
    this.colorBlendMode,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.invertColors = false,
    this.filterQuality = FilterQuality.low,
    this.isAntiAlias = false,
    this.onFinish,
    this.onStart,
    this.onFrame,
  })  : image = MemoryImage(bytes),
        _cacheConfigs = null,
        super(key: key);

  const GifView({
    Key? key,
    this.frameRate = 15,
    required this.image,
    this.loop = true,
    this.height,
    this.width,
    this.progress,
    this.fit,
    this.color,
    this.colorBlendMode,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.invertColors = false,
    this.filterQuality = FilterQuality.low,
    this.isAntiAlias = false,
    this.onFinish,
    this.onStart,
    this.onFrame,
  })  : _cacheConfigs = null,
        super(key: key);

  @override
  _GifViewState createState() => _GifViewState();
}

class _GifViewState extends State<GifView> with TickerProviderStateMixin {
  List<ImageInfo> frames = [];
  int currentIndex = 0;
  AnimationController? _controller;
  Tween<int> tweenFrames = Tween();
  BaseCacheManager? _cacheManager;

  @override
  void initState() {
    Future.delayed(Duration.zero, _loadImage);
    if (widget._cacheConfigs != null && widget._cacheConfigs!.cache) {
      _cacheManager = widget._cacheConfigs?.cacheManager ?? DefaultCacheManager();
    }
    super.initState();
  }

  ImageInfo get currentFrame => frames[currentIndex];

  @override
  Widget build(BuildContext context) {
    if (frames.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.progress,
      );
    }
    return RawImage(
      image: currentFrame.image,
      width: widget.width,
      height: widget.height,
      scale: currentFrame.scale,
      fit: widget.fit,
      color: widget.color,
      colorBlendMode: widget.colorBlendMode,
      alignment: widget.alignment,
      repeat: widget.repeat,
      centerSlice: widget.centerSlice,
      matchTextDirection: widget.matchTextDirection,
      invertColors: widget.invertColors,
      filterQuality: widget.filterQuality,
      isAntiAlias: widget.isAntiAlias,
    );
  }

  String _getKeyImage(ImageProvider provider) {
    return provider is NetworkImage
        ? provider.url
        : provider is AssetImage
            ? provider.assetName
            : provider is MemoryImage
                ? provider.bytes.toString()
                : "";
  }

  Future<List<ImageInfo>> fetchGif(ImageProvider provider) async {
    List<ImageInfo> frameList = [];
    dynamic data;
    String key = _getKeyImage(provider);
    if (_cache.containsKey(key)) {
      frameList = _cache[key]!;
      return frameList;
    }

    if (provider is NetworkImage) {
      data = await _downloadAndCacheNetworkImage(provider.url);
    } else if (provider is AssetImage) {
      AssetBundleImageKey key = await provider.obtainKey(const ImageConfiguration());
      data = await key.bundle.load(key.name);
    } else if (provider is FileImage) {
      data = await provider.file.readAsBytes();
    } else if (provider is MemoryImage) {
      data = provider.bytes;
    }

    Codec? codec = await PaintingBinding.instance?.instantiateImageCodec(data.buffer.asUint8List());

    if (codec != null) {
      for (int i = 0; i < codec.frameCount; i++) {
        FrameInfo frameInfo = await codec.getNextFrame();
        //scale ??
        frameList.add(ImageInfo(image: frameInfo.image));
      }
      _cache.putIfAbsent(key, () => frameList);
    }
    return frameList;
  }

  FutureOr _loadImage() async {
    frames = await fetchGif(widget.image);
    if (widget.frameRate < 1) {
      return setState(() => currentIndex = 1);
    }
    tweenFrames = IntTween(begin: 0, end: frames.length - 1);
    int milli = ((frames.length / widget.frameRate) * 1000).ceil();
    Duration duration = Duration(
      milliseconds: milli,
    );
    _controller = AnimationController(vsync: this, duration: duration);
    _controller?.addListener(_listener);
    widget.onStart?.call();
    _controller?.forward(from: 0.0);
  }

  void _listener() {
    int newFrame = tweenFrames.transform(_controller!.value);
    if (currentIndex != newFrame) {
      if (mounted) {
        setState(() {
          currentIndex = newFrame;
        });
        widget.onFrame?.call(newFrame);
      }
    }
    if (_controller?.status == AnimationStatus.completed) {
      widget.onFinish?.call();
      if (widget.loop) {
        _controller?.forward(from: 0.0);
      }
    }
  }

  Future<Uint8List?> _downloadAndCacheNetworkImage(String url) async {
    final key = widget._cacheConfigs?.cacheKey ?? url;
    final fileInfo = await _cacheManager?.getFileFromCache(url);
    final Uint8List? _data;
    if (fileInfo == null) {
      final downloadedFile = await _cacheManager?.downloadFile(url, key: key);
      _data = await downloadedFile?.file.readAsBytes();
    } else {
      _data = await fileInfo.file.readAsBytes();
    }
    return _data;
  }

  @override
  void dispose() {
    _controller?.removeListener(_listener);
    _controller?.dispose();
    _cacheManager?.dispose();
    super.dispose();
  }
}
