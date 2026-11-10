import "package:flutter/material.dart";

/// Where a screen deep in the stack wants the bottom-nav shell to go, e.g.
/// an empty state's "Explore recipes".
enum ShellRequest {
  /// The Home feed.
  home,

  /// The Search tab with the search box focused.
  searchFocus,

  /// The create-recipe flow (with its verified-account and ban checks).
  create,
}

/// Lets any screen ask the shell (FeedShellScreen) to switch tabs or start
/// creating a recipe. The shell listens to [requests].
class ShellNavigation {
  ShellNavigation._();

  static final ValueNotifier<ShellRequest?> requests = ValueNotifier(null);

  /// Closes every pushed page, then hands [request] to the shell.
  static void go(BuildContext context, ShellRequest request) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    // Null first, so asking for the same thing twice still notifies.
    requests.value = null;
    requests.value = request;
  }
}
