import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../notifications/notification_api.dart';
import '../widgets/common/push_permission_prompt_sheet.dart';

class PushPromptService {
  static final PushPromptService _instance = PushPromptService._internal();
  factory PushPromptService() => _instance;
  PushPromptService._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyShown = 'push_prompt_shown';
  static const _keyLikeCount = 'push_like_count';

  /// Call after a recipe is successfully saved (not unsaved).
  Future<void> onSaveCompleted(BuildContext context, ApiClient apiClient) async {
    if (await _isShown()) return;
    await _show(context, apiClient);
  }

  /// Call after a recipe is successfully liked (not unliked).
  /// Shows prompt on the 3rd like.
  Future<void> onLikeCompleted(BuildContext context, ApiClient apiClient) async {
    if (await _isShown()) return;
    final countStr = await _storage.read(key: _keyLikeCount) ?? '0';
    final count = (int.tryParse(countStr) ?? 0) + 1;
    await _storage.write(key: _keyLikeCount, value: '$count');
    if (count >= 3) {
      await _show(context, apiClient);
    }
  }

  /// Call when the app returns to foreground. Shows prompt if user account is
  /// older than 24 hours and prompt has not been shown yet.
  Future<void> onForegrounded(
    BuildContext context,
    AuthController auth,
    ApiClient apiClient,
  ) async {
    if (await _isShown()) return;
    if (!auth.isLoggedIn) return;
    final createdAtRaw = auth.me?['createdAt'] as String?;
    if (createdAtRaw == null) return;
    final created = DateTime.tryParse(createdAtRaw);
    if (created == null) return;
    if (DateTime.now().difference(created) < const Duration(hours: 24)) return;
    await _show(context, apiClient);
  }

  // In-memory guard so concurrent triggers don't race past the storage check.
  bool _isShowing = false;

  Future<bool> _isShown() async {
    return await _storage.read(key: _keyShown) == 'true';
  }

  Future<void> _show(BuildContext context, ApiClient apiClient) async {
    if (_isShowing || !context.mounted) return;
    _isShowing = true;
    try {
      await showPushPermissionPromptSheet(context, NotificationApi(apiClient));
      // Only persist after the sheet was actually displayed.
      await _storage.write(key: _keyShown, value: 'true');
    } finally {
      _isShowing = false;
    }
  }
}
