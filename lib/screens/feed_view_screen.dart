import 'package:flutter/material.dart';

import '../feed/feed_view_controller.dart';
import '../localization/app_localizations.dart';
import '../theme/app_tokens.dart';
import '../widgets/common/token_widgets.dart';

/// Feed view picker: one grouped radio list, like the Home sort sheet.
class FeedViewScreen extends StatelessWidget {
  const FeedViewScreen({super.key, required this.feedViewController});

  final FeedViewController feedViewController;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTokens.of(context).bg,
      appBar: AppBar(title: Text(localizations?.feedViewType ?? 'Feed View')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AnimatedBuilder(
            animation: feedViewController,
            builder: (context, _) {
              final options = [
                (false, Icons.view_agenda_outlined, localizations?.listView ?? 'List View',
                    localizations?.listViewDescription ?? 'Scroll through recipe cards'),
                (true, Icons.view_carousel_outlined, localizations?.fullScreenView ?? 'Full Screen View',
                    localizations?.fullScreenViewDescription ?? 'Immersive full-screen mode'),
              ];
              return TokenGroup(
                children: [
                  for (var i = 0; i < options.length; i++)
                    TokenRadioRow(
                      leading: options[i].$2,
                      label: options[i].$3,
                      description: options[i].$4,
                      selected: feedViewController.isFullScreenView == options[i].$1,
                      showDivider: i < options.length - 1,
                      onTap: () {
                        feedViewController.setFullScreenView(options[i].$1);
                        Navigator.of(context).pop();
                      },
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
