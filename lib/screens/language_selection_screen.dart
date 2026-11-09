import "package:flutter/material.dart";
import "../localization/app_localizations.dart";
import "../localization/language_controller.dart";
import "../theme/app_tokens.dart";
import "../widgets/common/token_widgets.dart";

/// Language picker: one grouped radio list, like the Home sort sheet.
class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({
    super.key,
    required this.languageController,
  });

  final LanguageController languageController;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final options = [
      ("ka", localizations?.georgian ?? "Georgian"),
      ("en", localizations?.english ?? "English"),
    ];

    return Scaffold(
      backgroundColor: AppTokens.of(context).bg,
      appBar: AppBar(title: Text(localizations?.language ?? "Language")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TokenGroup(
            children: [
              for (var i = 0; i < options.length; i++)
                TokenRadioRow(
                  leading: Icons.translate_rounded,
                  label: options[i].$2,
                  selected: languageController.languageCode == options[i].$1,
                  showDivider: i < options.length - 1,
                  onTap: () {
                    languageController.setLanguageCode(options[i].$1);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
