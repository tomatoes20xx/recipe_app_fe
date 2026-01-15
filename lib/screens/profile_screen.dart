import "dart:io";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:image/image.dart" as img;

import "../api/api_client.dart";
import "../auth/auth_api.dart";
import "../auth/auth_controller.dart";
import "../config.dart";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.auth, required this.apiClient});

  final AuthController auth;
  final ApiClient apiClient;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  bool _isDeleting = false;

  Future<void> _uploadAvatar() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _isUploading = true);

      // Compress the image before uploading (avatars are small, but compression helps)
      final compressedFile = await _compressImage(File(image.path));
      final fileToUpload = compressedFile ?? File(image.path);

      final authApi = AuthApi(widget.apiClient);
      await authApi.uploadAvatar(fileToUpload);
      
      // Refresh user data
      await widget.auth.bootstrap();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Avatar updated successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload avatar: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  /// Compresses and resizes an image to reduce file size
  /// Max dimensions: 512x512 (for avatars), Quality: 85%
  Future<File?> _compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      
      if (originalImage == null) return null;

      // For avatars, resize to 512x512 (square, center crop)
      const maxDimension = 512;
      
      // Calculate dimensions for square center crop
      int width = originalImage.width;
      int height = originalImage.height;
      int cropSize = width < height ? width : height;
      int offsetX = (width - cropSize) ~/ 2;
      int offsetY = (height - cropSize) ~/ 2;

      // Crop to square (center)
      final croppedImage = img.copyCrop(
        originalImage,
        x: offsetX,
        y: offsetY,
        width: cropSize,
        height: cropSize,
      );

      // Resize to 512x512
      final resizedImage = img.copyResize(
        croppedImage,
        width: maxDimension,
        height: maxDimension,
        interpolation: img.Interpolation.linear,
      );

      // Convert to JPEG with 85% quality
      final jpegBytes = img.encodeJpg(resizedImage, quality: 85);
      
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

  void _showAvatarMenu(BuildContext context, String? avatarUrl) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatarUrl == null || avatarUrl.isEmpty)
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: const Text("Add Avatar"),
                onTap: () {
                  Navigator.of(context).pop();
                  _uploadAvatar();
                },
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Update Avatar"),
                onTap: () {
                  Navigator.of(context).pop();
                  _uploadAvatar();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  "Delete Avatar",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteAvatar();
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Avatar"),
        content: const Text("Are you sure you want to remove your avatar?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isDeleting = true);

      final authApi = AuthApi(widget.apiClient);
      await authApi.deleteAvatar();
      
      // Refresh user data
      await widget.auth.bootstrap();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Avatar removed successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete avatar: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  String _buildImageUrl(String relativeUrl) {
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }
    return "${Config.apiBaseUrl}$relativeUrl";
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.me;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Profile")),
        body: const Center(
          child: Text("Not logged in"),
        ),
      );
    }

    final username = user["username"]?.toString() ?? "Unknown";
    final displayName = user["displayName"]?.toString();
    final email = user["email"]?.toString() ?? "";
    final avatarUrl = user["avatar_url"]?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _isUploading || _isDeleting
                            ? null
                            : () => _showAvatarMenu(context, avatarUrl),
                        child: Stack(
                          children: [
                            avatarUrl != null && avatarUrl.isNotEmpty
                                ? CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    backgroundImage: NetworkImage(_buildImageUrl(avatarUrl)),
                                    onBackgroundImageError: (exception, stackTrace) {
                                      // Image failed to load, will show child as fallback
                                    },
                                    child: null,
                                  )
                                : CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    child: Text(
                                      username.isNotEmpty ? username[0].toUpperCase() : "?",
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                            if (_isUploading || _isDeleting)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            // Pencil icon to indicate avatar is editable
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName ?? username,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "@$username",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          email,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
