import "dart:io";
import "package:image/image.dart" as img;

/// Shared image compression utilities for the app.
/// Used for avatar uploads, recipe images, etc.
class ImageUtils {
  ImageUtils._();

  // Default compression settings
  static const int defaultMaxDimension = 1440;
  static const int defaultJpegQuality = 80;
  static const int avatarMaxDimension = 512;
  static const int avatarJpegQuality = 85;
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5MB

  /// Compresses and resizes an image to reduce file size.
  ///
  /// [imageFile] - The source image file
  /// [maxDimension] - Maximum width/height (default: 1440)
  /// [quality] - JPEG quality 0-100 (default: 80)
  /// [maxFileSize] - Maximum file size in bytes (default: 5MB)
  ///
  /// Returns the compressed file, or null if compression fails.
  static Future<File?> compressImage(
    File imageFile, {
    int maxDimension = defaultMaxDimension,
    int quality = defaultJpegQuality,
    int maxFileSize = maxFileSizeBytes,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);

      if (originalImage == null) return null;

      // Calculate new dimensions (max on longest side)
      int width = originalImage.width;
      int height = originalImage.height;

      if (width > maxDimension || height > maxDimension) {
        if (width > height) {
          height = (height * maxDimension / width).round();
          width = maxDimension;
        } else {
          width = (width * maxDimension / height).round();
          height = maxDimension;
        }
      }

      // Resize the image
      final resizedImage = img.copyResize(
        originalImage,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      );

      // First pass: Convert to JPEG with standard quality
      var jpegBytes = img.encodeJpg(resizedImage, quality: quality);

      // If still too large, apply more aggressive compression
      if (jpegBytes.length > maxFileSize) {
        jpegBytes = img.encodeJpg(resizedImage, quality: 60);
      }

      // If STILL too large, reduce dimensions further
      if (jpegBytes.length > maxFileSize) {
        final smallerImage = img.copyResize(
          resizedImage,
          width: (width * 0.7).round(),
          height: (height * 0.7).round(),
          interpolation: img.Interpolation.linear,
        );
        jpegBytes = img.encodeJpg(smallerImage, quality: 70);
      }

      // Save to a temporary file
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedFile = File('${tempDir.path}/compressed_$timestamp.jpg');
      await compressedFile.writeAsBytes(jpegBytes);

      return compressedFile;
    } catch (e) {
      // If compression fails, return null to use original
      return null;
    }
  }

  /// Compresses an image for avatar use (square, center-cropped).
  ///
  /// [imageFile] - The source image file
  /// [maxDimension] - Maximum size for the square avatar (default: 512)
  /// [quality] - JPEG quality 0-100 (default: 85)
  ///
  /// Returns the compressed file, or null if compression fails.
  static Future<File?> compressAvatar(
    File imageFile, {
    int maxDimension = avatarMaxDimension,
    int quality = avatarJpegQuality,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);

      if (originalImage == null) return null;

      // Calculate dimensions for square center crop
      final width = originalImage.width;
      final height = originalImage.height;
      final cropSize = width < height ? width : height;
      final offsetX = (width - cropSize) ~/ 2;
      final offsetY = (height - cropSize) ~/ 2;

      // Crop to square (center)
      final croppedImage = img.copyCrop(
        originalImage,
        x: offsetX,
        y: offsetY,
        width: cropSize,
        height: cropSize,
      );

      // Resize to target dimension
      final resizedImage = img.copyResize(
        croppedImage,
        width: maxDimension,
        height: maxDimension,
        interpolation: img.Interpolation.linear,
      );

      // Convert to JPEG
      final jpegBytes = img.encodeJpg(resizedImage, quality: quality);

      // Save to a temporary file
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedFile = File('${tempDir.path}/compressed_avatar_$timestamp.jpg');
      await compressedFile.writeAsBytes(jpegBytes);

      return compressedFile;
    } catch (e) {
      // If compression fails, return null to use original
      return null;
    }
  }
}
