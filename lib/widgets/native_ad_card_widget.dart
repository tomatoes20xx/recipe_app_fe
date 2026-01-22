import "package:flutter/material.dart";
import "package:google_mobile_ads/google_mobile_ads.dart";

/// Native ad card widget that matches recipe card design
/// For regular card feed view
class NativeAdCardWidget extends StatefulWidget {
  const NativeAdCardWidget({
    super.key,
    this.adUnitId,
  });

  /// Ad Unit ID - defaults to production native ad unit
  final String? adUnitId;

  @override
  State<NativeAdCardWidget> createState() => _NativeAdCardWidgetState();
}

class _NativeAdCardWidgetState extends State<NativeAdCardWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    // Use production ad unit ID or the provided one
    // IMPORTANT: You need to create a NATIVE AD UNIT in AdMob (not banner)
    // The current ID is a banner ad unit - replace with your native ad unit ID
    // To create: AdMob Console > Apps > Ad units > Create ad unit > Native
    final adUnitId = widget.adUnitId ?? "ca-app-pub-5283215754482121/4569843853";
    
    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
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
        mainBackgroundColor: Theme.of(context).colorScheme.surface,
        cornerRadius: 16,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          style: NativeTemplateFontStyle.bold,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Theme.of(context).colorScheme.onSurface,
          style: NativeTemplateFontStyle.bold,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
    );

    _nativeAd?.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Stack(
          children: [
            // Native ad content (template handles the UI)
            AdWidget(ad: _nativeAd!),
            // "Ad" tag in top-right corner
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "Ad",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Native ad card widget for full screen feed view
class NativeAdFullScreenWidget extends StatefulWidget {
  const NativeAdFullScreenWidget({
    super.key,
    this.adUnitId,
  });

  /// Ad Unit ID - defaults to production native ad unit
  final String? adUnitId;

  @override
  State<NativeAdFullScreenWidget> createState() => _NativeAdFullScreenWidgetState();
}

class _NativeAdFullScreenWidgetState extends State<NativeAdFullScreenWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    // IMPORTANT: You need to create a NATIVE AD UNIT in AdMob (not banner)
    // The current ID is a banner ad unit - replace with your native ad unit ID
    final adUnitId = widget.adUnitId ?? "ca-app-pub-5283215754482121/4569843853";
    
    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
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
          textColor: Colors.white.withOpacity(0.9),
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white.withOpacity(0.8),
        ),
      ),
    );

    _nativeAd?.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Native ad content with gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ],
            ),
          ),
          child: AdWidget(ad: _nativeAd!),
        ),
        // "Ad" tag in top-right corner
        Positioned(
          top: 16,
          right: 16,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "Ad",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
