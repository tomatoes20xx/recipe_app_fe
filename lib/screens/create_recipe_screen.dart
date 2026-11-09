import "dart:async";
import "dart:io";
import "dart:isolate";
import "dart:math" as math;
import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart" show listEquals;
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../api/api_client.dart";
import "../auth/auth_api.dart";
import "../constants/cuisines.dart";
import "../constants/enums.dart";
import "../localization/app_localizations.dart";
import "../recipes/create/create_recipe_bottom_bar.dart";
import "../recipes/create/form_widgets.dart";
import "../recipes/create/ingredient_row.dart";
import "../recipes/create/number_stepper.dart";
import "../recipes/create/photos_section.dart";
import "../recipes/create/recipe_preview_screen.dart";
import "../recipes/create/step_card.dart";
import "../recipes/create/tag_picker_sheet.dart";
import "../recipes/recipe_api.dart";
import "../recipes/recipe_detail_models.dart";
import "../services/recipe_draft_service.dart";
import "../theme/app_tokens.dart";
import "../utils/error_utils.dart";
import "../utils/image_utils.dart";
import "../utils/ui_utils.dart";
import "image_crop_screen.dart";

class CreateRecipeScreen extends StatefulWidget {
  const CreateRecipeScreen({
    super.key,
    required this.apiClient,
    this.recipeId,
    this.recipe,
  });

  final ApiClient apiClient;
  final String? recipeId; // If provided, we're editing
  final RecipeDetail? recipe; // Recipe data for editing

  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

/// The form's six sections, in page order.
enum _Section { photos, basics, details, tags, ingredients, method }

class _CreateRecipeScreenState extends State<CreateRecipeScreen>
    with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cuisineController = TextEditingController();
  final _tagController = TextEditingController();
  final _cookingTimeMinController = TextEditingController();
  final _cookingTimeMaxController = TextEditingController();
  final _servingSizeController = TextEditingController();
  final _scrollController = ScrollController();
  final _titleFocus = FocusNode();
  final _maxTimeFocus = FocusNode();

  final List<String> _tags = [];
  final List<_IngredientItem> _ingredients = [];
  final List<_StepItem> _steps = [];
  /// All photos in display order, uploaded and local mixed; index 0 is the
  /// cover.
  final List<_Photo> _photos = [];
  final Set<String> _removedImageIds = {}; // Track removed existing images
  final ImagePicker _imagePicker = ImagePicker();

  /// Photos from the current pick still being compressed.
  int _pendingPhotos = 0;

  /// A photo is being dragged in the grid; the form must not scroll.
  bool _photoDragActive = false;

  Difficulty? _selectedDifficulty;
  String? _cookingTimeError;

  bool _isSubmitting = false;
  bool _submitted = false;
  String? _error;
  String? _uploadStatus; // For showing upload progress
  bool _isEditMode = false;

  final _draftService = RecipeDraftService();

  /// The backend accepts at most this many images per recipe
  /// (routes/recipes.ts); the add tile hides at the limit.
  static const _maxImages = 10;

  /// Debounced draft save (create mode): runs ~2 s after the last edit.
  Timer? _draftTimer;
  bool _draftSaved = false;

  /// True while a recipe or draft is being loaded into the controllers, so
  /// their listeners don't count it as an edit.
  bool _loadingData = false;

  /// The one ingredient row that is expanded, if any.
  _IngredientItem? _expandedIngredient;

  /// Validation messages shown under section headers after a Publish tap.
  Map<_Section, List<String>> _sectionErrors = {};
  final Map<_Section, GlobalKey> _sectionKeys = {
    for (final s in _Section.values) s: GlobalKey(),
  };

  Future<RecipePreviewAuthor?>? _previewAuthor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isEditMode = widget.recipeId != null && widget.recipe != null;
    if (_isEditMode && widget.recipe != null) {
      _loadRecipeData(widget.recipe!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkForDraft());
    }
    for (final c in [
      _titleController,
      _descriptionController,
      _cuisineController,
      _cookingTimeMinController,
      _cookingTimeMaxController,
      _servingSizeController,
    ]) {
      c.addListener(_onTextChanged);
    }
  }

  void _loadRecipeData(RecipeDetail recipe) {
    _titleController.text = recipe.title;
    _descriptionController.text = recipe.description ?? "";
    _cuisineController.text = recipe.cuisine ?? "";
    _tags.addAll(recipe.tags);
    _photos.addAll(recipe.images.map(_ExistingPhoto.new));
    _cookingTimeMinController.text = recipe.cookingTimeMin?.toString() ?? "";
    _cookingTimeMaxController.text = recipe.cookingTimeMax?.toString() ?? "";
    _servingSizeController.text = recipe.servingSize?.toString() ?? "";
    _selectedDifficulty = DifficultyApi.fromApiValue(recipe.difficulty);

    // Load ingredients
    for (final ing in recipe.ingredients) {
      final item = _IngredientItem();
      item.quantityController.text = ing.quantity?.toString() ?? "";
      item.unitController.text = ing.unit ?? "";
      item.nameController.text = ing.displayName;
      _watchIngredient(item);
      _ingredients.add(item);
    }

    // Load steps
    for (final step in recipe.steps) {
      final item = _StepItem();
      item.instructionController.text = step.instruction;
      _watchStep(item);
      _steps.add(item);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    if (!_isEditMode && !_submitted && _hasMeaningfulData()) {
      _saveDraft();
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _cuisineController.dispose();
    _tagController.dispose();
    _cookingTimeMinController.dispose();
    _cookingTimeMaxController.dispose();
    _servingSizeController.dispose();
    _scrollController.dispose();
    _titleFocus.dispose();
    _maxTimeFocus.dispose();
    for (var ing in _ingredients) {
      ing.quantityController.dispose();
      ing.unitController.dispose();
      ing.nameController.dispose();
      ing.nameFocusNode.dispose();
    }
    for (var step in _steps) {
      step.instructionController.dispose();
      step.focusNode.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isEditMode && !_submitted &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive) &&
        _hasMeaningfulData()) {
      _saveDraft();
    }
  }

  bool _hasMeaningfulData() {
    return _titleController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _cuisineController.text.trim().isNotEmpty ||
        _tags.isNotEmpty ||
        _ingredients.any((i) => i.nameController.text.trim().isNotEmpty) ||
        _steps.any((s) => s.instructionController.text.trim().isNotEmpty) ||
        _photos.any((p) => p is _LocalPhoto);
  }

  Future<void> _saveDraft() {
    return _draftService.saveDraft(
      title: _titleController.text,
      description: _descriptionController.text,
      cuisine: _cuisineController.text,
      tags: List.from(_tags),
      cookingTimeMin: _cookingTimeMinController.text,
      cookingTimeMax: _cookingTimeMaxController.text,
      servingSize: _servingSizeController.text,
      difficulty: _selectedDifficulty?.apiValue,
      ingredients: _ingredients
          .map((i) => {
                'quantity': i.quantityController.text,
                'unit': i.unitController.text,
                'name': i.nameController.text,
              })
          .toList(),
      steps: _steps.map((s) => s.instructionController.text).toList(),
      // Local photos in grid order. Only the processed file is kept, so a
      // restored photo re-crops from that rather than from the original.
      imagePaths: [for (final p in _photos) if (p is _LocalPhoto) p.path],
    );
  }

  Future<void> _checkForDraft() async {
    if (!mounted) return;
    final hasDraft = await _draftService.hasDraft();
    if (!mounted || !hasDraft) return;

    final localizations = AppLocalizations.of(context);
    final shouldContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(localizations?.draftFound ?? 'Draft Found'),
        content: Text(
          localizations?.draftFoundMessage ??
              'You have an unsaved recipe draft. Would you like to continue editing it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(localizations?.startFresh ?? 'Start Fresh'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(localizations?.continueDraft ?? 'Continue Draft'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (shouldContinue == true) {
      await _loadDraft();
    } else {
      await _draftService.clearDraft();
    }
  }

  Future<void> _loadDraft() async {
    final draft = await _draftService.loadDraft();
    if (draft == null || !mounted) return;

    _loadingData = true;
    setState(() {
      _titleController.text = (draft['title'] as String?) ?? '';
      _descriptionController.text = (draft['description'] as String?) ?? '';
      _cuisineController.text = (draft['cuisine'] as String?) ?? '';
      _cookingTimeMinController.text =
          (draft['cookingTimeMin'] as String?) ?? '';
      _cookingTimeMaxController.text =
          (draft['cookingTimeMax'] as String?) ?? '';
      _servingSizeController.text =
          (draft['servingSize'] as String?) ?? '';
      final diff = (draft['difficulty'] as String?) ?? '';
      _selectedDifficulty = DifficultyApi.fromApiValue(diff.isEmpty ? null : diff);

      final tags = (draft['tags'] as List<dynamic>?) ?? [];
      _tags.addAll(tags.cast<String>());

      final ingredients = (draft['ingredients'] as List<dynamic>?) ?? [];
      for (final ing in ingredients) {
        final map = ing as Map<String, dynamic>;
        final item = _IngredientItem();
        item.quantityController.text = (map['quantity'] as String?) ?? '';
        item.unitController.text = (map['unit'] as String?) ?? '';
        item.nameController.text = (map['name'] as String?) ?? '';
        _watchIngredient(item);
        _ingredients.add(item);
      }

      final steps = (draft['steps'] as List<dynamic>?) ?? [];
      for (final step in steps) {
        final item = _StepItem();
        item.instructionController.text = (step as String?) ?? '';
        _watchStep(item);
        _steps.add(item);
      }

      final imagePaths = (draft['imagePaths'] as List<dynamic>?) ?? [];
      for (final path in imagePaths) {
        final p = path as String;
        if (File(p).existsSync()) {
          _photos.add(_LocalPhoto(path: p, sourcePath: p));
        }
      }
    });
    _loadingData = false;
  }

  // ---------------------------------------------------------------------------
  // Change tracking: rebuild (section checks, progress) and debounce the draft.

  void _watchIngredient(_IngredientItem item) {
    item.nameController.addListener(_onTextChanged);
    item.quantityController.addListener(_onTextChanged);
    item.unitController.addListener(_onTextChanged);
  }

  void _watchStep(_StepItem item) {
    item.instructionController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_loadingData || !mounted) return;
    setState(() {});
    _markChanged();
  }

  /// Call after any edit that isn't a watched text change (tags, images,
  /// difficulty, add/remove/reorder).
  void _markChanged() {
    if (_loadingData) return;
    if (_sectionErrors.isNotEmpty) {
      // Keep showing errors only for sections that still have them; don't
      // add new ones until the next Publish tap.
      final fresh = _groupErrors(_collectErrors());
      setState(() {
        _sectionErrors = {
          for (final s in _sectionErrors.keys)
            if (fresh[s] != null) s: fresh[s]!,
        };
      });
    }
    _scheduleDraftSave();
  }

  void _scheduleDraftSave() {
    if (_isEditMode || _submitted) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted || _submitted || _isSubmitting || !_hasMeaningfulData()) return;
      await _saveDraft();
      if (mounted && !_submitted) setState(() => _draftSaved = true);
    });
  }

  // ---------------------------------------------------------------------------
  // Tags

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
      _markChanged();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
    _markChanged();
  }

  /// Category / diet chip: same toggle as the old horizontal chip rows.
  void _toggleTag(String label) {
    setState(() {
      if (_tags.contains(label)) {
        _tags.remove(label);
      } else {
        _tags.add(label);
      }
    });
    _markChanged();
  }

  Future<void> _openTagSheet() async {
    FocusScope.of(context).unfocus();
    _tagController.clear();
    await showTagPickerSheet(
      context,
      tags: _tags,
      searchController: _tagController,
      onToggle: _toggleTag,
      onAddCustom: _addTag,
      onRemove: _removeTag,
    );
  }

  // ---------------------------------------------------------------------------
  // Ingredients and steps

  void _addIngredient() {
    final newItem = _IngredientItem();
    _watchIngredient(newItem);
    setState(() {
      _ingredients.add(newItem);
      _expandedIngredient = newItem;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      newItem.nameFocusNode.requestFocus();
    });
    _markChanged();
  }

  void _removeIngredient(int index) {
    setState(() {
      if (_expandedIngredient == _ingredients[index]) _expandedIngredient = null;
      _ingredients[index].quantityController.dispose();
      _ingredients[index].unitController.dispose();
      _ingredients[index].nameController.dispose();
      _ingredients[index].nameFocusNode.dispose();
      _ingredients.removeAt(index);
    });
    _markChanged();
  }

  /// [newIndex] is the final position (ReorderableListView.onReorderItem
  /// already accounts for the removed item).
  void _reorderIngredients(int oldIndex, int newIndex) {
    setState(() {
      final item = _ingredients.removeAt(oldIndex);
      _ingredients.insert(newIndex, item);
    });
    _markChanged();
  }

  void _expandIngredient(_IngredientItem item) {
    setState(() => _expandedIngredient = item);
  }

  void _collapseIngredient(_IngredientItem item) {
    if (!mounted || _expandedIngredient != item) return;
    setState(() => _expandedIngredient = null);
  }

  void _addStep() {
    final newItem = _StepItem();
    _watchStep(newItem);
    setState(() {
      _steps.add(newItem);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      newItem.focusNode.requestFocus();
    });
    _markChanged();
  }

  void _removeStep(int index) {
    setState(() {
      _steps[index].instructionController.dispose();
      _steps[index].focusNode.dispose();
      _steps.removeAt(index);
    });
    _markChanged();
  }

  /// [newIndex] is the final position, as for [_reorderIngredients].
  void _reorderSteps(int oldIndex, int newIndex) {
    setState(() {
      final item = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, item);
    });
    _markChanged();
  }

  // ---------------------------------------------------------------------------
  // Photos (docs/recipe-photos-grid.md)

  int get _imageCount => _photos.length;

  /// Picks up to the remaining number of photos in one go and adds them in
  /// pick order, without a crop step. Each one is compressed in turn while a
  /// spinner holds its grid slot; failures are reported once at the end.
  Future<void> _pickImages() async {
    if (_pendingPhotos > 0 || _isSubmitting) return;
    final localizations = AppLocalizations.of(context);
    final remaining = _maxImages - _photos.length;
    if (remaining <= 0) return;

    final List<XFile> picked;
    try {
      if (remaining >= 2) {
        picked = await _imagePicker.pickMultiImage(imageQuality: 85, limit: remaining);
      } else {
        // pickMultiImage needs a limit of at least 2.
        final image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
        picked = image == null ? const [] : [image];
      }
    } catch (e) {
      if (mounted) ErrorUtils.showError(context, e);
      return;
    }
    if (!mounted || picked.isEmpty) return;

    // Some Android pickers ignore the limit: keep the first ones that fit.
    final batch = picked.take(math.max(0, _maxImages - _photos.length)).toList();
    final skippedForLimit = picked.length - batch.length;

    setState(() => _pendingPhotos = batch.length);
    final failures = <String>[];
    for (final file in batch) {
      final result = await _processPhoto(File(file.path), localizations);
      if (!mounted) return;
      setState(() {
        _pendingPhotos--;
        if (result.path != null) {
          _photos.add(_LocalPhoto(path: result.path!, sourcePath: file.path));
        }
      });
      if (result.error != null) failures.add(result.error!);
    }
    if (!mounted) return;

    final messages = [
      if (skippedForLimit > 0)
        localizations?.photosSkippedLimit(skippedForLimit, _maxImages) ??
            "$skippedForLimit photos weren't added — max $_maxImages",
      if (failures.length == 1)
        failures.single
      else if (failures.length > 1)
        localizations?.photosSkippedTooLarge(failures.length) ??
            "${failures.length} photos were too large and were skipped",
    ];
    if (messages.isNotEmpty) ErrorUtils.showError(context, messages.join("\n"));
    _markChanged();
  }

  /// Same rules as the single-photo flow before multi-pick: use the
  /// compressed copy unless it is still over 5 MB; if compression fails,
  /// keep the file as it is when it's under the limit. Returns the file to
  /// use, or the message to show.
  Future<({String? path, String? error})> _processPhoto(
    File file,
    AppLocalizations? localizations,
  ) async {
    final maxMB = (ImageUtils.maxFileSizeBytes / (1024 * 1024)).toStringAsFixed(0);
    final failed = localizations?.imageCompressionFailed(maxMB) ??
        "Could not process image. Please choose an image smaller than ${maxMB}MB.";
    try {
      final result = await _compressInBackground(file.path);
      if (result != null) {
        final compressedSize = await result.length();
        if (compressedSize > ImageUtils.maxFileSizeBytes) {
          final sizeMB = (compressedSize / (1024 * 1024)).toStringAsFixed(1);
          return (
            path: null,
            error: localizations?.imageTooLarge(sizeMB, maxMB) ??
                "Image is too large (${sizeMB}MB). Maximum size is ${maxMB}MB. Please choose a smaller image.",
          );
        }
        return (path: result.path, error: null);
      }
      if (await file.length() <= ImageUtils.maxFileSizeBytes) {
        return (path: file.path, error: null);
      }
      return (path: null, error: failed);
    } catch (_) {
      return (path: null, error: failed);
    }
  }

  /// [ImageUtils.compressImage] on a background isolate, so the spinners keep
  /// turning while a batch decodes. Static so the closure captures only the
  /// path.
  static Future<File?> _compressInBackground(String path) =>
      Isolate.run(() => ImageUtils.compressImage(File(path)));

  /// Crops a local photo starting from its original pick, so cropping again
  /// doesn't crop the crop, then compresses the result into the photo.
  Future<void> _cropPhoto(int index) async {
    if (_isSubmitting || index >= _photos.length) return;
    final photo = _photos[index];
    if (photo is! _LocalPhoto) return;
    final localizations = AppLocalizations.of(context);

    final source = [photo.sourcePath, photo.path].map(File.new).where((f) => f.existsSync()).firstOrNull;
    if (source == null) {
      final maxMB = (ImageUtils.maxFileSizeBytes / (1024 * 1024)).toStringAsFixed(0);
      ErrorUtils.showError(
        context,
        localizations?.imageCompressionFailed(maxMB) ??
            "Could not process image. Please choose an image smaller than ${maxMB}MB.",
      );
      return;
    }

    final cropped = await ImageCropScreen.show(context, source, aspectRatio: 4 / 3);
    if (cropped == null || !mounted) return;
    final result = await _processPhoto(cropped, localizations);
    if (!mounted) return;
    if (result.path == null) {
      ErrorUtils.showError(context, result.error);
      return;
    }
    if (!_photos.contains(photo)) return; // removed while cropping
    setState(() => photo.path = result.path!);
    _markChanged();
  }

  /// Removes at once (uploaded photos are deleted on save) and offers Undo
  /// for 4 seconds.
  void _removePhoto(int index) {
    if (_isSubmitting || index >= _photos.length) return;
    final photo = _photos[index];
    setState(() {
      _photos.removeAt(index);
      if (photo is _ExistingPhoto) _removedImageIds.add(photo.image.id);
    });
    _markChanged();

    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(localizations?.photoRemoved ?? "Photo removed"),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        // A snack bar with an action stays up by default.
        persist: false,
        action: SnackBarAction(
          label: localizations?.undo ?? "Undo",
          onPressed: () => _undoRemovePhoto(photo, index),
        ),
      ),
    );
  }

  void _undoRemovePhoto(_Photo photo, int index) {
    if (!mounted || _isSubmitting || _submitted || _photos.contains(photo)) return;
    if (_photos.length + _pendingPhotos >= _maxImages) {
      final localizations = AppLocalizations.of(context);
      ErrorUtils.showError(
        context,
        localizations?.photosSkippedLimit(1, _maxImages) ?? "1 photos weren't added — max $_maxImages",
      );
      return;
    }
    setState(() {
      _photos.insert(math.min(index, _photos.length), photo);
      if (photo is _ExistingPhoto) _removedImageIds.remove(photo.image.id);
    });
    _markChanged();
  }

  /// Moves the photo at [from] to index [to]; index 0 is the cover.
  void _reorderPhotos(int from, int to) {
    if (_isSubmitting || from == to) return;
    if (from < 0 || from >= _photos.length || to < 0 || to >= _photos.length) return;
    setState(() {
      final photo = _photos.removeAt(from);
      _photos.insert(to, photo);
    });
    _markChanged();
  }

  // ---------------------------------------------------------------------------
  // Validation and submit

  /// The submit validation rules, in order, each tagged with the section it
  /// belongs to.
  List<(_Section, String)> _collectErrors() {
    final localizations = AppLocalizations.of(context);
    final errors = <(_Section, String)>[];

    // Title is required
    if (_titleController.text.trim().isEmpty) {
      errors.add((_Section.basics, localizations?.recipeTitleRequired ?? "Recipe title is required"));
    }

    // At least one ingredient
    if (_ingredients.isEmpty) {
      errors.add((_Section.ingredients, localizations?.pleaseAddAtLeastOneIngredient ?? "Please add at least one ingredient"));
    } else {
      // Validate ingredient names
      for (var i = 0; i < _ingredients.length; i++) {
        if (_ingredients[i].nameController.text.trim().isEmpty) {
          errors.add((_Section.ingredients, localizations?.ingredientNameRequired(i) ?? "Ingredient ${i + 1}: name is required"));
        }
      }
    }

    // At least one step
    if (_steps.isEmpty) {
      errors.add((_Section.method, localizations?.pleaseAddAtLeastOneStep ?? "Please add at least one step"));
    } else {
      // Validate step instructions
      for (var i = 0; i < _steps.length; i++) {
        if (_steps[i].instructionController.text.trim().isEmpty) {
          errors.add((_Section.method, localizations?.stepInstructionRequired(i) ?? "Step ${i + 1}: instruction is required"));
        }
      }
    }

    // Validate cooking time
    final cookingTimeMinText = _cookingTimeMinController.text.trim();
    final cookingTimeMaxText = _cookingTimeMaxController.text.trim();

    if (cookingTimeMinText.isNotEmpty && int.tryParse(cookingTimeMinText) == null) {
      errors.add((_Section.details, localizations?.minCookingTimeMustBeValidNumber ?? "Minimum cooking time must be a valid number"));
    }
    if (cookingTimeMaxText.isNotEmpty && int.tryParse(cookingTimeMaxText) == null) {
      errors.add((_Section.details, localizations?.maxCookingTimeMustBeValidNumber ?? "Maximum cooking time must be a valid number"));
    }

    final cookingTimeMin = cookingTimeMinText.isEmpty ? null : int.tryParse(cookingTimeMinText);
    final cookingTimeMax = cookingTimeMaxText.isEmpty ? null : int.tryParse(cookingTimeMaxText);

    if (cookingTimeMin != null && cookingTimeMax != null && cookingTimeMin > cookingTimeMax) {
      errors.add((_Section.details, localizations?.minCookingTimeCannotBeGreater ?? "Minimum cooking time cannot be greater than maximum time"));
    }

    return errors;
  }

  Map<_Section, List<String>> _groupErrors(List<(_Section, String)> errors) {
    final grouped = <_Section, List<String>>{};
    for (final (section, message) in errors) {
      (grouped[section] ??= []).add(message);
    }
    return grouped;
  }

  /// Shows [errors] under their section headers, scrolls to the first such
  /// section and focuses its field.
  void _showErrors(List<(_Section, String)> errors) {
    final grouped = _groupErrors(errors);
    final first = _Section.values.firstWhere(grouped.containsKey);

    FocusNode? focus;
    _IngredientItem? expand;
    switch (first) {
      case _Section.basics:
        focus = _titleFocus;
      case _Section.details:
        focus = _maxTimeFocus;
      case _Section.ingredients:
        expand = _ingredients.where((i) => i.nameController.text.trim().isEmpty).firstOrNull;
        focus = expand?.nameFocusNode;
      case _Section.method:
        focus = _steps.where((s) => s.instructionController.text.trim().isEmpty).firstOrNull?.focusNode;
      case _Section.photos:
      case _Section.tags:
        break;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _sectionErrors = grouped;
      if (expand != null) _expandedIngredient = expand;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = _sectionKeys[first]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      if (mounted) focus?.requestFocus();
    });
  }

  Future<void> _submit() async {
    if (_pendingPhotos > 0) {
      // The photos still being processed would be left out.
      final localizations = AppLocalizations.of(context);
      ErrorUtils.showInfo(context, localizations?.processingPhotos ?? "Processing photos…");
      return;
    }

    final errors = _collectErrors();
    if (errors.isNotEmpty) {
      _showErrors(errors);
      return;
    }

    // A draft save finishing after the success path's clearDraft would bring
    // the published recipe back as a "Draft found".
    _draftTimer?.cancel();
    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _error = null;
      _sectionErrors = {};
    });

    try {
      final ingredients = _ingredients.map((ing) {
        final qty = ing.quantityController.text.trim();
        final unit = ing.unitController.text.trim();
        final name = ing.nameController.text.trim();

        // Build ingredient using camelCase format as expected by backend
        final parsedQty = qty.isNotEmpty ? double.tryParse(qty) : null;
        final ingredient = <String, dynamic>{
          "displayName": name, // Backend expects camelCase
        };

        // Add optional fields only if they have values
        if (parsedQty != null) {
          ingredient["quantity"] = parsedQty;
        }
        if (unit.isNotEmpty) {
          ingredient["unit"] = unit;
        }

        return ingredient;
      }).toList();

      final steps = _steps.map((step) => {
            "instruction": step.instructionController.text.trim(),
          }).toList();

      final api = RecipeApi(widget.apiClient);

      // Snapshot: the loops below await, and the grid stays interactive.
      final photos = List<_Photo>.of(_photos);
      final newPhotos = photos.whereType<_LocalPhoto>().toList();
      // Files to upload, in grid order.
      final imageFiles = [for (final p in newPhotos) File(p.path)];
      // Edit mode: the first photo upload that failed, if any.
      Object? uploadError;

      // Show upload status
      if (mounted && imageFiles.isNotEmpty) {
        setState(() {
          _uploadStatus = "Preparing upload...";
        });

        // Calculate total size for user feedback
        int totalSize = 0;
        for (final file in imageFiles) {
          totalSize += await file.length();
        }
        final sizeMB = (totalSize / 1024 / 1024).toStringAsFixed(2);

        if (mounted) {
          setState(() {
            _uploadStatus = _isEditMode
                ? "Updating recipe with ${imageFiles.length} new image(s) ($sizeMB MB)..."
                : "Uploading ${imageFiles.length} image(s) ($sizeMB MB)...";
          });
        }
      }

      if (_isEditMode && widget.recipeId != null) {
        // Update existing recipe using PATCH
        final cookingTimeMinText = _cookingTimeMinController.text.trim();
        final cookingTimeMaxText = _cookingTimeMaxController.text.trim();

        final cookingTimeMin =
            cookingTimeMinText.isEmpty ? null : int.tryParse(cookingTimeMinText);
        final cookingTimeMax =
            cookingTimeMaxText.isEmpty ? null : int.tryParse(cookingTimeMaxText);

        final servingSizeText = _servingSizeController.text.trim();
        final servingSize = servingSizeText.isEmpty ? null : int.tryParse(servingSizeText);

        await api.updateRecipe(
          recipeId: widget.recipeId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          cuisine: _cuisineController.text.trim().isEmpty
              ? null
              : _cuisineController.text.trim(),
          tags: _tags.isEmpty ? null : _tags,
          cookingTimeMin: cookingTimeMin,
          cookingTimeMax: cookingTimeMax,
          difficulty: _selectedDifficulty?.apiValue,
          servingSize: servingSize,
          ingredients: ingredients,
          steps: steps,
        );

        // Handle image updates via separate endpoints
        // Delete removed images
        for (final imageId in _removedImageIds) {
          try {
            await api.deleteRecipeImage(widget.recipeId!, imageId);
          } catch (e) {
            // Continue even if deletion fails for one image
          }
        }

        // Upload new photos in grid order. The server appends each one, so
        // a new photo that sits before an old one needs the reorder below.
        final uploadedIds = <_LocalPhoto, String>{};
        for (int i = 0; i < newPhotos.length; i++) {
          try {
            if (mounted) {
              setState(() {
                _uploadStatus = "Uploading image ${i + 1} of ${newPhotos.length}...";
              });
            }
            uploadedIds[newPhotos[i]] = await api.addRecipeImage(widget.recipeId!, imageFiles[i]);
          } catch (e) {
            // Continue even if one image upload fails
            uploadError ??= e;
          }
        }

        // The grid order, minus any photo that failed to upload.
        final finalOrder = <String>[
          for (final p in photos)
            if (p is _ExistingPhoto) p.image.id else if (uploadedIds[p] != null) uploadedIds[p]!,
        ];
        // The server's order now: kept photos in their old order, then the
        // uploads as appended.
        final keptIds = {for (final p in photos) if (p is _ExistingPhoto) p.image.id};
        final serverOrder = [
          for (final img in widget.recipe!.images)
            if (keptIds.contains(img.id)) img.id,
          for (final p in newPhotos)
            if (uploadedIds[p] != null) uploadedIds[p]!,
        ];
        if (finalOrder.isNotEmpty && !listEquals(finalOrder, serverOrder)) {
          try {
            await api.reorderRecipeImages(widget.recipeId!, finalOrder);
          } catch (e) {
            // Ignore reorder errors
          }
        }
      } else {
        // Create new recipe
        final cookingTimeMinText = _cookingTimeMinController.text.trim();
        final cookingTimeMaxText = _cookingTimeMaxController.text.trim();
        final servingSizeText = _servingSizeController.text.trim();

        final cookingTimeMin =
            cookingTimeMinText.isEmpty ? null : int.tryParse(cookingTimeMinText);
        final cookingTimeMax =
            cookingTimeMaxText.isEmpty ? null : int.tryParse(cookingTimeMaxText);
        final servingSize =
            servingSizeText.isEmpty ? null : int.tryParse(servingSizeText);

        await api.createRecipe(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          cuisine: _cuisineController.text.trim().isEmpty
              ? null
              : _cuisineController.text.trim(),
          tags: _tags,
          cookingTimeMin: cookingTimeMin,
          cookingTimeMax: cookingTimeMax,
          difficulty: _selectedDifficulty?.apiValue,
          servingSize: servingSize,
          ingredients: ingredients,
          steps: steps,
          images: imageFiles.isEmpty ? null : imageFiles,
        );
      }

      _submitted = true;
      if (!_isEditMode) {
        await _draftService.clearDraft();
      }
      if (mounted) {
        setState(() {
          _uploadStatus = null;
          _isSubmitting = false;
        });
        final localizations = AppLocalizations.of(context);
        if (uploadError != null) {
          // The recipe itself was saved, so leave anyway (staying would
          // upload the photos that did go through a second time), but say
          // why a photo is missing.
          ErrorUtils.showError(context, uploadError);
        } else {
          ErrorUtils.showSuccess(
            context,
            _isEditMode
                ? (localizations?.recipeUpdatedSuccessfully ??
                    "Recipe updated successfully")
                : (localizations?.recipeCreatedSuccessfully ??
                    "Recipe created successfully"),
          );
        }
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorUtils.getUserFriendlyMessage(e, context);
          _isSubmitting = false;
          _uploadStatus = null;
        });
      }
    }
  }

  void _validateCookingTime() {
    final localizations = AppLocalizations.of(context);
    final min = _cookingTimeMinController.text.trim().isEmpty
        ? null
        : int.tryParse(_cookingTimeMinController.text.trim());
    final max = _cookingTimeMaxController.text.trim().isEmpty
        ? null
        : int.tryParse(_cookingTimeMaxController.text.trim());

    setState(() {
      if (min != null && max != null && min > max) {
        _cookingTimeError = localizations?.minTimeCannotBeGreater ??
            "Min time cannot exceed max time";
      } else {
        _cookingTimeError = null;
      }
    });
  }

  /// When the minimum time ends up above the maximum, raise the maximum.
  void _onMinTimeCommitted() {
    final min = int.tryParse(_cookingTimeMinController.text.trim());
    final max = int.tryParse(_cookingTimeMaxController.text.trim());
    if (min != null && max != null && min > max) {
      _cookingTimeMaxController.text = "$min";
      _validateCookingTime();
    }
  }

  // ---------------------------------------------------------------------------
  // Preview

  String _primaryLabel(AppLocalizations? l) =>
      _isEditMode ? (l?.saveChanges ?? "Save Changes") : (l?.publish ?? "Publish");

  Future<RecipePreviewAuthor?> _loadPreviewAuthor() async {
    final recipe = widget.recipe;
    if (_isEditMode && recipe != null) {
      return RecipePreviewAuthor(
        name: recipe.authorDisplayName ?? recipe.authorUsername,
        avatarUrl: recipe.authorAvatarUrl,
      );
    }
    try {
      final me = await AuthApi(widget.apiClient).me();
      if (me == null) return null;
      final display = me["display_name"]?.toString();
      final username = me["username"]?.toString() ?? "";
      return RecipePreviewAuthor(
        name: display != null && display.isNotEmpty && display != "null" ? display : username,
        avatarUrl: me["avatar_url"]?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  RecipePreviewData _previewData() {
    return RecipePreviewData(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      cuisine: _cuisineController.text.trim(),
      tags: List.of(_tags),
      cookingTimeMin: int.tryParse(_cookingTimeMinController.text.trim()),
      cookingTimeMax: int.tryParse(_cookingTimeMaxController.text.trim()),
      servings: int.tryParse(_servingSizeController.text.trim()),
      difficulty: _selectedDifficulty,
      ingredients: [
        for (final i in _ingredients)
          if (i.nameController.text.trim().isNotEmpty)
            RecipePreviewIngredient(
              amount: ingredientAmountLabel(i.quantityController.text, i.unitController.text),
              name: i.nameController.text.trim(),
            ),
      ],
      steps: [
        for (final s in _steps)
          if (s.instructionController.text.trim().isNotEmpty) s.instructionController.text.trim(),
      ],
      images: [
        for (final photo in _photos)
          switch (photo) {
            _ExistingPhoto(:final image) => RecipePreviewImage.url(image.url),
            _LocalPhoto(:final path) => RecipePreviewImage.file(path),
          },
      ],
    );
  }

  Future<void> _openPreview() async {
    FocusScope.of(context).unfocus();
    final l = AppLocalizations.of(context);
    _previewAuthor ??= _loadPreviewAuthor();
    final publish = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipePreviewScreen(
          data: _previewData(),
          primaryLabel: _primaryLabel(l),
          author: _previewAuthor!,
        ),
      ),
    );
    // The preview only asks; _submit pops this screen on success, so it has
    // to run once the preview is gone.
    if (publish == true && mounted && !_isSubmitting) await _submit();
  }

  // ---------------------------------------------------------------------------
  // Build

  bool get _titleDone => _titleController.text.trim().isNotEmpty;

  bool get _ingredientsDone =>
      _ingredients.isNotEmpty && _ingredients.every((i) => i.nameController.text.trim().isNotEmpty);

  bool get _stepsDone =>
      _steps.isNotEmpty && _steps.every((s) => s.instructionController.text.trim().isNotEmpty);

  bool get _detailsDone =>
      _cookingTimeMinController.text.trim().isNotEmpty ||
      _cookingTimeMaxController.text.trim().isNotEmpty ||
      _servingSizeController.text.trim().isNotEmpty ||
      _selectedDifficulty != null ||
      _cuisineController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildTopBar(t, l),
          Expanded(
            child: GestureDetector(
              // A tap on empty space ends editing and collapses the open
              // ingredient row; taps on fields and buttons don't reach here.
              behavior: HitTestBehavior.translucent,
              onTap: () {
                FocusScope.of(context).unfocus();
                if (_expandedIngredient != null) setState(() => _expandedIngredient = null);
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                // Held still while a photo is dragged in the grid.
                physics: _photoDragActive ? const NeverScrollableScrollPhysics() : null,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPhotosSection(l),
                    const SizedBox(height: 24),
                    _buildBasicsSection(t, l),
                    const SizedBox(height: 24),
                    _buildDetailsSection(t, l),
                    const SizedBox(height: 24),
                    _buildTagsSection(t, l),
                    const SizedBox(height: 24),
                    _buildIngredientsSection(t, l),
                    const SizedBox(height: 24),
                    _buildMethodSection(l),
                  ],
                ),
              ),
            ),
          ),
          CreateRecipeBottomBar(
            requiredDone: [_titleDone, _ingredientsDone, _stepsDone],
            primaryLabel: _primaryLabel(l),
            onPrimary: _submit,
            onPreview: _openPreview,
            isSubmitting: _isSubmitting,
            keyboardOpen: keyboardOpen,
            uploadStatus: _uploadStatus,
            error: _error,
            onDismissError: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(AppTokens t, AppLocalizations? l) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: Icon(Icons.close_rounded, color: t.ink),
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _isEditMode
                  ? (l?.editRecipe ?? "Edit Recipe")
                  : (l?.createRecipe ?? "Create Recipe"),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.ink),
            ),
          ),
          if (!_isEditMode && _draftSaved)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                "✓ ${l?.draftSaved ?? "Draft saved"}",
                style: TextStyle(fontSize: 12, color: t.ink2),
              ),
            ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  /// Header (+ any validation messages) above a section's body.
  Widget _section({
    required _Section section,
    required String title,
    required bool complete,
    String? caption,
    required Widget child,
  }) {
    final errors = _sectionErrors[section];
    return Column(
      key: _sectionKeys[section],
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSectionHeader(
          number: section.index + 1,
          title: title,
          complete: complete,
          caption: caption,
        ),
        if (errors != null && errors.isNotEmpty) FormSectionErrors(messages: errors),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildPhotosSection(AppLocalizations? l) {
    final count = _imageCount;
    return _section(
      section: _Section.photos,
      title: l?.sectionPhotos ?? "Photos",
      complete: count > 0,
      caption: count > 0
          ? (l?.photoCount(count, _maxImages) ?? "$count / $_maxImages")
          : (l?.optional ?? "Optional"),
      child: PhotosSection(
        photos: [
          for (final photo in _photos)
            PhotoGridItem(
              id: photo,
              canCrop: photo is _LocalPhoto,
              image: switch (photo) {
                // Width only: setting both cache dimensions squashes
                // non-square photos.
                _ExistingPhoto(:final image) => RecipeImageWidget(
                    key: ValueKey(image.id),
                    imageUrl: image.url,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    cacheWidth: 600,
                    placeholderSize: 24,
                  ),
                // Keyed by path, so a re-crop shows the new file.
                _LocalPhoto(:final path) => Image.file(
                    File(path),
                    key: ValueKey(path),
                    fit: BoxFit.cover,
                    cacheWidth: 600,
                  ),
              },
            ),
        ],
        pendingCount: _pendingPhotos,
        // Hidden while a pick is still being processed.
        canAdd: _pendingPhotos == 0 && count < _maxImages,
        onAdd: _pickImages,
        onRemove: _removePhoto,
        onCrop: _cropPhoto,
        onReorder: _reorderPhotos,
        onDragActiveChanged: (active) => setState(() => _photoDragActive = active),
      ),
    );
  }

  Widget _buildBasicsSection(AppTokens t, AppLocalizations? l) {
    return _section(
      section: _Section.basics,
      title: l?.sectionBasics ?? "Basics",
      complete: _titleDone,
      child: FormSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormFieldLabel(l?.title ?? "Title", required: true),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              focusNode: _titleFocus,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              style: tokenFieldStyle(t),
              decoration: tokenInputDecoration(t, hint: l?.titleHint ?? "e.g. Adjarian khachapuri"),
            ),
            const SizedBox(height: 16),
            FormFieldLabel(l?.description ?? "Description"),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: tokenFieldStyle(t),
              decoration: tokenInputDecoration(
                t,
                hint: l?.descriptionHint ?? "What makes this dish special?",
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection(AppTokens t, AppLocalizations? l) {
    final error = Theme.of(context).colorScheme.error;
    final timeLabel = l?.cookingTime ?? "Cooking time";
    final minLabel = l?.minHint ?? "min";
    final maxLabel = l?.maxHint ?? "max";
    final servingsLabel = l?.servingSize ?? "Servings";
    final showTimeError = _cookingTimeError != null && _sectionErrors[_Section.details] == null;

    return _section(
      section: _Section.details,
      title: l?.sectionDetails ?? "Details",
      complete: _detailsDone,
      caption: l?.optional ?? "Optional",
      child: FormSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Time range
            FormFieldLabel(timeLabel, caption: l?.minutesShort ?? "min"),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: NumberStepper(
                    controller: _cookingTimeMinController,
                    step: 5,
                    placeholder: minLabel,
                    fieldName: "$timeLabel ($minLabel)",
                    onChanged: _validateCookingTime,
                    onCommit: _onMinTimeCommitted,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text("–", style: TextStyle(fontSize: 16, color: t.ink2)),
                ),
                Expanded(
                  child: NumberStepper(
                    controller: _cookingTimeMaxController,
                    focusNode: _maxTimeFocus,
                    step: 5,
                    placeholder: maxLabel,
                    fieldName: "$timeLabel ($maxLabel)",
                    // Start from the minimum so + doesn't land below it.
                    emptyStart: () => math.max(5, int.tryParse(_cookingTimeMinController.text.trim()) ?? 0),
                    onChanged: _validateCookingTime,
                  ),
                ),
              ],
            ),
            if (showTimeError) ...[
              const SizedBox(height: 6),
              Text(_cookingTimeError!, style: TextStyle(fontSize: 13, color: error)),
            ],
            const SizedBox(height: 18),

            // Servings
            Row(
              children: [
                Expanded(
                  child: Text(
                    servingsLabel,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: NumberStepper(
                    controller: _servingSizeController,
                    step: 1,
                    placeholder: "–",
                    fieldName: servingsLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Difficulty
            FormFieldLabel(l?.difficulty ?? "Difficulty"),
            const SizedBox(height: 8),
            Row(
              children: [
                _difficultyButton(t, label: l?.easy ?? "Easy", value: Difficulty.easy, dots: 1),
                const SizedBox(width: 8),
                _difficultyButton(t, label: l?.medium ?? "Medium", value: Difficulty.medium, dots: 2),
                const SizedBox(width: 8),
                _difficultyButton(t, label: l?.hard ?? "Hard", value: Difficulty.hard, dots: 3),
              ],
            ),
            const SizedBox(height: 18),

            // Cuisine
            FormFieldLabel(l?.cuisine ?? "Cuisine"),
            const SizedBox(height: 8),
            TextField(
              controller: _cuisineController,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              style: tokenFieldStyle(t),
              decoration: tokenInputDecoration(t, hint: l?.cuisineExample ?? "e.g., Italian, Mexican"),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final option in cuisineOptions)
                  Builder(builder: (context) {
                    final label = option.getLabel(l);
                    final isSelected = _cuisineController.text == label;
                    return TokenChip(
                      label: label,
                      selected: isSelected,
                      height: 34,
                      onTap: () => _cuisineController.text = isSelected ? '' : label,
                    );
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _difficultyButton(
    AppTokens t, {
    required String label,
    required Difficulty value,
    required int dots,
  }) {
    final isSelected = _selectedDifficulty == value;
    final color = isSelected ? t.brandInk : t.ink2;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _selectedDifficulty = isSelected ? null : value;
            });
            _markChanged();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? t.soft : t.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? t.brand : t.line,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < dots ? color : Colors.transparent,
                          border: Border.all(color: color, width: 1.2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagsSection(AppTokens t, AppLocalizations? l) {
    final addChip = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DashedBox(
        onTap: _openTagSheet,
        radius: 18,
        semanticLabel: l?.addTag ?? "Add a tag",
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: t.brandInk),
              const SizedBox(width: 4),
              Text(
                l?.addTagChip ?? "Tag",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.brandInk),
              ),
            ],
          ),
        ),
      ),
    );

    return _section(
      section: _Section.tags,
      title: l?.tags ?? "Tags",
      complete: _tags.isNotEmpty,
      caption: l?.optional ?? "Optional",
      child: FormSectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tag in _tags) RemovableTagChip(label: tag, onRemove: () => _removeTag(tag)),
            addChip,
            if (_tags.isEmpty)
              Text(
                l?.tagsHint ?? "Category, diet or your own",
                style: TextStyle(fontSize: 13, color: t.ink2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsSection(AppTokens t, AppLocalizations? l) {
    return _section(
      section: _Section.ingredients,
      title: l?.ingredients ?? "Ingredients",
      complete: _ingredientsDone,
      caption: _ingredients.isNotEmpty
          ? (l?.nIngredients(_ingredients.length) ?? "${_ingredients.length} ingredients")
          : null,
      child: FormSectionCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_ingredients.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                buildDefaultDragHandles: false,
                itemCount: _ingredients.length,
                onReorderItem: _reorderIngredients,
                proxyDecorator: (child, index, animation) => _dragProxy(t, child, animation),
                itemBuilder: (context, index) {
                  final item = _ingredients[index];
                  return IngredientRow(
                    key: ObjectKey(item),
                    index: index,
                    nameController: item.nameController,
                    quantityController: item.quantityController,
                    unitController: item.unitController,
                    nameFocusNode: item.nameFocusNode,
                    expanded: _expandedIngredient == item,
                    showDivider: index < _ingredients.length - 1,
                    onExpand: () => _expandIngredient(item),
                    onCollapse: () => _collapseIngredient(item),
                    onRemove: () => _removeIngredient(_ingredients.indexOf(item)),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: DashedAddButton(
                label: l?.addIngredient ?? "Add ingredient",
                onTap: _addIngredient,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodSection(AppLocalizations? l) {
    final t = AppTokens.of(context);
    return _section(
      section: _Section.method,
      title: l?.sectionMethod ?? "Method",
      complete: _stepsDone,
      caption: _steps.isNotEmpty ? (l?.nSteps(_steps.length) ?? "${_steps.length} steps") : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_steps.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              buildDefaultDragHandles: false,
              itemCount: _steps.length,
              onReorderItem: _reorderSteps,
              proxyDecorator: (child, index, animation) => _dragProxy(t, child, animation),
              itemBuilder: (context, index) {
                final step = _steps[index];
                return StepCard(
                  key: ObjectKey(step),
                  index: index,
                  controller: step.instructionController,
                  focusNode: step.focusNode,
                  onRemove: () => _removeStep(_steps.indexOf(step)),
                );
              },
            ),
          DashedAddButton(label: l?.addStep ?? "Add step", onTap: _addStep),
        ],
      ),
    );
  }

  Widget _dragProxy(AppTokens t, Widget child, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final elevation = lerpDouble(0, 6, Curves.easeInOut.transform(animation.value))!;
        return Material(
          elevation: elevation,
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          child: child,
        );
      },
      child: child,
    );
  }
}

/// One photo in the form's grid: uploaded (edit mode) or picked here.
sealed class _Photo {}

final class _ExistingPhoto extends _Photo {
  _ExistingPhoto(this.image);

  final RecipeImage image;
}

final class _LocalPhoto extends _Photo {
  _LocalPhoto({required this.path, required this.sourcePath});

  /// The file that gets uploaded: compressed, and cropped if the user did.
  String path;

  /// The original pick, so each crop starts from the full image.
  final String sourcePath;
}

class _IngredientItem {
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final FocusNode nameFocusNode = FocusNode();
}

class _StepItem {
  final TextEditingController instructionController = TextEditingController();
  final FocusNode focusNode = FocusNode();
}
