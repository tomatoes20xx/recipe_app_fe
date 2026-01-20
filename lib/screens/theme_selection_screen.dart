import "package:flutter/material.dart";
import "../localization/app_localizations.dart";
import "../theme/theme_controller.dart";

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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              localizations?.themeMode ?? "Theme Mode",
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
          AnimatedBuilder(
            animation: themeController,
            builder: (context, _) {
              return Column(
                children: [
                  _ThemeOption(
                    themeController: themeController,
                    mode: ThemeMode.system,
                    icon: Icons.brightness_auto,
                    title: localizations?.system ?? "System",
                    subtitle: localizations?.followSystemTheme ?? "Follow system theme",
                  ),
                  const SizedBox(height: 12),
                  _ThemeOption(
                    themeController: themeController,
                    mode: ThemeMode.light,
                    icon: Icons.light_mode,
                    title: localizations?.light ?? "Light",
                    subtitle: localizations?.lightTheme ?? "Light theme",
                  ),
                  const SizedBox(height: 12),
                  _ThemeOption(
                    themeController: themeController,
                    mode: ThemeMode.dark,
                    icon: Icons.dark_mode,
                    title: localizations?.dark ?? "Dark",
                    subtitle: localizations?.darkTheme ?? "Dark theme",
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

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.themeController,
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final ThemeController themeController;
  final ThemeMode mode;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isSelected = themeController.themeMode == mode;
    
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
          icon,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : const Icon(Icons.circle_outlined),
        onTap: () {
          themeController.setThemeMode(mode);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
