import "dart:developer";
import "dart:io";

import "package:flutter/material.dart";
import "package:google_mobile_ads/google_mobile_ads.dart";

/// Reusable banner ad widget
/// Ad Unit ID: ca-app-pub-3299728362959933/3238998585
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({
    super.key,
    this.adUnitId,
    this.adSize = AdSize.banner,
  });

  /// Ad Unit ID - defaults to the production ad unit
  /// For testing, use: AdHelper.bannerAdUnitId
  final String? adUnitId;
  
  /// Ad size - defaults to standard banner
  final AdSize adSize;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final adUnitId = widget.adUnitId ?? AdHelper.nativeAdUnitId;
    
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          log('BannerAd failed to load: code=${error.code} message=${error.message}', name: 'AdMob');
          ad.dispose();
        },
        onAdOpened: (_) {
          // Banner ad opened
        },
        onAdClosed: (_) {
          // Banner ad closed
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      // Return a placeholder or empty container while ad loads
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

/// Helper class for AdMob configuration
class AdHelper {
  /// Production Banner Ad Unit ID
  /// TODO: Create a Banner ad unit in AdMob and replace this ID
  static const String bannerAdUnitId = "ca-app-pub-3299728362959933/REPLACE_WITH_BANNER_AD_UNIT_ID";

  /// Production Native Ad Unit ID (YummyAd - Native Advanced)
  static String get nativeAdUnitId => Platform.isIOS
      ? "ca-app-pub-3299728362959933/5205563553"
      : "ca-app-pub-3299728362959933/3238998585";
  
  /// Test Ad Unit IDs (for development/testing)
  /// Use these during development to avoid invalid traffic
  static const String testBannerAdUnitId = "ca-app-pub-3940256099942544/6300978111";
  static const String testNativeAdUnitId = "ca-app-pub-3940256099942544/2247696110";
  
  /// Check if we should use test ads (useful for debug builds)
  static bool get useTestAds {
    // In debug mode, you might want to use test ads
    // Uncomment the line below to always use test ads in debug
    // return true;
    return false;
  }
  
  /// Get the appropriate banner ad unit ID
  static String getBannerAdUnitId() {
    return useTestAds ? testBannerAdUnitId : bannerAdUnitId;
  }
}
