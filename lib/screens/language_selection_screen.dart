import "package:flutter/material.dart";
import "../localization/app_localizations.dart";
import "../localization/language_controller.dart";

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({
    super.key,
    required this.languageController,
  });

  final LanguageController languageController;

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
              localizations?.language ?? "Language",
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
          _LanguageOption(
            languageController: languageController,
            languageCode: "en",
            title: localizations?.english ?? "English",
          ),
          const SizedBox(height: 12),
          _LanguageOption(
            languageController: languageController,
            languageCode: "ka",
            title: localizations?.georgian ?? "Georgian",
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.languageController,
    required this.languageCode,
    required this.title,
  });

  final LanguageController languageController;
  final String languageCode;
  final String title;

  @override
  Widget build(BuildContext context) {
    final isSelected = languageController.languageCode == languageCode;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.language,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        title: Text(title),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : const Icon(Icons.circle_outlined),
        onTap: () {
          languageController.setLanguageCode(languageCode);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
