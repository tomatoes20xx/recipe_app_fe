import "package:flutter/material.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../localization/language_controller.dart";
import "../theme/theme_controller.dart";
import "package:package_info_plus/package_info_plus.dart";
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
    this.auth,
    this.apiClient,
  });

  final ThemeController themeController;
  final LanguageController languageController;
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
        ErrorUtils.showSuccess(context, "Privacy settings updated");
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
    final theme = Theme.of(context);
    final isLoggedIn = widget.auth?.isLoggedIn == true;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            backgroundColor: theme.colorScheme.surface,
            title: Text(
              localizations?.settings ?? "Settings",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // User Header (if logged in)
          if (isLoggedIn)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.08),
                      theme.colorScheme.primary.withValues(alpha: 0.03),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildUserHeader(context),
              ),
            ),

          // Settings Content
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // Preferences Section
                _buildSectionLabel(
                  context,
                  localizations?.appPreferences ?? "Preferences",
                ),
                const SizedBox(height: 12),
                _buildSettingsGroup(
                  context,
                  children: [
                    _buildSettingsTile(
                      context,
                      icon: Icons.palette_outlined,
                      iconColor: theme.colorScheme.primary,
                      title: localizations?.themeMode ?? "Theme",
                      subtitle: _getThemeModeLabel(context),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ThemeSelectionScreen(
                              themeController: widget.themeController,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      context,
                      icon: Icons.translate_rounded,
                      iconColor: Colors.orange,
                      title: localizations?.language ?? "Language",
                      subtitle: _getLanguageLabel(context),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LanguageSelectionScreen(
                              languageController: widget.languageController,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Privacy Section (only if logged in)
                if (isLoggedIn) ...[
                  _buildSectionLabel(
                    context,
                    localizations?.privacy ?? "Privacy",
                  ),
                  const SizedBox(height: 12),
                  _buildPrivacySettings(context),
                  const SizedBox(height: 28),
                ],

                // Support Section
                _buildSectionLabel(
                  context,
                  localizations?.about ?? "Support",
                ),
                const SizedBox(height: 12),
                _buildSettingsGroup(
                  context,
                  children: [
                    _buildSettingsTile(
                      context,
                      icon: Icons.help_outline_rounded,
                      iconColor: Colors.blue,
                      title: localizations?.helpAndSupport ?? "Help & Support",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HelpAndSupportScreen(),
                          ),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      context,
                      icon: Icons.shield_outlined,
                      iconColor: Colors.teal,
                      title: localizations?.termsAndPrivacy ?? "Terms & Privacy",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TermsAndPrivacyScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Logout Button (if logged in)
                if (isLoggedIn) ...[
                  _buildLogoutButton(context),
                  const SizedBox(height: 28),
                ],

                // App Info Footer
                _buildAppInfoFooter(context),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    final theme = Theme.of(context);
    final username = widget.auth?.me?["username"]?.toString();
    final email = widget.auth?.me?["email"]?.toString();
    final displayName = widget.auth?.me?["display_name"]?.toString();
    final avatarUrl = widget.auth?.me?["avatar_url"]?.toString();

    return Row(
      children: [
        // Avatar
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            image: avatarUrl != null && avatarUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(avatarUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Icon(
                  Icons.person_rounded,
                  size: 28,
                  color: theme.colorScheme.primary,
                )
              : null,
        ),
        const SizedBox(width: 16),
        // User Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName ?? username ?? "",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (email != null) ...[
                const SizedBox(height: 2),
                Text(
                  email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(
    BuildContext context, {
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon with background
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 14),
              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacySettings(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
              children: [
                SwitchListTile(
                  title: Text(localizations?.privateFollowers ?? "Private Followers"),
                  subtitle: Text(localizations?.hideYourFollowersListFromOthers ?? "Hide your followers list from others"),
                  value: _privacySettings.followersPrivate,
                  onChanged: _isLoadingPrivacy
                      ? null
                      : (value) {
                          _updatePrivacy(followersPrivate: value);
                        },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                ),
                SwitchListTile(
                  title: Text(localizations?.privateFollowing ?? "Private Following"),
                  subtitle: Text(localizations?.hideYourFollowingListFromOthers ?? "Hide your following list from others"),
                  value: _privacySettings.followingPrivate,
                  onChanged: _isLoadingPrivacy
                      ? null
                      : (value) {
                          _updatePrivacy(followingPrivate: value);
                        },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showLogoutDialog(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                size: 20,
                color: Colors.red.shade600,
              ),
              const SizedBox(width: 10),
              Text(
                localizations?.logout ?? "Log Out",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          localizations?.logout ?? "Log Out",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          localizations?.logoutConfirmation ?? "Are you sure you want to log out?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              localizations?.cancel ?? "Cancel",
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.auth?.logout();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(
              localizations?.logout ?? "Log Out",
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
