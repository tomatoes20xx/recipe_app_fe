import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:tutorial_coach_mark/tutorial_coach_mark.dart";

import "../widgets/att_permission_sheet.dart";

import "../localization/app_localizations.dart";

/// Service for managing the app tour/walkthrough
class AppTourService {
  static const _storage = FlutterSecureStorage();

  static String _key(String userId) => 'app_tour_completed_$userId';

  /// Check if user has completed the tour
  static Future<bool> hasTourCompleted(String userId) async {
    final completed = await _storage.read(key: _key(userId));
    return completed == 'true';
  }

  /// Mark tour as completed
  static Future<void> markTourCompleted(String userId) async {
    await _storage.write(key: _key(userId), value: 'true');
  }

  /// Reset tour (for testing)
  static Future<void> resetTour(String userId) async {
    await _storage.delete(key: _key(userId));
  }

  /// Create and show the tour
  static void showTour(
    BuildContext context, {
    required String userId,
    required GlobalKey feedKey,
    required GlobalKey searchKey,
    required GlobalKey createKey,
    required GlobalKey notificationsKey,
    required GlobalKey menuKey,
    VoidCallback? onFinish,
  }) {
    final targets = <TargetFocus>[];

    // 1. Feed/Home
    final localizations = AppLocalizations.of(context);
    targets.add(
      TargetFocus(
        identify: "feed",
        keyTarget: feedKey,
        alignSkip: Alignment.topRight,
        radius: 10,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildContent(
              context,
              title: localizations?.tourWelcomeTitle ?? "Welcome to Yummy! 👋",
              description: localizations?.tourWelcomeDescription ??
                  "This is your home feed. Discover amazing recipes from the community and find your next meal inspiration!",
              isFirst: true,
            ),
          ),
        ],
      ),
    );

    // 3. Search
    targets.add(
      TargetFocus(
        identify: "search",
        keyTarget: searchKey,
        alignSkip: Alignment.topRight,
        radius: 10,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildContent(
              context,
              title: localizations?.tourSearchTitle ?? "Search Recipes 🔍",
              description: localizations?.tourSearchDescription ??
                  "Find recipes by name, ingredients, or cuisine type. You can also filter by dietary preferences!",
            ),
          ),
        ],
      ),
    );

    // 4. Create
    targets.add(
      TargetFocus(
        identify: "create",
        keyTarget: createKey,
        alignSkip: Alignment.topRight,
        radius: 10,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildContent(
              context,
              title: localizations?.tourCreateTitle ?? "Share Your Recipes ✨",
              description: localizations?.tourCreateDescription ??
                  "Tap here to create and share your own recipes with the community. Add photos, ingredients, and steps!",
            ),
          ),
        ],
      ),
    );

    // 5. Notifications
    targets.add(
      TargetFocus(
        identify: "notifications",
        keyTarget: notificationsKey,
        alignSkip: Alignment.topRight,
        radius: 10,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildContent(
              context,
              title: localizations?.tourNotificationsTitle ?? "Stay Updated 🔔",
              description: localizations?.tourNotificationsDescription ??
                  "Get notified when someone likes your recipes, follows you, or comments on your posts!",
            ),
          ),
        ],
      ),
    );

    // 6. Menu
    targets.add(
      TargetFocus(
        identify: "menu",
        keyTarget: menuKey,
        alignSkip: Alignment.topRight,
        radius: 10,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildContent(
              context,
              title: localizations?.tourMenuTitle ?? "More Features 📱",
              description: localizations?.tourMenuDescription ??
                  "Access saved recipes, notifications, settings, and more from the menu.",
              isLast: true,
            ),
          ),
        ],
      ),
    );

    final tutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.8,
      hideSkip: false,
      textSkip: localizations?.skip ?? "Skip",
      onFinish: () => _completeTour(context, userId, onFinish),
      onSkip: () {
        _completeTour(context, userId, onFinish);
        return true;
      },
    );

    // Small delay to ensure widgets are built
    Future.delayed(const Duration(milliseconds: 500), () {
      tutorial.show(context: context);
    });
  }

  static void _completeTour(BuildContext context, String userId, VoidCallback? onFinish) {
    markTourCompleted(userId);
    // Brief delay lets the tour overlay finish dismissing before the sheet appears
    Future.delayed(const Duration(milliseconds: 300), () {
      showAttPermissionSheet(context);
    });
    onFinish?.call();
  }

  static Widget _buildContent(
    BuildContext context, {
    required String title,
    required String description,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          if (isFirst) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.touch_app,
                  size: 16,
                  color: theme.colorScheme.primary.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    localizations?.tourTapToContinue ?? "Tap the highlighted area or this box to continue",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (isLast) ...[
            const SizedBox(height: 16),
            Text(
              localizations?.tourAllSet ?? "You're all set! Enjoy using Yummy! 🎉",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
