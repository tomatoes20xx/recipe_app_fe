import "dart:async";

import "package:flutter/material.dart";
import "package:wakelock_plus/wakelock_plus.dart";

import "../localization/app_localizations.dart";
import "../services/proximity_sensor.dart";
import "../theme/app_tokens.dart";
import "../utils/error_utils.dart";
import "../widgets/common/app_bottom_sheet.dart";
import "cooking_mode_prefs.dart";
import "hand_wave_detector.dart";
import "recipe_detail_parts.dart";

/// Opens cooking mode for a recipe. Resolves to true when the user taps
/// "Made it" on the last page; the recipe page then runs its usual cook flow
/// (account gate, streak, celebration).
Future<bool> openCookingMode(
  BuildContext context, {
  required String title,
  required List<String> steps,
  required List<RecipeIngredientLine> ingredients,
  required Set<String> tickedIds,
  required ValueChanged<Set<String>> onTicksChanged,
  required bool canMarkCooked,
}) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CookingModeScreen(
        title: title,
        steps: steps,
        ingredients: ingredients,
        tickedIds: tickedIds,
        onTicksChanged: onTicksChanged,
        canMarkCooked: canMarkCooked,
      ),
    ),
  );
  return result == true;
}

/// One step at a time in large text, swipe or Back/Next, the ingredients
/// (with the page's ticks) one tap away, and the screen kept awake. The last
/// page is "Done!" with "Made it".
///
/// Hand wave (Android phones with a proximity sensor): a quick wave over the
/// top of the phone goes to the next step, covering it for about a second
/// goes back. On by default, toggled from the top bar, explained once.
class CookingModeScreen extends StatefulWidget {
  const CookingModeScreen({
    super.key,
    required this.title,
    required this.steps,
    required this.ingredients,
    required this.tickedIds,
    required this.onTicksChanged,
    required this.canMarkCooked,
  });

  final String title;
  final List<String> steps;
  final List<RecipeIngredientLine> ingredients;
  final Set<String> tickedIds;
  final ValueChanged<Set<String>> onTicksChanged;
  final bool canMarkCooked;

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  final PageController _pages = PageController();
  late Set<String> _ticked = {...widget.tickedIds};
  int _page = 0;

  final HandWaveDetector _handWave = HandWaveDetector();
  final Stopwatch _clock = Stopwatch()..start();
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<bool>? _proximity;
  bool _handWaveAvailable = false;
  bool _handWaveOn = false;
  bool _appVisible = true;
  bool _sheetOpen = false;

  /// The steps, then the "Done!" page.
  int get _pageCount => widget.steps.length + 1;
  bool get _onDonePage => _page == widget.steps.length;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _lifecycle = AppLifecycleListener(
      onShow: () => _setAppVisible(true),
      onHide: () => _setAppVisible(false),
    );
    _initHandWave();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _lifecycle.dispose();
    _proximity?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pages.animateToPage(page, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _initHandWave() async {
    if (!await ProximitySensor.isAvailable()) return;
    final on = await CookingModePrefs.handWaveEnabled();
    if (!mounted) return;
    setState(() {
      _handWaveAvailable = true;
      _handWaveOn = on;
    });
    _syncProximity();
    if (!on || await CookingModePrefs.handWaveHintSeen()) return;
    if (!mounted) return;
    CookingModePrefs.markHandWaveHintSeen();
    _showHandWaveHint();
  }

  void _setAppVisible(bool visible) {
    _appVisible = visible;
    _syncProximity();
  }

  /// The sensor runs only while hand wave is on and the app is on screen.
  void _syncProximity() {
    final listen = _handWaveAvailable && _handWaveOn && _appVisible;
    if (listen && _proximity == null) {
      _handWave.reset();
      _proximity = ProximitySensor.changes.listen(
        _onProximity,
        onError: (Object _) => _stopProximity(unavailable: true),
      );
    } else if (!listen) {
      _stopProximity();
    }
  }

  void _stopProximity({bool unavailable = false}) {
    _proximity?.cancel();
    _proximity = null;
    if (unavailable && mounted) setState(() => _handWaveAvailable = false);
  }

  void _onProximity(bool near) {
    final gesture = _handWave.onReading(near: near, at: _clock.elapsed);
    // While the ingredients sheet is up, a wave would turn the page behind it.
    if (gesture == null || _sheetOpen || !mounted) return;
    switch (gesture) {
      case HandGesture.wave:
        if (!_onDonePage) _goTo(_page + 1);
      case HandGesture.hold:
        if (_page > 0) _goTo(_page - 1);
    }
  }

  void _toggleHandWave() {
    final on = !_handWaveOn;
    _applyHandWave(on);
    if (on) {
      _showHandWaveHint();
    } else {
      final l = AppLocalizations.of(context);
      ErrorUtils.showInfo(context, l?.handWaveTurnedOff ?? "Hand wave turned off");
    }
  }

  /// Saves the setting even if cooking mode has closed meanwhile (the hint's
  /// "Turn off" can still be tapped on the recipe page).
  void _applyHandWave(bool on) {
    CookingModePrefs.setHandWaveEnabled(on);
    if (on) CookingModePrefs.markHandWaveHintSeen();
    if (!mounted) return;
    setState(() => _handWaveOn = on);
    _syncProximity();
  }

  void _showHandWaveHint() {
    final l = AppLocalizations.of(context);
    ErrorUtils.showInfo(
      context,
      l?.handWaveHint ??
          "Wave over the top of the phone for the next step. To go back, cover it with your hand for a second.",
      duration: const Duration(seconds: 8),
      actionLabel: l?.turnOff ?? "Turn off",
      onActionPressed: () => _applyHandWave(false),
    );
  }

  void _toggleTick(String id) {
    setState(() {
      _ticked = {..._ticked};
      if (!_ticked.remove(id)) _ticked.add(id);
    });
    widget.onTicksChanged(_ticked);
  }

  void _clearTicks() {
    setState(() => _ticked = {});
    widget.onTicksChanged(_ticked);
  }

  void _showIngredients() {
    final t = AppTokens.of(context);
    _sheetOpen = true;
    showAppBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8),
          decoration: BoxDecoration(color: t.sheet, borderRadius: sheetTopRadius),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(padding: EdgeInsets.only(top: 8), child: SheetHandle()),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: RecipeIngredientsSection(
                      lines: widget.ingredients,
                      tickedIds: _ticked,
                      onToggle: (id) {
                        _toggleTick(id);
                        setSheetState(() {});
                      },
                      onClearTicks: () {
                        _clearTicks();
                        setSheetState(() {});
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => _sheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final stepCount = widget.steps.length;

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          // Top bar: close, recipe + step, ingredients
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icon(Icons.close_rounded, color: t.ink),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: t.ink2),
                      ),
                      Text(
                        _onDonePage
                            ? (l?.cookingDoneTitle ?? "Done!")
                            : (l?.stepNOfM(_page + 1, stepCount) ?? "Step ${_page + 1} of $stepCount"),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.ink),
                      ),
                    ],
                  ),
                ),
                if (_handWaveAvailable)
                  IconButton(
                    tooltip: _handWaveOn
                        ? (l?.handWaveOnTooltip ?? "Hand wave: on")
                        : (l?.handWaveOffTooltip ?? "Hand wave: off"),
                    onPressed: _toggleHandWave,
                    isSelected: _handWaveOn,
                    icon: Icon(Icons.waving_hand_outlined, color: t.ink2),
                    selectedIcon: Icon(Icons.waving_hand_rounded, color: t.brand),
                  ),
                if (widget.ingredients.isNotEmpty)
                  TextButton.icon(
                    onPressed: _showIngredients,
                    icon: const Icon(Icons.format_list_bulleted_rounded, size: 20),
                    label: Text(l?.ingredients ?? "Ingredients"),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (_page + 1) / _pageCount,
                minHeight: 4,
                color: t.brand,
                backgroundColor: t.line,
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _pageCount,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) => index < stepCount
                  ? _StepPage(number: index + 1, text: widget.steps[index])
                  : _DonePage(
                      canMarkCooked: widget.canMarkCooked,
                      onMadeIt: () => Navigator.of(context).pop(true),
                      onClose: () => Navigator.of(context).pop(false),
                    ),
            ),
          ),
          if (!_onDonePage)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _page == 0 ? null : () => _goTo(_page - 1),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: t.card,
                          foregroundColor: t.ink,
                          side: BorderSide(color: t.line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(l?.previousStep ?? "Back"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => _goTo(_page + 1),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        child: Text(_page == stepCount - 1
                            ? (l?.finishCooking ?? "Finish")
                            : (l?.nextStep ?? "Next")),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
            child: Text(
              "$number",
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: t.brandInk),
            ),
          ),
          const SizedBox(height: 24),
          Text(text, style: TextStyle(fontSize: 22, height: 1.5, color: t.ink)),
        ],
      ),
    );
  }
}

class _DonePage extends StatelessWidget {
  const _DonePage({required this.canMarkCooked, required this.onMadeIt, required this.onClose});

  final bool canMarkCooked;
  final VoidCallback onMadeIt;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
              child: Icon(Icons.local_fire_department_rounded, size: 56, color: t.brandInk),
            ),
            const SizedBox(height: 24),
            Text(
              l?.cookingDoneTitle ?? "Done!",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: t.ink),
            ),
            const SizedBox(height: 8),
            Text(
              canMarkCooked
                  ? (l?.cookingDoneBody ?? "Mark it as cooked to keep your streak going.")
                  : (l?.alreadyCookedToday ?? "Cooked today ✓"),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.5, color: t.ink2),
            ),
            const Spacer(),
            if (canMarkCooked)
              FilledButton.icon(
                onPressed: onMadeIt,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: const Icon(Icons.local_fire_department_rounded),
                label: Text(l?.madeIt ?? "Made it!"),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onClose,
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: Text(MaterialLocalizations.of(context).closeButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
