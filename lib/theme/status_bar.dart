import "package:flutter/material.dart";
import "package:flutter/services.dart";

// The app runs edge to edge (see main.dart). Every page sits below the status
// bar, which shows the theme's surface color: [StatusBarInset], applied to
// each pushed page by [statusBarInsetPageTransitions]. The home route is the
// exception so the shell's signed-in Profile tab can draw its cover behind the
// status bar; the shell gives its other tabs the inset itself.

/// The usual status bar: icons that contrast with the theme's surface.
SystemUiOverlayStyle themeStatusBarStyle(Brightness brightness) {
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    // Android.
    statusBarIconBrightness: brightness == Brightness.light ? Brightness.dark : Brightness.light,
    // iOS names the background, not the icons. Set it explicitly: iOS ignores
    // a null, so light icons from the Profile cover would otherwise stay.
    statusBarBrightness: brightness,
  );
}

/// Light status-bar icons, for content behind the status bar that is dark
/// (the Profile cover and its top scrim).
const SystemUiOverlayStyle lightStatusBarStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

/// Keeps [child] below the status bar, which shows the theme's surface color
/// and [themeStatusBarStyle]. This is what the app-wide SafeArea in
/// main.dart's builder used to do for every page.
class StatusBarInset extends StatelessWidget {
  const StatusBarInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The region also wins over a light-icon page underneath while this page
    // animates in on top of it.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: themeStatusBarStyle(theme.brightness),
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: SafeArea(bottom: false, child: child),
      ),
    );
  }
}

/// The platform's default page transitions, with every page except the home
/// route wrapped in [StatusBarInset].
final PageTransitionsTheme statusBarInsetPageTransitions = PageTransitionsTheme(
  builders: {
    for (final platform in TargetPlatform.values)
      platform: _StatusBarInsetTransitionsBuilder(
        const PageTransitionsTheme().builders[platform] ??
            // The framework's own fallback for a platform without a default
            // (only Fuchsia; iOS and Android both have one).
            const ZoomPageTransitionsBuilder(),
      ),
  },
);

/// Delegates everything (animation, timing, the transition handed to the
/// page below) to [inner], and only adds the inset to the page.
class _StatusBarInsetTransitionsBuilder extends PageTransitionsBuilder {
  const _StatusBarInsetTransitionsBuilder(this.inner);

  final PageTransitionsBuilder inner;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => inner.delegatedTransition;

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Inside the transition, so the status-bar strip comes and goes with
    // its page instead of popping in over a full-bleed page below.
    final page = route.settings.name == Navigator.defaultRouteName
        ? child
        : StatusBarInset(child: child);
    return inner.buildTransitions(route, context, animation, secondaryAnimation, page);
  }
}
