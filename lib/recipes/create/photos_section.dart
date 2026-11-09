import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/semantics.dart" show CustomSemanticsAction;
import "package:flutter/services.dart";

import "../../localization/app_localizations.dart";
import "../../theme/app_tokens.dart";
import "form_widgets.dart";

/// One photo in [PhotosSection].
class PhotoGridItem {
  const PhotoGridItem({required this.id, required this.image, required this.canCrop});

  /// Stays the same when the photo moves or is re-cropped, so its tile
  /// animates to its new slot instead of being rebuilt.
  final Object id;

  /// The picture (file or network), filling its tile with [BoxFit.cover].
  final Widget image;

  /// Local photos only: tapping them opens the cropper. Uploaded photos
  /// can't be re-cropped here, so tapping them does nothing.
  final bool canCrop;
}

/// Photos section body (docs/recipe-photos-grid.md).
///
/// Empty: one big dashed "Add photos" button. With photos: a 3-column grid
/// of square tiles where the first photo (the cover) spans 2×2, followed by
/// one placeholder per photo still being processed and the "+" tile.
/// Tap a local photo to crop it; long-press any photo to drag it to another
/// slot (screen readers get move-earlier / move-later / make-cover actions
/// instead).
class PhotosSection extends StatefulWidget {
  const PhotosSection({
    super.key,
    required this.photos,
    required this.pendingCount,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
    required this.onCrop,
    required this.onReorder,
    required this.onDragActiveChanged,
  });

  /// Cover first.
  final List<PhotoGridItem> photos;

  /// Photos picked but still being compressed; each gets a spinner tile.
  final int pendingCount;

  /// Shows the "+" tile after the photos.
  final bool canAdd;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int index) onCrop;

  /// Moves the photo at [from] so that it ends up at index [to].
  final void Function(int from, int to) onReorder;

  /// True while a photo is lifted, so the form can stop scrolling.
  final ValueChanged<bool> onDragActiveChanged;

  @override
  State<PhotosSection> createState() => _PhotosSectionState();
}

class _PhotosSectionState extends State<PhotosSection> {
  static const double _gap = 8;
  static const Duration _moveDuration = Duration(milliseconds: 200);

  final _gridKey = GlobalKey();

  /// The lifted photo, and the slot it would land in if dropped now.
  Object? _dragId;
  int? _dropSlot;

  /// Where the finger is inside the tile that is about to be lifted; the
  /// drag reports the tile's top-left, so this turns it back into the
  /// finger position.
  Offset _grabOffset = Offset.zero;

  bool get _dragging => _dragId != null;

  /// Slot 0 is the 2×2 cover at the top left, slots 1 and 2 fill the right
  /// column beside it, and from slot 3 on the grid runs in full rows of 3.
  static Rect _slotRect(int slot, double cell) {
    final pitch = cell + _gap;
    if (slot == 0) return Rect.fromLTWH(0, 0, cell * 2 + _gap, cell * 2 + _gap);
    if (slot <= 2) return Rect.fromLTWH(pitch * 2, pitch * (slot - 1), cell, cell);
    final k = slot - 3;
    return Rect.fromLTWH(pitch * (k % 3), pitch * (2 + k ~/ 3), cell, cell);
  }

  /// The slot under [point] (grid coordinates), gaps included, whether or
  /// not anything is there.
  static int _slotAt(Offset point, double cell) {
    final pitch = cell + _gap;
    final col = (point.dx / pitch).floor().clamp(0, 2);
    final row = math.max(0, (point.dy / pitch).floor());
    if (row < 2) return col < 2 ? 0 : 1 + row;
    return 3 + (row - 2) * 3 + col;
  }

  int _indexOf(Object? id) => widget.photos.indexWhere((p) => p.id == id);

  void _startDrag(Object id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _dragId = id;
      _dropSlot = _indexOf(id);
    });
    widget.onDragActiveChanged(true);
  }

  void _onDragMove(Offset tileTopLeft, double cell) {
    if (!_dragging || widget.photos.isEmpty) return;
    final box = _gridKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final local = box.globalToLocal(tileTopLeft + _grabOffset);
    // Slots after the last photo (spinners, "+") aren't targets.
    final slot = _slotAt(local, cell).clamp(0, widget.photos.length - 1);
    if (slot != _dropSlot) setState(() => _dropSlot = slot);
  }

  /// The finger left the grid: everything slides back.
  void _onDragLeave() {
    if (!_dragging) return;
    setState(() => _dropSlot = _indexOf(_dragId));
  }

  void _onDrop() {
    final from = _indexOf(_dragId);
    final to = _dropSlot;
    _endDrag();
    if (from < 0 || to == null) return;
    final target = to.clamp(0, widget.photos.length - 1);
    if (target != from) widget.onReorder(from, target);
  }

  /// Runs for drops and cancels alike; a drop has already ended the drag.
  void _endDrag() {
    if (!_dragging) return;
    setState(() {
      _dragId = null;
      _dropSlot = null;
    });
    widget.onDragActiveChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty && widget.pendingCount == 0) {
      return _EmptyPhotos(onTap: widget.onAdd);
    }

    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, constraints) => _buildGrid(constraints.maxWidth)),
        // The tip covers cropping too, so it shows from the first photo.
        if (widget.photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _dragging
                ? (l?.photosDropHint ?? "Drop it where you want it · first place is the cover")
                : (l?.photosReorderHint ??
                    "Tap a photo to crop it. To reorder, press and hold a photo for 1–2 seconds and drag it where you want."),
            style: TextStyle(fontSize: 12, color: t.ink2),
          ),
        ],
      ],
    );
  }

  Widget _buildGrid(double width) {
    final photos = widget.photos;
    final n = photos.length;
    final pending = widget.pendingCount;
    final cell = (width - _gap * 2) / 3;
    final slotCount = n + pending + (widget.canAdd ? 1 : 0);
    final height = math.max(_slotRect(0, cell).bottom, _slotRect(slotCount - 1, cell).bottom);

    // Display order. While dragging, the lifted photo's slot moves to the
    // drop slot and the photos in between shift by one.
    final order = List<int>.generate(n, (i) => i);
    final from = _indexOf(_dragId);
    if (from >= 0 && _dropSlot != null) {
      order.insert(_dropSlot!.clamp(0, n - 1), order.removeAt(from));
    }

    Widget place(Key key, int slot, Widget child) => AnimatedPositioned.fromRect(
          key: key,
          rect: _slotRect(slot, cell),
          duration: _moveDuration,
          curve: Curves.easeOut,
          child: child,
        );

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) => _indexOf(details.data) >= 0,
      onMove: (details) => _onDragMove(details.offset, cell),
      onLeave: (_) => _onDragLeave(),
      onAcceptWithDetails: (_) => _onDrop(),
      builder: (context, candidates, rejected) => SizedBox(
        key: _gridKey,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var slot = 0; slot < n; slot++)
              place(ValueKey(photos[order[slot]].id), slot, _buildPhoto(order[slot], slot, cell)),
            for (var p = 0; p < pending; p++) place(ValueKey("pending-$p"), n + p, const _PendingTile()),
            if (widget.canAdd) place(const ValueKey("add"), n + pending, _AddTile(onTap: widget.onAdd)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto(int index, int slot, double cell) {
    final l = AppLocalizations.of(context);
    final photo = widget.photos[index];
    final n = widget.photos.length;
    final lifted = photo.id == _dragId;

    final label = index == 0
        ? "${l?.photoLabel(1) ?? "Photo 1"}, ${l?.coverBadge ?? "Cover"}"
        : (l?.photoLabel(index + 1) ?? "Photo ${index + 1}");

    return Semantics(
      container: true,
      label: label,
      // Tapping a local photo opens the cropper; uploaded ones can't be
      // re-cropped, so they have no tap.
      onTap: photo.canCrop && !_dragging ? () => widget.onCrop(index) : null,
      onTapHint: photo.canCrop ? (l?.cropPhoto ?? "Crop") : null,
      customSemanticsActions: {
        if (index > 0)
          CustomSemanticsAction(label: l?.moveEarlier ?? "Move earlier"): () => widget.onReorder(index, index - 1),
        if (index < n - 1)
          CustomSemanticsAction(label: l?.moveLater ?? "Move later"): () => widget.onReorder(index, index + 1),
        if (index > 0) CustomSemanticsAction(label: l?.makeCover ?? "Make cover"): () => widget.onReorder(index, 0),
      },
      child: Listener(
        onPointerDown: (e) {
          if (!_dragging) _grabOffset = e.localPosition;
        },
        onPointerMove: (e) {
          if (!_dragging) _grabOffset = e.localPosition;
        },
        child: LongPressDraggable<Object>(
          data: photo.id,
          delay: const Duration(milliseconds: 300),
          hapticFeedbackOnStart: false,
          // One photo at a time, and a lone photo has nowhere to go.
          maxSimultaneousDrags: n < 2 || (_dragging && !lifted) ? 0 : 1,
          feedback: _LiftedPhoto(size: _slotRect(slot, cell).size, child: photo.image),
          childWhenDragging: const _DropSlot(),
          onDragStarted: () => _startDrag(photo.id),
          onDragEnd: (_) => _endDrag(),
          child: _PhotoTile(
            image: photo.image,
            // The badge follows slot 0, so it moves as soon as another photo
            // is dragged in front.
            cover: slot == 0,
            showControls: !_dragging,
            canCrop: photo.canCrop,
            onRemove: () => widget.onRemove(index),
            onCrop: () => widget.onCrop(index),
          ),
        ),
      ),
    );
  }
}

const double _tileRadius = 14;

class _EmptyPhotos extends StatelessWidget {
  const _EmptyPhotos({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    return DashedBox(
      onTap: onTap,
      radius: 20,
      color: t.card,
      semanticLabel: l?.addPhotos ?? "Add photos",
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 176),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.add_photo_alternate_outlined, size: 26, color: t.brandInk),
              ),
              const SizedBox(height: 12),
              Text(
                l?.addPhotos ?? "Add photos",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink),
              ),
              const SizedBox(height: 4),
              Text(
                l?.coverPhotoHint ?? "The first photo will be the cover",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: t.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.image,
    required this.cover,
    required this.showControls,
    required this.canCrop,
    required this.onRemove,
    required this.onCrop,
  });

  final Widget image;
  final bool cover;
  final bool showControls;
  final bool canCrop;
  final VoidCallback onRemove;
  final VoidCallback onCrop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(_tileRadius), child: image),
        // Tap a local photo to crop it. A tap ends before the long-press
        // delay, so it never competes with dragging.
        if (canCrop && showControls)
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onCrop,
              borderRadius: BorderRadius.circular(_tileRadius),
              // The tile's Semantics carries the tap and its hint.
              excludeFromSemantics: true,
            ),
          ),
        if (cover)
          Positioned(
            left: 10,
            bottom: 10,
            // The tile's own label already says "cover"; taps pass through
            // to the photo.
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000), // black 60%, over a photo
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l?.coverBadge ?? "Cover",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        if (showControls)
          Positioned(
            top: 0,
            right: 0,
            child: _TileButton(
              icon: Icons.close_rounded,
              iconSize: 13,
              label: l?.removePhoto ?? "Remove photo",
              onTap: onRemove,
            ),
          ),
      ],
    );
  }
}

/// 30px dark circle 6px in from the tile's top-right corner, inside a 44×44
/// hit area.
class _TileButton extends StatelessWidget {
  const _TileButton({
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0x8C000000), // black 55%, over a photo
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: iconSize, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A picked photo still being compressed.
class _PendingTile extends StatelessWidget {
  const _PendingTile();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    return Semantics(
      label: l?.processingPhotos ?? "Processing photos…",
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.field, borderRadius: BorderRadius.circular(_tileRadius)),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.brandInk),
          ),
        ),
      ),
    );
  }
}

/// Where the lifted photo will land: dashed brand outline on soft.
class _DropSlot extends StatelessWidget {
  const _DropSlot();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(color: t.brand, borderRadius: _tileRadius, strokeWidth: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(_tileRadius)),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// The photo under the finger while dragging: grows to 1.06, tilts −4° and
/// casts a shadow as it lifts.
class _LiftedPhoto extends StatelessWidget {
  const _LiftedPhoto({required this.size, required this.child});

  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      builder: (context, v, child) => Transform.rotate(
        angle: -4 * math.pi / 180 * v,
        child: Transform.scale(
          scale: 1 + 0.06 * v,
          child: Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_tileRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22 * v),
                  offset: Offset(0, 14 * v),
                  blurRadius: 30 * v,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(_tileRadius), child: child),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    return DashedBox(
      onTap: onTap,
      radius: _tileRadius,
      color: t.card,
      semanticLabel: l?.addPhotos ?? "Add photos",
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 22, color: t.brandInk),
                const SizedBox(height: 2),
                Text(
                  l?.add ?? "Add",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.brandInk),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
