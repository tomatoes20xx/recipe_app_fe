import "package:flutter/material.dart";
import "../localization/app_localizations.dart";
import "../theme/app_tokens.dart";
import "../theme/theme_controller.dart";
import "../widgets/common/token_widgets.dart";

/// Theme picker: one grouped radio list, like the Home sort sheet.
class ThemeSelectionScreen extends StatelessWidget {
  const ThemeSelectionScreen({
    super.key,
    required this.themeController,
  });

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTokens.of(context).bg,
      appBar: AppBar(title: Text(localizations?.themeMode ?? "Theme Mode")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AnimatedBuilder(
            animation: themeController,
            builder: (context, _) {
              final options = [
                (ThemeMode.system, Icons.brightness_auto_outlined, localizations?.system ?? "System",
                    localizations?.followSystemTheme ?? "Follow system theme"),
                (ThemeMode.light, Icons.light_mode_outlined, localizations?.light ?? "Light",
                    localizations?.lightTheme ?? "Light theme"),
                (ThemeMode.dark, Icons.dark_mode_outlined, localizations?.dark ?? "Dark",
                    localizations?.darkTheme ?? "Dark theme"),
              ];
              return TokenGroup(
                children: [
                  for (var i = 0; i < options.length; i++)
                    TokenRadioRow(
                      leading: options[i].$2,
                      label: options[i].$3,
                      description: options[i].$4,
                      selected: themeController.themeMode == options[i].$1,
                      showDivider: i < options.length - 1,
                      onTap: () {
                        themeController.setThemeMode(options[i].$1);
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
