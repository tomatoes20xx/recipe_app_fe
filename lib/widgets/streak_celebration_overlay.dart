import "package:flutter/material.dart";
import "package:lottie/lottie.dart";

import "../localization/app_localizations.dart";

/// Shows a full-screen streak celebration overlay.
/// The fire animation plays once, then the screen auto-dismisses
/// 1 second after the animation finishes. Tapping also dismisses early.
Future<void> showStreakCelebration(
  BuildContext context, {
  required int streakDays,
  required bool isNewRecord,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "streak-celebration",
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (ctx, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    pageBuilder: (ctx, _, __) => _StreakCelebrationOverlay(
      streakDays: streakDays,
      isNewRecord: isNewRecord,
    ),
  );
}

class _StreakCelebrationOverlay extends StatefulWidget {
  const _StreakCelebrationOverlay({
    required this.streakDays,
    required this.isNewRecord,
  });

  final int streakDays;
  final bool isNewRecord;

  @override
  State<_StreakCelebrationOverlay> createState() =>
      _StreakCelebrationOverlayState();
}

class _StreakCelebrationOverlayState extends State<_StreakCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lottieController;
  bool _textVisible = false;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    // Fade the text in 400ms after the fire starts
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _textVisible = true);
    });
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  void _onLottieLoaded(LottieComposition composition) {
    _lottieController
      ..duration = composition.duration
      ..forward().whenComplete(() {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.of(context).pop();
        });
      });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final streakTitle = widget.streakDays == 1
        ? (l?.streakFirstDay ?? "პირველი ჩაწვა!")
        : (l?.streakNDays(widget.streakDays) ?? "${widget.streakDays}-დღიანი სერია!");

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                "assets/animations/fire.json",
                controller: _lottieController,
                onLoaded: _onLottieLoaded,
                width: 240,
                height: 240,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                opacity: _textVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: AnimatedSlide(
                  offset: _textVisible ? Offset.zero : const Offset(0, 0.2),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  child: Column(
                    children: [
                      Text(
                        streakTitle,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 12,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.isNewRecord) ...[
                        const SizedBox(height: 8),
                        Text(
                          l?.streakRecord ?? "რეკორდი! 🏆",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 12,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
