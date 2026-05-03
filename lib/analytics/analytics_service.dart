import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import '../api/api_client.dart';
import 'analytics_api.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  AnalyticsApi? _api;
  FirebaseAnalytics? _fa;
  DateTime? _sessionStart;

  /// Per-session set of recipe IDs that have already fired an impression.
  final Set<String> _impressedCards = {};

  /// Called from main() after ApiClient is created.
  void init(ApiClient apiClient) {
    _api = AnalyticsApi(apiClient);
  }

  /// Called from main() inside the Firebase init block — safe to skip if
  /// Firebase isn't configured.
  void initFirebase() {
    _fa = FirebaseAnalytics.instance;
  }

  void _track(
    String eventType, {
    String? recipeId,
    Map<String, dynamic>? metadata,
  }) {
    _api?.trackEvent(
      eventType: eventType,
      recipeId: recipeId,
      metadata: metadata,
    );
  }

  void _faLog(String name, {Map<String, Object>? params}) {
    _fa?.logEvent(name: name, parameters: params);
  }

  // ── App lifecycle ─────────────────────────────────────────────────────────
  // Firebase Analytics auto-tracks app_open and session_start natively.
  // No backend calls — these aren't in /analytics/track enum.

  void logAppOpen({required bool coldStart}) {
    _faLog('app_open', params: {'cold_start': coldStart ? 1 : 0});
    if (coldStart) {
      FacebookAppEvents().logEvent(name: 'fb_mobile_activate_app');
    }
  }

  void logSessionStart() {
    _sessionStart = DateTime.now();
    _impressedCards.clear();
    // Firebase auto-tracks session_start; no explicit call needed
  }

  void logSessionEnd() {
    final duration = _sessionStart != null
        ? DateTime.now().difference(_sessionStart!).inSeconds
        : null;
    _faLog('session_end', params: {
      if (duration != null) 'duration_seconds': duration,
    });
    _sessionStart = null;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  // Auto-tracked server-side in auth.ts — Firebase only here.

  void logSignupComplete({String method = 'email'}) {
    _fa?.logSignUp(signUpMethod: method);
    FacebookAppEvents().logCompletedRegistration(registrationMethod: method);
  }

  void logEmailVerifyComplete() {
    _faLog('email_verify_complete');
  }

  // ── Feed ──────────────────────────────────────────────────────────────────
  // These are NOT auto-tracked server-side → hit backend + Firebase.

  void logFeedView() {
    _track('feed_view');
    _faLog('feed_view');
  }

  void logFeedCardImpression(String recipeId, {int? position}) {
    if (_impressedCards.contains(recipeId)) return;
    _impressedCards.add(recipeId);
    _track('feed_card_impression', recipeId: recipeId, metadata: {
      if (position != null) 'position': position,
    });
    _faLog('feed_card_impression', params: {
      'recipe_id': recipeId,
      if (position != null) 'position': position,
    });
  }

  void logFeedCardTap(String recipeId, {int? position}) {
    _track('feed_card_tap', recipeId: recipeId, metadata: {
      if (position != null) 'position': position,
    });
    _faLog('feed_card_tap', params: {
      'recipe_id': recipeId,
      if (position != null) 'position': position,
    });
  }

  // ── Recipe ────────────────────────────────────────────────────────────────

  // Auto-tracked server-side on GET /recipes/:id → Firebase only.
  void logRecipeView(String recipeId, {String? cuisineType}) {
    _faLog('recipe_view', params: {
      'recipe_id': recipeId,
      if (cuisineType != null) 'cuisine': cuisineType,
    });
    FacebookAppEvents().logViewContent(
      id: recipeId,
      type: cuisineType ?? 'recipe',
    );
  }

  // Auto-tracked server-side when bookmark API is called → Firebase only.
  void logRecipeSave(String recipeId) {
    _faLog('recipe_save', params: {'recipe_id': recipeId});
  }

  void logRecipeUnsave(String recipeId) {
    _faLog('recipe_unsave', params: {'recipe_id': recipeId});
  }

  // Not auto-tracked → backend + Firebase.
  void logRecipeCook(String recipeId) {
    _track('recipe_cook', recipeId: recipeId);
    _faLog('recipe_cook', params: {'recipe_id': recipeId});
  }

  // ── Social ────────────────────────────────────────────────────────────────
  // Not tracked server-side → Firebase only (or add to follow route later).

  void logFollow(String targetUsername) {
    _faLog('follow', params: {'target_username': targetUsername});
  }

  void logUnfollow(String targetUsername) {
    _faLog('unfollow', params: {'target_username': targetUsername});
  }

  // ── Push notifications ────────────────────────────────────────────────────
  // Firebase only — not in /analytics/track enum.

  void logPushReceived({String? channel, String? type}) {
    _faLog('push_received', params: {
      if (channel != null) 'channel': channel,
      if (type != null) 'type': type,
    });
  }

  void logPushOpened({String? channel, String? type}) {
    _faLog('push_opened', params: {
      if (channel != null) 'channel': channel,
      if (type != null) 'type': type,
    });
  }

  // ── Onboarding ────────────────────────────────────────────────────────────
  // Not auto-tracked → backend + Firebase.

  void logOnboardingStepView(int step) {
    _track('onboarding_step_view', metadata: {'step': step});
    _faLog('tutorial_step_complete', params: {'step_number': step});
  }

  void logOnboardingComplete() {
    _track('onboarding_complete');
    _fa?.logTutorialComplete();
  }
}
