import 'package:flutter/material.dart';

import '../feed/feed_view_controller.dart';
import '../localization/app_localizations.dart';

class FeedViewScreen extends StatelessWidget {
  const FeedViewScreen({super.key, required this.feedViewController});

  final FeedViewController feedViewController;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          localizations?.feedViewType ?? 'Feed View',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AnimatedBuilder(
            animation: feedViewController,
            builder: (context, _) {
              return Column(
                children: [
                  _FeedViewOption(
                    feedViewController: feedViewController,
                    isFullScreen: false,
                    icon: Icons.view_agenda_rounded,
                    title: localizations?.listView ?? 'List View',
                    subtitle: localizations?.listViewDescription ?? 'Scroll through recipe cards',
                  ),
                  const SizedBox(height: 12),
                  _FeedViewOption(
                    feedViewController: feedViewController,
                    isFullScreen: true,
                    icon: Icons.view_carousel_rounded,
                    title: localizations?.fullScreenView ?? 'Full Screen View',
                    subtitle: localizations?.fullScreenViewDescription ?? 'Immersive full-screen mode',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeedViewOption extends StatelessWidget {
  const _FeedViewOption({
    required this.feedViewController,
    required this.isFullScreen,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final FeedViewController feedViewController;
  final bool isFullScreen;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isSelected = feedViewController.isFullScreenView == isFullScreen;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
            : const Icon(Icons.circle_outlined),
        onTap: () {
          feedViewController.setFullScreenView(isFullScreen);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
