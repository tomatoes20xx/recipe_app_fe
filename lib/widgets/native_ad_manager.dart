import "package:flutter/material.dart";
import "package:google_mobile_ads/google_mobile_ads.dart";
import "banner_ad_widget.dart";

/// Manages native ad instances to prevent unnecessary reloads
/// when switching between card and fullscreen views
class NativeAdManager {
  static final NativeAdManager _instance = NativeAdManager._internal();
  factory NativeAdManager() => _instance;
  NativeAdManager._internal();

  // Cache for card view ads (keyed by ad index position)
  final Map<int, _CachedAd> _cardAds = {};
  
  // Cache for fullscreen view ads (keyed by ad index position)
  final Map<int, _CachedAd> _fullscreenAds = {};

  /// Get or create a cached ad for card view
  /// Returns the ad and a notifier for its loaded state
  /// Ads are cached for 5 minutes to allow instant view switching while still refreshing regularly
  ({NativeAd? ad, ValueNotifier<bool> loadedNotifier}) getCardAd(
    int adIndex,
    BuildContext context,
    String? adUnitId, {
    Duration cacheDuration = const Duration(minutes: 5),
  }) {
    final existingCached = _cardAds[adIndex];
    
    // Return existing ad if it exists and hasn't expired
    if (existingCached != null && !existingCached.shouldRefresh(cacheDuration: cacheDuration)) {
      return (ad: existingCached.ad, loadedNotifier: existingCached.loadedNotifier);
    }
    
    // Dispose old ad if it exists but expired
    if (existingCached != null) {
      existingCached.ad.dispose();
      existingCached.loadedNotifier.dispose();
      _cardAds.remove(adIndex);
    }
    
    // Create new ad if none exists or previous one was disposed
    final theme = Theme.of(context);
    final finalAdUnitId = adUnitId ?? AdHelper.testNativeAdUnitId;
    
    final ad = NativeAd(
      adUnitId: finalAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          final cached = _cardAds[adIndex];
          if (cached != null) {
            cached.isLoaded = true;
            cached.loadedNotifier.value = true;
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _cardAds.remove(adIndex);
          debugPrint("Native ad failed to load: $error");
        },
        onAdClicked: (_) {
          debugPrint("Native ad clicked");
        },
        onAdImpression: (_) {
          debugPrint("Native ad impression");
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: theme.colorScheme.surface,
        cornerRadius: 16,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          style: NativeTemplateFontStyle.bold,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.colorScheme.onSurface,
          style: NativeTemplateFontStyle.bold,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
    
    ad.load();
    final newCached = _CachedAd(ad: ad, isLoaded: false, createdAt: DateTime.now());
    _cardAds[adIndex] = newCached;
    return (ad: ad, loadedNotifier: newCached.loadedNotifier);
  }

  /// Get or create a cached ad for fullscreen view
  /// Returns the ad and a notifier for its loaded state
  /// Ads are cached for 5 minutes to allow instant view switching while still refreshing regularly
  ({NativeAd? ad, ValueNotifier<bool> loadedNotifier}) getFullscreenAd(
    int adIndex,
    BuildContext context,
    String? adUnitId, {
    Duration cacheDuration = const Duration(minutes: 5),
  }) {
    final existingCached = _fullscreenAds[adIndex];
    
    // Return existing ad if it exists and hasn't expired
    if (existingCached != null && !existingCached.shouldRefresh(cacheDuration: cacheDuration)) {
      return (ad: existingCached.ad, loadedNotifier: existingCached.loadedNotifier);
    }
    
    // Dispose old ad if it exists but expired
    if (existingCached != null) {
      existingCached.ad.dispose();
      existingCached.loadedNotifier.dispose();
      _fullscreenAds.remove(adIndex);
    }
    
    // Create new ad if none exists or previous one was disposed
    final finalAdUnitId = adUnitId ?? AdHelper.testNativeAdUnitId;
    
    final ad = NativeAd(
      adUnitId: finalAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          final cached = _fullscreenAds[adIndex];
          if (cached != null) {
            cached.isLoaded = true;
            cached.loadedNotifier.value = true;
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _fullscreenAds.remove(adIndex);
          debugPrint("Native ad failed to load: $error");
        },
        onAdClicked: (_) {
          debugPrint("Native ad clicked");
        },
        onAdImpression: (_) {
          debugPrint("Native ad impression");
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.transparent,
        cornerRadius: 16,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          style: NativeTemplateFontStyle.bold,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          style: NativeTemplateFontStyle.bold,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white.withValues(alpha: 0.9),
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white.withValues(alpha: 0.8),
        ),
      ),
    );
    
    ad.load();
    final newCached = _CachedAd(ad: ad, isLoaded: false, createdAt: DateTime.now());
    _fullscreenAds[adIndex] = newCached;
    return (ad: ad, loadedNotifier: newCached.loadedNotifier);
  }
  
  /// Force refresh all ads (call when feed refreshes or user pulls to refresh)
  void refreshAllAds() {
    disposeAll();
  }
  
  /// Force refresh ads for a specific index
  void refreshAd(int adIndex) {
    disposeAd(adIndex);
  }

  /// Dispose all cached ads (call when app closes or feed resets)
  void disposeAll() {
    for (final cached in _cardAds.values) {
      cached.ad.dispose();
      cached.loadedNotifier.dispose();
    }
    for (final cached in _fullscreenAds.values) {
      cached.ad.dispose();
      cached.loadedNotifier.dispose();
    }
    _cardAds.clear();
    _fullscreenAds.clear();
  }

  /// Dispose ads for a specific index (when item is removed from feed)
  void disposeAd(int adIndex) {
    final cardCached = _cardAds[adIndex];
    if (cardCached != null) {
      cardCached.ad.dispose();
      cardCached.loadedNotifier.dispose();
      _cardAds.remove(adIndex);
    }
    final fullscreenCached = _fullscreenAds[adIndex];
    if (fullscreenCached != null) {
      fullscreenCached.ad.dispose();
      fullscreenCached.loadedNotifier.dispose();
      _fullscreenAds.remove(adIndex);
    }
  }
}

class _CachedAd {
  final NativeAd ad;
  bool isLoaded;
  final ValueNotifier<bool> loadedNotifier;
  final DateTime createdAt;
  
  _CachedAd({
    required this.ad,
    required this.isLoaded,
    DateTime? createdAt,
  }) : loadedNotifier = ValueNotifier<bool>(isLoaded),
       createdAt = createdAt ?? DateTime.now();
  
  /// Check if this cached ad should be refreshed (older than cache duration)
  bool shouldRefresh({Duration cacheDuration = const Duration(minutes: 5)}) {
    return DateTime.now().difference(createdAt) > cacheDuration;
  }
}
