# AdMob Integration Guide

## Setup Complete ✅

AdMob has been successfully integrated into your Flutter app with the following configuration:

- **App ID**: `ca-app-pub-5283215754482121~9547688424`
- **Banner Ad Unit ID**: `ca-app-pub-5283215754482121/4569843853`

## Files Modified

1. ✅ `pubspec.yaml` - Added `google_mobile_ads: ^5.1.0`
2. ✅ `lib/main.dart` - Initialized MobileAds SDK
3. ✅ `android/app/src/main/AndroidManifest.xml` - Added App ID meta-data
4. ✅ `ios/Runner/Info.plist` - Added GADApplicationIdentifier
5. ✅ `lib/widgets/banner_ad_widget.dart` - Created reusable banner ad widget

## How to Use

### Basic Usage

Add a banner ad to any screen using the `BannerAdWidget`:

```dart
import "../widgets/banner_ad_widget.dart";

// In your widget's build method:
Column(
  children: [
    // Your content here
    Text("Your content"),
    
    // Add banner ad at the bottom
    const BannerAdWidget(),
  ],
)
```

### Example: Adding to Home Screen

```dart
// In lib/screens/home_screen.dart
import "../widgets/banner_ad_widget.dart";

// Add at the bottom of your ListView or Column:
ListView(
  children: [
    // ... your existing content ...
    
    // Banner ad at the bottom
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: BannerAdWidget(),
    ),
  ],
)
```

### Using Test Ads (Development)

To use test ads during development, modify `lib/widgets/banner_ad_widget.dart`:

```dart
// In AdHelper class, change:
static bool get useTestAds {
  return true; // Enable test ads
}
```

Or pass a test ad unit ID directly:

```dart
BannerAdWidget(
  adUnitId: AdHelper.testBannerAdUnitId,
)
```

### Custom Ad Sizes

You can use different ad sizes:

```dart
BannerAdWidget(
  adSize: AdSize.largeBanner, // or AdSize.mediumRectangle, etc.
)
```

## Important Notes

1. **Testing**: New ad units may take up to an hour to start showing ads. Use test ad unit IDs during development.

2. **Ad Policies**: Make sure your implementation complies with [AdMob policies](https://support.google.com/admob/answer/6128543).

3. **User Experience**: 
   - Don't place ads too close together
   - Ensure ads don't interfere with app functionality
   - Consider user experience when placing ads

4. **Revenue Optimization**:
   - Place ads where users naturally pause (between content sections)
   - Consider using native ads for better user experience
   - Monitor ad performance in AdMob dashboard

## Next Steps

1. **Test the integration**: Run the app and verify ads load correctly
2. **Add ads to screens**: Place banner ads in appropriate locations
3. **Monitor performance**: Check AdMob dashboard for ad performance metrics
4. **Consider native ads**: For better user experience, consider implementing native ads

## Troubleshooting

- **Ads not showing**: Check that the App ID is correctly configured in both Android and iOS
- **Test ads not working**: Ensure you're using the correct test ad unit IDs
- **Build errors**: Make sure you've run `flutter pub get` after adding the package
