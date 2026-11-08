import "package:flutter/material.dart";

import "../../theme/app_tokens.dart";

/// Equal-width text tab with a 3px `brand` underline when active (Home feed
/// scopes, Recipes screen). Put it in an `Expanded` inside a row that has a
/// 1px `line` bottom border; the underline sits directly on that border.
class UnderlineTab extends StatelessWidget {
  const UnderlineTab({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Semantics(
      button: true,
      selected: isActive,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 9),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? t.ink : t.ink2,
                ),
              ),
            ),
            Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isActive ? t.brand : Colors.transparent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
