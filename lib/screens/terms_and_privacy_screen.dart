import "package:flutter/material.dart";
import "../localization/app_localizations.dart";
import "../widgets/section_title_widget.dart";

class TermsAndPrivacyScreen extends StatelessWidget {
  const TermsAndPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.termsAndPrivacy ?? "Terms & Privacy"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Terms of Service Section
          SectionTitleWidget(
            text: localizations?.termsOfService ?? "Terms of Service",
            variant: SectionTitleVariant.large,
          ),
          const SizedBox(height: 16),
          _buildTermsContent(context),
          const SizedBox(height: 32),
          
          // Privacy Policy Section
          SectionTitleWidget(
            text: localizations?.privacyPolicy ?? "Privacy Policy",
            variant: SectionTitleVariant.large,
          ),
          const SizedBox(height: 16),
          _buildPrivacyContent(context),
        ],
      ),
    );
  }

  Widget _buildTermsContent(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          context,
          localizations?.termsAcceptanceTitle ?? "1. Acceptance of Terms",
          localizations?.termsAcceptanceContent ?? "By accessing and using Yummy, you accept and agree to be bound by the terms and provision of this agreement.",
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          localizations?.termsLicenseTitle ?? "2. Use License",
          localizations?.termsLicenseContent ?? "Permission is granted to temporarily use Yummy for personal, non-commercial purposes. This license does not include:\n\n• Reselling or sublicensing the service\n• Using the service for any commercial purpose\n• Removing any copyright or proprietary notations",
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          localizations?.termsAccountsTitle ?? "3. User Accounts",
          localizations?.termsAccountsContent ?? "You are responsible for maintaining the confidentiality of your account credentials. You agree to:\n\n• Provide accurate and complete information\n• Keep your password secure\n• Notify us immediately of any unauthorized use",
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          localizations?.termsContentTitle ?? "4. User Content",
          localizations?.termsContentContent ?? "You retain ownership of content you post on Yummy. By posting content, you grant us a license to use, modify, and display your content on the platform.",
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          localizations?.termsProhibitedTitle ?? "5. Prohibited Uses",
          localizations?.termsProhibitedContent ?? "You may not use Yummy to:\n\n• Violate any laws or regulations\n• Infringe on intellectual property rights\n• Post harmful, offensive, or illegal content\n• Spam or harass other users",
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          localizations?.termsTerminationTitle ?? "6. Termination",
          localizations?.termsTerminationContent ?? "We reserve the right to terminate or suspend your account at any time for violations of these terms.",
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          localizations?.termsChangesTitle ?? "7. Changes to Terms",
          localizations?.termsChangesContent ?? "We reserve the right to modify these terms at any time. Continued use of the service after changes constitutes acceptance of the new terms.",
        ),
      ],
    );
  }

  Widget _buildPrivacyContent(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          context,
          localizations?.privacyCollectTitle ?? "1. Information We Collect",
          localizations?.privacyCollectContent ?? "We collect information that you provide directly to us, including:\n\n• Account information (username, email, display name)\n• Content you create (recipes, comments, images)\n• Usage data and analytics\n• Device information and identifiers",
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          localizations?.privacyUseTitle ?? "2. How We Use Your Information",
          localizations?.privacyUseContent ?? "We use the information we collect to:\n\n• Provide and improve our services\n• Personalize your experience\n• Communicate with you about your account\n• Analyze usage patterns and trends\n• Ensure security and prevent fraud",
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          localizations?.privacySharingTitle ?? "3. Information Sharing",
          localizations?.privacySharingContent ?? "We do not sell your personal information. We may share your information only:\n\n• With your consent\n• To comply with legal obligations\n• To protect our rights and safety\n• With service providers who assist us (under strict confidentiality agreements)",
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          localizations?.privacySecurityTitle ?? "4. Data Security",
          localizations?.privacySecurityContent ?? "We implement appropriate technical and organizational measures to protect your personal information. However, no method of transmission over the internet is 100% secure.",
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          localizations?.privacyRightsTitle ?? "5. Your Rights",
          localizations?.privacyRightsContent ?? "You have the right to:\n\n• Access your personal information\n• Correct inaccurate information\n• Delete your account and data\n• Opt-out of certain data processing\n• Export your data",
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          localizations?.privacyCookiesTitle ?? "6. Cookies and Tracking",
          localizations?.privacyCookiesContent ?? "We use cookies and similar technologies to enhance your experience, analyze usage, and assist with marketing efforts. You can control cookies through your browser settings.",
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          localizations?.privacyChildrenTitle ?? "7. Children's Privacy",
          localizations?.privacyChildrenContent ?? "Yummy is not intended for users under the age of 13. We do not knowingly collect personal information from children under 13.",
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          localizations?.privacyChangesTitle ?? "8. Changes to Privacy Policy",
          localizations?.privacyChangesContent ?? "We may update this privacy policy from time to time. We will notify you of any material changes by posting the new policy on this page.",
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          localizations?.privacyContactTitle ?? "9. Contact Us",
          localizations?.privacyContactContent ?? "If you have questions about this privacy policy, please contact us through the app settings or support channels.",
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.5,
              ),
        ),
      ],
    );
  }
}
