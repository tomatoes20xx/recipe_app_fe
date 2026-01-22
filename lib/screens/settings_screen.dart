import "package:flutter/material.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../localization/language_controller.dart";
import "../theme/theme_controller.dart";
import "package:package_info_plus/package_info_plus.dart";
import "theme_selection_screen.dart";
import "language_selection_screen.dart";
import "terms_and_privacy_screen.dart";
import "../widgets/section_title_widget.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themeController,
    required this.languageController,
    this.auth,
  });

  final ThemeController themeController;
  final LanguageController languageController;
  final AuthController? auth;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<String>? _appVersionFuture;

  @override
  void initState() {
    super.initState();
    _appVersionFuture = _loadAppVersion();
  }

  Future<String> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              localizations?.settings ?? "Settings",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            );
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          SectionTitleWidget(
            text: localizations?.appearance ?? "Appearance",
            variant: SectionTitleVariant.settings,
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Theme Mode
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return AnimatedBuilder(
                      animation: widget.themeController,
                      builder: (context, _) {
                        return ListTile(
                          leading: Icon(
                            Icons.palette_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(localizations?.themeMode ?? "Theme Mode"),
                          subtitle: Text(_getThemeModeLabel(context)),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ThemeSelectionScreen(
                                  themeController: widget.themeController,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                const Divider(height: 1),
                // Language
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return ListTile(
                      leading: Icon(
                        Icons.language,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(localizations?.language ?? "Language"),
                      subtitle: Text(_getLanguageLabel(context)),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LanguageSelectionScreen(
                              languageController: widget.languageController,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Account Section (only if logged in)
          if (widget.auth?.isLoggedIn == true) ...[
            SectionTitleWidget(
              text: localizations?.account ?? "Account",
              variant: SectionTitleVariant.settings,
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  final username = widget.auth?.me?["username"]?.toString();
                  final email = widget.auth?.me?["email"]?.toString();
                  
                  return Column(
                    children: [
                      if (username != null)
                        ListTile(
                          leading: Icon(
                            Icons.person_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(localizations?.username ?? "Username"),
                          subtitle: Text("@$username"),
                        ),
                      if (username != null && email != null) const Divider(height: 1),
                      if (email != null)
                        ListTile(
                          leading: Icon(
                            Icons.email_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(localizations?.email ?? "Email"),
                          subtitle: Text(email),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // About Section
          SectionTitleWidget(
            text: localizations?.about ?? "About",
            variant: SectionTitleVariant.settings,
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                FutureBuilder<String>(
                  key: const ValueKey("app_version"),
                  future: _appVersionFuture,
                  builder: (context, snapshot) {
                    final localizations = AppLocalizations.of(context);
                    String? versionText;
                    
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // While loading, don't show subtitle
                      versionText = null;
                    } else if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                      versionText = "${localizations?.version ?? "Version"} ${snapshot.data}";
                    }
                    
                    return ListTile(
                      leading: Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text("CookBook"),
                      subtitle: versionText != null ? Text(versionText) : null,
                    );
                  },
                ),
                const Divider(height: 1),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return ListTile(
                      leading: Icon(
                        Icons.help_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(localizations?.helpAndSupport ?? "Help & Support"),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onTap: () {
                        // TODO: Navigate to help & support screen or show dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(localizations?.helpAndSupport ?? "Help & Support"),
                          ),
                        );
                      },
                    );
                  },
                ),
                const Divider(height: 1),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return ListTile(
                      leading: Icon(
                        Icons.description_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(localizations?.termsAndPrivacy ?? "Terms & Privacy"),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TermsAndPrivacyScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
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

