import "package:flutter/material.dart";

import "../../localization/app_localizations.dart";
import "../../theme/app_tokens.dart";

/// Pinned bar of the create/edit recipe screen: required-items progress,
/// Preview, and the primary (Publish / Save) button. A server error shows in
/// a dismissible banner just above it.
class CreateRecipeBottomBar extends StatelessWidget {
  const CreateRecipeBottomBar({
    super.key,
    required this.requiredDone,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onPreview,
    required this.isSubmitting,
    required this.keyboardOpen,
    this.uploadStatus,
    this.error,
    this.onDismissError,
  });

  /// Title, ingredients, steps.
  final List<bool> requiredDone;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onPreview;
  final bool isSubmitting;
  final bool keyboardOpen;
  final String? uploadStatus;
  final String? error;
  final VoidCallback? onDismissError;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final done = requiredDone.where((d) => d).length;
    final total = requiredDone.length;
    final allDone = done == total;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final status = isSubmitting ? uploadStatus : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 20, color: scheme.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(error!, style: TextStyle(fontSize: 13, color: scheme.onErrorContainer)),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDismissError,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: Icon(Icons.close_rounded, size: 18, color: scheme.onErrorContainer),
                  constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, keyboardOpen ? 12 : 28 + safeBottom),
          decoration: BoxDecoration(
            color: t.card,
            border: Border(top: BorderSide(color: t.line)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: status != null
                      ? Text(
                          status,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink2),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              allDone
                                  ? (l?.readyToPublish ?? "Ready to publish")
                                  : (l?.requiredProgress(done, total) ?? "$done / $total required"),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: allDone ? t.brandInk : t.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ExcludeSemantics(
                              child: Row(
                                children: [
                                  for (var i = 0; i < total; i++) ...[
                                    if (i > 0) const SizedBox(width: 4),
                                    Expanded(
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: requiredDone[i] ? t.brand : t.line,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: l?.preview ?? "Preview",
                  child: Semantics(
                    button: true,
                    label: l?.preview ?? "Preview",
                    excludeSemantics: true,
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : onPreview,
                      style: OutlinedButton.styleFrom(
                        fixedSize: const Size(48, 48),
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                        foregroundColor: t.ink,
                        side: BorderSide(color: t.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Icon(Icons.visibility_outlined, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.46),
                  // Muted while required items are missing, but still
                  // tappable: the tap shows what is missing.
                  child: Opacity(
                    opacity: allDone || isSubmitting ? 1 : 0.4,
                    child: FilledButton(
                      onPressed: isSubmitting ? null : onPrimary,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        backgroundColor: t.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: t.primary,
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                primaryLabel,
                                maxLines: 1,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
