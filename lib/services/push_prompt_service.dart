import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../notifications/notification_api.dart';
import '../widgets/common/push_permission_prompt_sheet.dart';

class PushPromptService {
  static final PushPromptService _instance = PushPromptService._internal();
  factory PushPromptService() => _instance;
  PushPromptService._internal();

  static const _keyShown = 'push_prompt_shown';
  static const _keyLikeCount = 'push_like_count';

  /// Call after a recipe is successfully saved (not unsaved).
  Future<void> onSaveCompleted(BuildContext context, ApiClient apiClient) async {
    final shown = await _isShown();
    debugPrint('PUSH PROMPT: onSaveCompleted, alreadyShown=$shown');
    if (shown) return;
    await _show(context, apiClient);
  }

  /// Call after a recipe is successfully liked (not unliked).
  /// Shows prompt on the 3rd like.
  Future<void> onLikeCompleted(BuildContext context, ApiClient apiClient) async {
    final shown = await _isShown();
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_keyLikeCount) ?? 0) + 1;
    await prefs.setInt(_keyLikeCount, count);
    debugPrint('PUSH PROMPT: onLikeCompleted, alreadyShown=$shown, likeCount=$count');
    if (shown) return;
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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShown) == true;
  }

  Future<void> _show(BuildContext context, ApiClient apiClient) async {
    debugPrint('PUSH PROMPT: _show called, _isShowing=$_isShowing, mounted=${context.mounted}');
    if (_isShowing || !context.mounted) return;
    _isShowing = true;
    try {
      await showPushPermissionPromptSheet(context, NotificationApi(apiClient));
      // Only persist after the sheet was actually displayed.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShown, true);
    } finally {
      _isShowing = false;
    }
  }
}
