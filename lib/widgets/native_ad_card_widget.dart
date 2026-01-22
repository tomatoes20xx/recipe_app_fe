import "package:flutter/material.dart";
import "package:google_mobile_ads/google_mobile_ads.dart";
import "native_ad_manager.dart";

/// Native ad card widget that matches recipe card design
/// For regular card feed view
class NativeAdCardWidget extends StatefulWidget {
  const NativeAdCardWidget({
    super.key,
    required this.adIndex,
    this.adUnitId,
  });

  /// Ad index position in the feed (used for caching)
  final int adIndex;

  /// Ad Unit ID - defaults to production native ad unit
  final String? adUnitId;

  @override
  State<NativeAdCardWidget> createState() => _NativeAdCardWidgetState();
}

class _NativeAdCardWidgetState extends State<NativeAdCardWidget> {
  NativeAd? _nativeAd;
  ValueNotifier<bool>? _loadedNotifier;
  bool _adInitialized = false;
  bool _isLoading = false;
  final _adManager = NativeAdManager();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load ad after we have access to context/theme
    // Use a minimal delay to avoid loading during initial build phase
    if (!_adInitialized) {
      _adInitialized = true;
      setState(() {
        _isLoading = true;
      });
      // Use post-frame callback instead of delay for faster loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadAd();
        }
      });
    }
  }

  void _loadAd() {
    // Load immediately since we're already in post-frame callback
    if (!mounted) return;
    
    // Get cached ad or create new one
    final result = _adManager.getCardAd(widget.adIndex, context, widget.adUnitId);
    _nativeAd = result.ad;
    _loadedNotifier = result.loadedNotifier;
    
    // Listen to loaded state changes
    _loadedNotifier?.removeListener(_onLoadedStateChanged); // Remove old listener if any
    _loadedNotifier?.addListener(_onLoadedStateChanged);
    
    // Check initial state
    if (_loadedNotifier?.value == true && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  void _onLoadedStateChanged() {
    if (mounted) {
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _loadedNotifier?.removeListener(_onLoadedStateChanged);
    // Don't dispose the ad - let the manager handle it
    // This allows the ad to be reused when switching views
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while ad is loading
    if (_nativeAd == null || _loadedNotifier?.value != true) {
      if (_isLoading) {
        // Show a subtle loading placeholder so users know something is happening
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // Use RepaintBoundary to isolate ad rendering and prevent unnecessary repaints
    return RepaintBoundary(
      child: Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: SizedBox(
          height: 200,
          child: Stack(
            children: [
              // Native ad content (template handles the UI)
              // Constrain the ad widget to prevent infinite height
              Positioned.fill(
                child: AdWidget(ad: _nativeAd!),
              ),
              // "Ad" tag in top-right corner
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
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
      ),
      ),
    );
  }
}

/// Native ad card widget for full screen feed view
class NativeAdFullScreenWidget extends StatefulWidget {
  const NativeAdFullScreenWidget({
    super.key,
    required this.adIndex,
    this.adUnitId,
  });

  /// Ad index position in the feed (used for caching)
  final int adIndex;

  /// Ad Unit ID - defaults to production native ad unit
  final String? adUnitId;

  @override
  State<NativeAdFullScreenWidget> createState() => _NativeAdFullScreenWidgetState();
}

class _NativeAdFullScreenWidgetState extends State<NativeAdFullScreenWidget> {
  NativeAd? _nativeAd;
  ValueNotifier<bool>? _loadedNotifier;
  bool _adInitialized = false;
  bool _isLoading = false;
  final _adManager = NativeAdManager();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load ad after we have access to context/theme
    // Use a minimal delay to avoid loading during initial build phase
    if (!_adInitialized) {
      _adInitialized = true;
      setState(() {
        _isLoading = true;
      });
      // Use post-frame callback instead of delay for faster loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadAd();
        }
      });
    }
  }

  void _loadAd() {
    // Load immediately since we're already in post-frame callback
    if (!mounted) return;
    
    // Get cached ad or create new one
    final result = _adManager.getFullscreenAd(widget.adIndex, context, widget.adUnitId);
    _nativeAd = result.ad;
    _loadedNotifier = result.loadedNotifier;
    
    // Listen to loaded state changes
    _loadedNotifier?.removeListener(_onLoadedStateChanged); // Remove old listener if any
    _loadedNotifier?.addListener(_onLoadedStateChanged);
    
    // Check initial state
    if (_loadedNotifier?.value == true && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  void _onLoadedStateChanged() {
    if (mounted) {
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _loadedNotifier?.removeListener(_onLoadedStateChanged);
    // Don't dispose the ad - let the manager handle it
    // This allows the ad to be reused when switching views
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while ad is loading
    if (_nativeAd == null || _loadedNotifier?.value != true) {
      if (_isLoading) {
        // Show a subtle loading placeholder for fullscreen view
        return Container(
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
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // Use RepaintBoundary to isolate ad rendering and prevent unnecessary repaints
    return RepaintBoundary(
      child: Stack(
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
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
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
      ),
    );
  }
}
