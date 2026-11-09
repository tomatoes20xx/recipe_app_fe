import "package:flutter/material.dart";
import "../auth/auth_api.dart";
import "../auth/auth_controller.dart";
import "../feed/feed_view_controller.dart";
import "../localization/app_localizations.dart";
import "../widgets/common/profile_avatar.dart";
import "../widgets/common/token_widgets.dart";
import "../theme/app_tokens.dart";
import "../localization/language_controller.dart";
import "../theme/theme_controller.dart";
import "package:package_info_plus/package_info_plus.dart";
import "feed_view_screen.dart";
import "theme_selection_screen.dart";
import "language_selection_screen.dart";
import "terms_and_privacy_screen.dart";
import "help_and_support_screen.dart";
import "../api/api_client.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "../utils/error_utils.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themeController,
    required this.languageController,
    this.feedViewController,
    this.auth,
    this.apiClient,
  });

  final ThemeController themeController;
  final LanguageController languageController;
  final FeedViewController? feedViewController;
  final AuthController? auth;
  final ApiClient? apiClient;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = "";
  UserPrivacySettings _privacySettings = UserPrivacySettings(
    followersPrivate: false,
    followingPrivate: false,
  );
  bool _isLoadingPrivacy = true;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    if (widget.auth?.isLoggedIn == true && widget.apiClient != null) {
      _loadPrivacySettings();
    }
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  Future<void> _loadPrivacySettings() async {
    if (widget.apiClient == null) return;

    setState(() {
      _isLoadingPrivacy = true;
    });

    try {
      final userApi = UserApi(widget.apiClient!);
      final username = widget.auth?.me?["username"]?.toString();
      if (username != null) {
        final profile = await userApi.getUserProfile(username);
        if (mounted) {
          setState(() {
            if (profile.privacy != null) {
              _privacySettings = profile.privacy!;
            }
            _isLoadingPrivacy = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPrivacy = false;
        });
      }
    }
  }

  Future<void> _updatePrivacy({
    bool? followersPrivate,
    bool? followingPrivate,
  }) async {
    if (widget.apiClient == null) return;

    setState(() {
      _isLoadingPrivacy = true;
    });

    try {
      final userApi = UserApi(widget.apiClient!);
      final updatedPrivacy = await userApi.updatePrivacy(
        followersPrivate: followersPrivate,
        followingPrivate: followingPrivate,
      );

      if (mounted) {
        setState(() {
          _privacySettings = updatedPrivacy;
          _isLoadingPrivacy = false;
        });
        final localizations = AppLocalizations.of(context);
        ErrorUtils.showSuccess(
          context,
          localizations?.privacySettingsUpdated ??
              "Privacy settings updated",
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingPrivacy = false;
      });
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final t = AppTokens.of(context);
    final isLoggedIn = widget.auth?.isLoggedIn == true;
    const gap = SizedBox(height: 24);

    return Scaffold(
      backgroundColor: t.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(localizations?.settings ?? "Settings"),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            sliver: SliverList.list(
              children: [
                if (isLoggedIn) ...[
                  _buildUserHeader(context),
                  gap,
                ],

                // Preferences
                TokenSectionLabel(localizations?.appPreferences ?? "Preferences"),
                TokenGroup(
                  children: [
                    TokenListRow(
                      icon: Icons.palette_outlined,
                      label: localizations?.themeMode ?? "Theme",
                      value: _getThemeModeLabel(context),
                      showDivider: true,
                      onTap: () => _push(ThemeSelectionScreen(themeController: widget.themeController)),
                    ),
                    TokenListRow(
                      icon: Icons.translate_rounded,
                      label: localizations?.language ?? "Language",
                      value: _getLanguageLabel(context),
                      showDivider: widget.feedViewController != null,
                      onTap: () => _push(LanguageSelectionScreen(languageController: widget.languageController)),
                    ),
                    if (widget.feedViewController != null)
                      AnimatedBuilder(
                        animation: widget.feedViewController!,
                        builder: (context, _) => TokenListRow(
                          icon: Icons.view_carousel_outlined,
                          label: localizations?.feedViewType ?? "Feed View",
                          value: widget.feedViewController!.isFullScreenView
                              ? (localizations?.fullScreenView ?? "Full Screen View")
                              : (localizations?.listView ?? "List View"),
                          onTap: () => _push(FeedViewScreen(feedViewController: widget.feedViewController!)),
                        ),
                      ),
                  ],
                ),

                // Privacy (only if logged in)
                if (isLoggedIn) ...[
                  gap,
                  TokenSectionLabel(localizations?.privacy ?? "Privacy"),
                  _buildPrivacySettings(context),
                ],

                // Support
                gap,
                TokenSectionLabel(localizations?.about ?? "Support"),
                TokenGroup(
                  children: [
                    TokenListRow(
                      icon: Icons.help_outline_rounded,
                      label: localizations?.helpAndSupport ?? "Help & Support",
                      showDivider: true,
                      onTap: () => _push(const HelpAndSupportScreen()),
                    ),
                    TokenListRow(
                      icon: Icons.shield_outlined,
                      label: localizations?.termsAndPrivacy ?? "Terms & Privacy",
                      onTap: () => _push(const TermsAndPrivacyScreen()),
                    ),
                  ],
                ),

                // Sign out + delete account (if logged in)
                if (isLoggedIn) ...[
                  gap,
                  TokenGroup(
                    children: [
                      TokenListRow(
                        icon: Icons.logout_rounded,
                        label: localizations?.signOut ?? "Sign out",
                        destructive: true,
                        onTap: () => _confirmSignOut(context, localizations),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDeleteAccountButton(context),
                ],

                const SizedBox(height: 28),
                _buildAppInfoFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  /// Avatar, name and email on a `card`, like the Profile tab's cards.
  Widget _buildUserHeader(BuildContext context) {
    final t = AppTokens.of(context);
    final me = widget.auth?.me;
    final username = me?["username"]?.toString() ?? "";
    final email = me?["email"]?.toString();
    final displayName = me?["display_name"]?.toString();
    final name = displayName?.trim().isNotEmpty == true ? displayName!.trim() : username;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          ProfileAvatar(avatarUrl: me?["avatar_url"]?.toString(), name: name, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.ink),
                ),
                if (email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: t.ink2),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySettings(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final t = AppTokens.of(context);

    Widget toggle(bool value, ValueChanged<bool> onChanged) => Switch(
          value: value,
          onChanged: _isLoadingPrivacy ? null : onChanged,
          activeTrackColor: t.fill,
        );

    return TokenGroup(
      children: [
        TokenListRow(
          icon: Icons.people_outline_rounded,
          label: localizations?.privateFollowers ?? "Private Followers",
          description: localizations?.hideYourFollowersListFromOthers ?? "Hide your followers list from others",
          showDivider: true,
          trailing: toggle(_privacySettings.followersPrivate, (v) => _updatePrivacy(followersPrivate: v)),
        ),
        TokenListRow(
          icon: Icons.person_outline_rounded,
          label: localizations?.privateFollowing ?? "Private Following",
          description: localizations?.hideYourFollowingListFromOthers ?? "Hide your following list from others",
          trailing: toggle(_privacySettings.followingPrivate, (v) => _updatePrivacy(followingPrivate: v)),
        ),
      ],
    );
  }

  /// Moved here from the removed side drawer. Signing out lands the user back
  /// on the shell's Home tab (the shell switches to it on sign-out).
  void _confirmSignOut(BuildContext context, AppLocalizations? localizations) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations?.signOutConfirmTitle ?? "Sign out?"),
        content: Text(localizations?.signOutConfirmMessage ?? "Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
              widget.auth?.logout();
            },
            child: Text(
              localizations?.signOut ?? "Sign out",
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteAccountButton(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final localizations = AppLocalizations.of(context);

    return OutlinedButton.icon(
      onPressed: () => _showDeleteAccountDialog(context),
      icon: const Icon(Icons.delete_forever_outlined, size: 20),
      label: Text(localizations?.deleteAccount ?? "Delete Account"),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        foregroundColor: error,
        side: BorderSide(color: error.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.deleteAccount ?? "Delete Account"),
        content: Text(
          localizations?.deleteAccountWarning ??
              "This will permanently delete your account and all your data. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              localizations?.cancel ?? "Cancel",
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeleteAccountConfirmDialog(context);
            },
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            child: Text(localizations?.continueButton ?? "Continue"),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final confirmController = TextEditingController();
    bool isConfirmed = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(localizations?.deleteAccountConfirmTitle ?? "Are you sure?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localizations?.deleteAccountTypeDelete ?? 'Type "DELETE" to confirm'),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "DELETE",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (value) {
                  setDialogState(() {
                    isConfirmed = value == "DELETE";
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                localizations?.cancel ?? "Cancel",
              ),
            ),
            TextButton(
              onPressed: isConfirmed
                  ? () async {
                      Navigator.of(dialogContext).pop();
                      await _deleteAccount();
                    }
                  : null,
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: Text(localizations?.deleteAccount ?? "Delete Account"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (widget.apiClient == null || widget.auth == null) return;

    try {
      final authApi = AuthApi(widget.apiClient!);
      await authApi.deleteAccount();

      if (mounted) {
        widget.auth!.logout();
        Navigator.of(context).popUntil((route) => route.isFirst);
        final localizations = AppLocalizations.of(context);
        ErrorUtils.showSuccess(
          context,
          localizations?.accountDeletedSuccessfully ?? "Account deleted successfully",
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    }
  }

  Widget _buildAppInfoFooter(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // App Icon
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            "assets/icon/app_icon.png",
            width: 56,
            height: 56,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Yummy",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _appVersion.isNotEmpty ? "Version $_appVersion" : "",
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Made with love",
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  String _getThemeModeLabel(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    switch (widget.themeController.themeMode) {
      case ThemeMode.system:
        return localizations?.system ?? "System";
      case ThemeMode.light:
        return localizations?.light ?? "Light";
      case ThemeMode.dark:
        return localizations?.dark ?? "Dark";
    }
  }

  String _getLanguageLabel(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    switch (widget.languageController.languageCode) {
      case "en":
        return localizations?.english ?? "English";
      case "ka":
        return localizations?.georgian ?? "Georgian";
      default:
        return localizations?.english ?? "English";
    }
  }
}
