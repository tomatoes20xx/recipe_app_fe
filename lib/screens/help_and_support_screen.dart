import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:url_launcher/url_launcher.dart";
import "../localization/app_localizations.dart";
import "../widgets/section_title_widget.dart";
import "package:package_info_plus/package_info_plus.dart";

class HelpAndSupportScreen extends StatefulWidget {
  const HelpAndSupportScreen({super.key});

  @override
  State<HelpAndSupportScreen> createState() => _HelpAndSupportScreenState();
}

class _HelpAndSupportScreenState extends State<HelpAndSupportScreen> {
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
              localizations?.helpAndSupport ?? "Help & Support",
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
          // Welcome Message
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          localizations?.helpWelcomeTitle ?? "Welcome to Help & Support",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations?.helpWelcomeMessage ?? 
                    "I'm a solo developer working on CookBook. While I don't have a dedicated support team, I'm here to help! Please check the FAQs below first, and if you still need assistance, feel free to reach out.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          height: 1.5,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Frequently Asked Questions
          SectionTitleWidget(
            text: localizations?.faq ?? "Frequently Asked Questions",
            variant: SectionTitleVariant.large,
          ),
          const SizedBox(height: 16),
          _buildFAQSection(context),
          const SizedBox(height: 32),

          // How to Report Issues
          SectionTitleWidget(
            text: localizations?.reportIssues ?? "Report Issues & Bugs",
            variant: SectionTitleVariant.large,
          ),
          const SizedBox(height: 16),
          _buildReportIssuesSection(context),
          const SizedBox(height: 32),

          // Contact Information
          SectionTitleWidget(
            text: localizations?.contactUs ?? "Contact Us",
            variant: SectionTitleVariant.large,
          ),
          const SizedBox(height: 16),
          _buildContactSection(context),
          const SizedBox(height: 32),

          // App Information
          SectionTitleWidget(
            text: localizations?.appInformation ?? "App Information",
            variant: SectionTitleVariant.large,
          ),
          const SizedBox(height: 16),
          _buildAppInfoSection(context),
        ],
      ),
    );
  }

  Widget _buildFAQSection(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    final faqs = [
      {
        "question": localizations?.faqHowToCreateRecipe ?? "How do I create a recipe?",
        "answer": localizations?.faqHowToCreateRecipeAnswer ?? 
          "Tap the '+' button in the navigation bar or use the 'Create Recipe' option from the menu. Fill in the recipe details including title, description, ingredients, steps, and images, then save.",
      },
      {
        "question": localizations?.faqHowToSaveRecipe ?? "How do I save a recipe?",
        "answer": localizations?.faqHowToSaveRecipeAnswer ?? 
          "When viewing a recipe, tap the bookmark icon to save it. You can view all your saved recipes from the menu under 'Saved Recipes'.",
      },
      {
        "question": localizations?.faqHowToSearch ?? "How do I search for recipes?",
        "answer": localizations?.faqHowToSearchAnswer ?? 
          "Use the search icon in the navigation bar. You can search by recipe name, ingredients, or cuisine type. Use filters to narrow down your search results.",
      },
      {
        "question": localizations?.faqHowToFollowUser ?? "How do I follow other users?",
        "answer": localizations?.faqHowToFollowUserAnswer ?? 
          "Visit a user's profile and tap the 'Follow' button. You'll see their recipes in your 'Following' feed.",
      },
      {
        "question": localizations?.faqAccountIssues ?? "I'm having trouble with my account. What should I do?",
        "answer": localizations?.faqAccountIssuesAnswer ?? 
          "Try logging out and logging back in. If you've forgotten your password, use the password reset option on the login screen. If issues persist, contact us using the information below.",
      },
      {
        "question": localizations?.faqAppNotWorking ?? "The app isn't working properly. What can I do?",
        "answer": localizations?.faqAppNotWorkingAnswer ?? 
          "First, try closing and reopening the app. If that doesn't help, try restarting your device. Make sure you have a stable internet connection. If the problem continues, please report it using the bug reporting section below.",
      },
    ];

    return Column(
      children: faqs.asMap().entries.map((entry) {
        final index = entry.key;
        final faq = entry.value;
        return Column(
          children: [
            _buildExpandableFAQ(context, faq["question"]!, faq["answer"]!),
            if (index < faqs.length - 1) const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildExpandableFAQ(BuildContext context, String question, String answer) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(
          Icons.help_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          question,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        children: [
          Text(
            answer,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportIssuesSection(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations?.reportIssuesInstructions ?? 
              "When reporting a bug or issue, please include:",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _buildBulletPoint(
              context,
              localizations?.reportIssuesAppVersion ?? "App version (shown below)",
            ),
            _buildBulletPoint(
              context,
              localizations?.reportIssuesDeviceInfo ?? "Your device type and OS version",
            ),
            _buildBulletPoint(
              context,
              localizations?.reportIssuesStepsToReproduce ?? "Steps to reproduce the issue",
            ),
            _buildBulletPoint(
              context,
              localizations?.reportIssuesScreenshots ?? "Screenshots if possible",
            ),
            _buildBulletPoint(
              context,
              localizations?.reportIssuesExpectedBehavior ?? "What you expected to happen",
            ),
            const SizedBox(height: 16),
            Text(
              localizations?.reportIssuesNote ?? 
              "Note: As a solo developer, I may not be able to respond immediately, but I review all reports and work on fixes in order of priority.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "• ",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    // TODO: Replace with your actual support email
    const supportEmail = "support@cookbook.app";
    const subject = "CookBook Support Request";
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.email_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(localizations?.contactEmail ?? "Email Support"),
            subtitle: Text(
              supportEmail,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            onTap: () async {
              final uri = Uri(
                scheme: "mailto",
                path: supportEmail,
                queryParameters: {
                  "subject": subject,
                },
              );
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  // Copy email to clipboard as fallback
                  await Clipboard.setData(ClipboardData(text: supportEmail));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          localizations?.emailCopiedToClipboard ?? 
                          "Email address copied to clipboard",
                        ),
                      ),
                    );
                  }
                }
              } catch (e) {
                // Copy email to clipboard as fallback
                await Clipboard.setData(ClipboardData(text: supportEmail));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        localizations?.emailCopiedToClipboard ?? 
                        "Email address copied to clipboard",
                      ),
                    ),
                  );
                }
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.content_copy_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(localizations?.copyEmailAddress ?? "Copy Email Address"),
            subtitle: Text(
              localizations?.copyEmailAddressSubtitle ?? 
              "Copy the support email to your clipboard",
            ),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: supportEmail));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      localizations?.emailCopiedToClipboard ?? 
                      "Email address copied to clipboard",
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoSection(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          FutureBuilder<String>(
            future: _appVersionFuture,
            builder: (context, snapshot) {
              final version = snapshot.data ?? "Loading...";
              return ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(localizations?.version ?? "Version"),
                subtitle: Text(version),
                trailing: IconButton(
                  icon: Icon(
                    Icons.content_copy_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: () async {
                    if (snapshot.hasData) {
                      await Clipboard.setData(ClipboardData(text: version));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              localizations?.versionCopiedToClipboard ?? 
                              "Version copied to clipboard",
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.restaurant_menu_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text("CookBook"),
            subtitle: Text(
              localizations?.appDescription ?? 
              "Your personal recipe collection and sharing platform",
            ),
          ),
        ],
      ),
    );
  }
}
