import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../localization/app_localizations.dart';

/// Full-screen image cropper with pan and pinch-zoom support.
///
/// Push via [ImageCropScreen.show] after the user picks an image.
/// Returns a [File] with the cropped result, or null if cancelled.
class ImageCropScreen extends StatefulWidget {
  const ImageCropScreen({
    super.key,
    required this.imageFile,
    this.aspectRatio = 1.0,
  });

  final File imageFile;

  /// Desired crop aspect ratio (width / height).
  /// - `1.0` — square (avatars)
  /// - `4 / 3` — landscape (recipe images)
  /// - `null` — free / unconstrained
  final double? aspectRatio;

  static Future<File?> show(
    BuildContext context,
    File imageFile, {
    double? aspectRatio = 1.0,
  }) =>
      Navigator.of(context).push<File?>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ImageCropScreen(
            imageFile: imageFile,
            aspectRatio: aspectRatio,
          ),
        ),
      );

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  ui.Image? _uiImage;
  img.Image? _rawImage;
  Size _imageSize = Size.zero;

  // Current display transform
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  // Saved at gesture start for stable pan+zoom
  double _startScale = 1.0;
  Offset _startOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;

  bool _loading = true;
  bool _saving = false;
  bool _transformInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();

    // Decode with dart:ui for GPU-accelerated display
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;

    // Decode with image package for pixel-level crop
    final rawImage = img.decodeImage(bytes);

    if (!mounted) return;
    setState(() {
      _uiImage = uiImage;
      _rawImage = rawImage;
      _imageSize = Size(uiImage.width.toDouble(), uiImage.height.toDouble());
      _loading = false;
    });
  }

  Rect _computeCropRect(Size screenSize) {
    const topPadding = 80.0;
    const bottomPadding = 80.0;
    const sidePadding = 24.0;

    final availableW = screenSize.width - sidePadding * 2;
    final availableH = screenSize.height - topPadding - bottomPadding;

    double cropW, cropH;

    if (widget.aspectRatio == null) {
      cropW = availableW;
      cropH = availableH;
    } else {
      final ratio = widget.aspectRatio!;
      if (ratio > availableW / availableH) {
        cropW = availableW;
        cropH = cropW / ratio;
      } else {
        cropH = availableH;
        cropW = cropH * ratio;
      }
    }

    final left = (screenSize.width - cropW) / 2;
    final top = topPadding + (availableH - cropH) / 2;
    return Rect.fromLTWH(left, top, cropW, cropH);
  }

  double _minScale(Rect cropRect) {
    if (_imageSize == Size.zero) return 1.0;
    return max(
      cropRect.width / _imageSize.width,
      cropRect.height / _imageSize.height,
    );
  }

  void _initTransform(Rect cropRect) {
    final minS = _minScale(cropRect);
    _scale = minS;
    _offset = Offset(
      cropRect.center.dx - _imageSize.width * _scale / 2,
      cropRect.center.dy - _imageSize.height * _scale / 2,
    );
    _transformInitialized = true;
  }

  void _clampOffset(Rect cropRect) {
    final imageW = _imageSize.width * _scale;
    final imageH = _imageSize.height * _scale;
    _offset = Offset(
      _offset.dx.clamp(cropRect.right - imageW, cropRect.left),
      _offset.dy.clamp(cropRect.bottom - imageH, cropRect.top),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
    _startOffset = _offset;
    _startFocalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Rect cropRect) {
    final newScale =
        (_startScale * details.scale).clamp(_minScale(cropRect), 10.0);

    // Scale around the start focal point, then translate by focal delta
    final focalInImage = (_startFocalPoint - _startOffset) / _startScale;
    var newOffset = details.focalPoint - focalInImage * newScale;

    setState(() {
      _scale = newScale;
      _offset = newOffset;
      _clampOffset(cropRect);
    });
  }

  Future<void> _applyCrop(Rect cropRect) async {
    if (_rawImage == null) return;
    setState(() => _saving = true);

    try {
      final srcX = (cropRect.left - _offset.dx) / _scale;
      final srcY = (cropRect.top - _offset.dy) / _scale;
      final srcW = cropRect.width / _scale;
      final srcH = cropRect.height / _scale;

      final cropped = img.copyCrop(
        _rawImage!,
        x: srcX.round().clamp(0, _rawImage!.width - 1),
        y: srcY.round().clamp(0, _rawImage!.height - 1),
        width: srcW.round().clamp(1, _rawImage!.width),
        height: srcH.round().clamp(1, _rawImage!.height),
      );

      final encoded = img.encodeJpg(cropped, quality: 92);
      final tempDir = Directory.systemTemp;
      final path =
          '${tempDir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(path).writeAsBytes(encoded);

      if (mounted) Navigator.of(context).pop(File(path));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final cropRect = _computeCropRect(screenSize);

    // Initialize transform on first layout after image loads
    if (!_loading && !_transformInitialized) {
      _initTransform(cropRect);
    }

    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image layer with gesture handling
          if (!_loading)
            GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: (d) => _onScaleUpdate(d, cropRect),
              child: SizedBox.expand(
                child: CustomPaint(
                  painter: _ImagePainter(
                    image: _uiImage!,
                    offset: _offset,
                    scale: _scale,
                  ),
                ),
              ),
            ),

          // Crop overlay (non-interactive)
          if (!_loading)
            IgnorePointer(
              child: CustomPaint(
                painter: _OverlayPainter(cropRect: cropRect),
                size: screenSize,
              ),
            ),

          // Loading spinner
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Header and footer UI
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: Text(
                          localizations?.cancel ?? 'Cancel',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed:
                            (_saving || _loading) ? null : () => _applyCrop(cropRect),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                localizations?.apply ?? 'Apply',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    localizations?.moveAndResize ?? 'Move and resize',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePainter extends CustomPainter {
  const _ImagePainter({
    required this.image,
    required this.offset,
    required this.scale,
  });

  final ui.Image image;
  final Offset offset;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        offset.dx,
        offset.dy,
        image.width * scale,
        image.height * scale,
      ),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(_ImagePainter old) =>
      old.image != image || old.offset != offset || old.scale != scale;
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({required this.cropRect});

  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);

    // Four dimmed regions surrounding the crop rect
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, cropRect.top), dimPaint);
    canvas.drawRect(
        Rect.fromLTRB(0, cropRect.bottom, size.width, size.height), dimPaint);
    canvas.drawRect(
        Rect.fromLTRB(0, cropRect.top, cropRect.left, cropRect.bottom),
        dimPaint);
    canvas.drawRect(
        Rect.fromLTRB(
            cropRect.right, cropRect.top, size.width, cropRect.bottom),
        dimPaint);

    // Crop border
    canvas.drawRect(
      cropRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Rule-of-thirds grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 0.7;
    for (var i = 1; i <= 2; i++) {
      final x = cropRect.left + cropRect.width * i / 3;
      final y = cropRect.top + cropRect.height * i / 3;
      canvas.drawLine(Offset(x, cropRect.top), Offset(x, cropRect.bottom),
          gridPaint);
      canvas.drawLine(
          Offset(cropRect.left, y), Offset(cropRect.right, y), gridPaint);
    }

    // Corner handles
    final handlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const h = 20.0;

    void drawHandle(Offset corner, Offset dx, Offset dy) {
      canvas.drawLine(corner, corner + dx, handlePaint);
      canvas.drawLine(corner, corner + dy, handlePaint);
    }

    drawHandle(cropRect.topLeft, const Offset(h, 0), const Offset(0, h));
    drawHandle(cropRect.topRight, const Offset(-h, 0), const Offset(0, h));
    drawHandle(cropRect.bottomLeft, const Offset(h, 0), const Offset(0, -h));
    drawHandle(cropRect.bottomRight, const Offset(-h, 0), const Offset(0, -h));
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.cropRect != cropRect;
}
