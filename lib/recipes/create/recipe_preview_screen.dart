import "dart:io";

import "package:flutter/material.dart";

import "../../constants/cuisines.dart";
import "../../constants/enums.dart";
import "../../localization/app_localizations.dart";
import "../../theme/app_tokens.dart";
import "../../utils/ui_utils.dart";
import "../../widgets/common/profile_avatar.dart";

/// A photo in the preview: an uploaded image ([url]) or a picked file.
class RecipePreviewImage {
  const RecipePreviewImage.url(String this.url) : filePath = null;
  const RecipePreviewImage.file(String this.filePath) : url = null;

  final String? url;
  final String? filePath;
}

class RecipePreviewIngredient {
  const RecipePreviewIngredient({required this.amount, required this.name});

  /// Amount and unit, e.g. "500 გრ"; may be empty.
  final String amount;
  final String name;
}

class RecipePreviewAuthor {
  const RecipePreviewAuthor({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;
}

/// The form's in-memory state, as the preview shows it.
class RecipePreviewData {
  const RecipePreviewData({
    required this.title,
    required this.description,
    required this.cuisine,
    required this.tags,
    required this.cookingTimeMin,
    required this.cookingTimeMax,
    required this.servings,
    required this.difficulty,
    required this.ingredients,
    required this.steps,
    required this.images,
  });

  final String title;
  final String description;
  final String cuisine;
  final List<String> tags;
  final int? cookingTimeMin;
  final int? cookingTimeMax;
  final int? servings;
  final Difficulty? difficulty;
  final List<RecipePreviewIngredient> ingredients;
  final List<String> steps;
  final List<RecipePreviewImage> images;
}

/// Read-only look at the recipe before publishing, built from the form (the
/// real detail screen loads by id). Pops `true` when the user taps the
/// primary button, so the form runs its own submit; anything else means
/// "back to editing".
class RecipePreviewScreen extends StatefulWidget {
  const RecipePreviewScreen({super.key, required this.data, required this.primaryLabel, required this.author});

  final RecipePreviewData data;
  final String primaryLabel;
  final Future<RecipePreviewAuthor?> author;

  @override
  State<RecipePreviewScreen> createState() => _RecipePreviewScreenState();
}

class _RecipePreviewScreenState extends State<RecipePreviewScreen> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final d = widget.data;

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          _Banner(onBack: () => Navigator.of(context).pop(false)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _photos(t),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.title,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: t.ink, height: 1.2),
                      ),
                      const SizedBox(height: 12),
                      _authorRow(t),
                      ..._meta(t, l),
                      if (d.description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(d.description, style: TextStyle(fontSize: 15, height: 1.6, color: t.ink)),
                      ],
                      if (d.tags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(spacing: 8, runSpacing: 8, children: [for (final tag in d.tags) _pill(t, "#$tag")]),
                      ],
                      if (d.ingredients.isNotEmpty) ...[const SizedBox(height: 24), _ingredients(t, l)],
                      if (d.steps.isNotEmpty) ...[const SizedBox(height: 24), _steps(t, l)],
                    ],
                  ),
                ),
              ],
            ),
          ),
          _BottomBar(
            primaryLabel: widget.primaryLabel,
            onEdit: () => Navigator.of(context).pop(false),
            onPrimary: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  Widget _photos(AppTokens t) {
    final images = widget.data.images;
    if (images.isEmpty) {
      return const SizedBox(height: 250, child: RecipeFallbackImage(width: double.infinity, height: 250));
    }
    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final img = images[i];
              return img.url != null
                  ? RecipeImageWidget(imageUrl: img.url!, width: double.infinity, height: 250, fit: BoxFit.cover)
                  : Image.file(File(img.filePath!), fit: BoxFit.cover, width: double.infinity, height: 250);
            },
          ),
          if (images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page ? t.card : t.card.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _authorRow(AppTokens t) {
    return FutureBuilder<RecipePreviewAuthor?>(
      future: widget.author,
      builder: (context, snap) {
        final author = snap.data;
        if (author == null) return const SizedBox.shrink();
        return Row(
          children: [
            ProfileAvatar(avatarUrl: author.avatarUrl, name: author.name, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                author.name,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _meta(AppTokens t, AppLocalizations? l) {
    final d = widget.data;
    final chips = <Widget>[];
    final min = d.cookingTimeMin;
    final max = d.cookingTimeMax;
    if (min != null || max != null) {
      final range = min != null && max != null && min != max ? "$min–$max" : "${min ?? max}";
      chips.add(_metaChip(t, Icons.schedule_rounded, "$range ${l?.minuteAbbreviation ?? "min"}"));
    }
    if (d.servings != null) {
      chips.add(_metaChip(t, Icons.people_outline_rounded, "${d.servings} ${l?.servingsAbbreviation ?? "serv."}"));
    }
    if (d.difficulty != null) {
      final label = switch (d.difficulty!) {
        Difficulty.easy => l?.easy ?? "Easy",
        Difficulty.medium => l?.medium ?? "Medium",
        Difficulty.hard => l?.hard ?? "Hard",
      };
      chips.add(_metaChip(t, Icons.signal_cellular_alt_rounded, label));
    }
    if (d.cuisine.isNotEmpty) {
      chips.add(_metaChip(t, Icons.public_rounded, getLocalizedCuisine(d.cuisine, l)));
    }
    if (chips.isEmpty) return const [];
    return [const SizedBox(height: 16), Wrap(spacing: 8, runSpacing: 8, children: chips)];
  }

  Widget _metaChip(AppTokens t, IconData icon, String label) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: t.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: t.brandInk),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(AppTokens t, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(17)),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.brandInk),
      ),
    );
  }

  Widget _ingredients(AppTokens t, AppLocalizations? l) {
    final items = widget.data.ingredients;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l?.nIngredients(items.length) ?? "${items.length} ingredients",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.ink),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < items.length; i++)
            Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i < items.length - 1 ? Border(bottom: BorderSide(color: t.line)) : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      items[i].amount,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.brandInk),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(items[i].name, style: TextStyle(fontSize: 15, color: t.ink)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _steps(AppTokens t, AppLocalizations? l) {
    final steps = widget.data.steps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${l?.steps ?? "Steps"} (${steps.length})",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.ink),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                  child: Text(
                    "${i + 1}",
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.brandInk),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(steps[i], style: TextStyle(fontSize: 15, height: 1.5, color: t.ink)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      color: t.soft,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Icon(Icons.arrow_back_rounded, color: t.ink),
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l?.preview ?? "Preview",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink),
                ),
                Text(
                  l?.previewSubtitle ?? "This is how others will see it",
                  style: TextStyle(fontSize: 12, color: t.brandInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.primaryLabel, required this.onEdit, required this.onPrimary});

  final String primaryLabel;
  final VoidCallback onEdit;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + (bottom > 0 ? bottom : 16)),
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: t.ink,
                side: BorderSide(color: t.line),
                shape: shape,
              ),
              child: Text(l?.edit ?? "Edit", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: t.primary,
                foregroundColor: Colors.white,
                shape: shape,
              ),
              child: Text(
                primaryLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
