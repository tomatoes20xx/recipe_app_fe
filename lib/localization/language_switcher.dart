import "package:flutter/material.dart";
import "app_localizations.dart";
import "language_controller.dart";

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({
    super.key,
    required this.languageController,
  });

  final LanguageController languageController;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return PopupMenuButton<String>(
      tooltip: localizations?.language ?? "Language",
      icon: const Icon(Icons.language),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (languageCode) {
        languageController.setLanguageCode(languageCode);
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: "en",
          child: Row(
            children: [
              if (languageController.languageCode == "en")
                Icon(
                  Icons.check,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              if (languageController.languageCode == "en") const SizedBox(width: 8),
              Text(localizations?.english ?? "English"),
            ],
          ),
        ),
        PopupMenuItem(
          value: "ka",
          child: Row(
            children: [
              if (languageController.languageCode == "ka")
                Icon(
                  Icons.check,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              if (languageController.languageCode == "ka") const SizedBox(width: 8),
              Text(localizations?.georgian ?? "Georgian"),
            ],
          ),
        ),
      ],
    );
  }
}
