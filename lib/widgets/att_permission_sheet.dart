import "dart:io";

import "package:app_tracking_transparency/app_tracking_transparency.dart";
import "package:flutter/material.dart";

import "../localization/app_localizations.dart";
import "common/app_bottom_sheet.dart";

void showAttPermissionSheet(BuildContext context) {
  if (!Platform.isIOS) return;

  showAppBottomSheet(
    context: context,
    builder: (ctx) => const _AttPermissionSheet(),
  );
}

class _AttPermissionSheet extends StatelessWidget {
  const _AttPermissionSheet();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l?.attPermissionTitle ?? "Personalized Experience",
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              l?.attPermissionSubtitle ?? "Yummy uses ads to keep the app free. Allowing tracking helps us show you ads that are actually relevant to you.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                "assets/images/tracking_popup.jpeg",
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_rounded, color: theme.colorScheme.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  l?.attPermissionTapAllow ?? "Tap \"Allow\"",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _BenefitRow(
              icon: Icons.block_rounded,
              iconColor: theme.colorScheme.primary,
              title: l?.attPermissionBenefit1 ?? "Fewer irrelevant ads",
              description: l?.attPermissionBenefit1Description ?? "See ads that match your interests instead of random ones",
            ),
            const SizedBox(height: 16),
            _BenefitRow(
              icon: Icons.stars_rounded,
              iconColor: theme.colorScheme.primary,
              title: l?.attPermissionBenefit2 ?? "Better overall experience",
              description: l?.attPermissionBenefit2Description ?? "Help keep the app free and support a better in-app experience",
            ),
            const SizedBox(height: 24),
            Text(
              l?.attPermissionNote ?? "Your data is never sold. This only improves your in-app experience.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await AppTrackingTransparency.requestTrackingAuthorization();
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  l?.attPermissionAllow ?? "Continue",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  l?.attPermissionSkip ?? "No thanks",
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 15,
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

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
