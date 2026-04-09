import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";

import "../api/api_client.dart";
import "../constants/cuisines.dart";
import "../constants/dietary_preferences.dart";
import "../constants/enums.dart";
import "../constants/recipe_categories.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_api.dart";
import "../recipes/recipe_detail_models.dart";
import "../services/recipe_draft_service.dart";
import "../utils/error_utils.dart";
import "../utils/image_utils.dart";
import "../utils/ui_utils.dart";

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

class _CreateRecipeScreenState extends State<CreateRecipeScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cuisineController = TextEditingController();
  final _tagController = TextEditingController();
  final _cookingTimeMinController = TextEditingController();
  final _cookingTimeMaxController = TextEditingController();
  final _scrollController = ScrollController();

  final List<String> _tags = [];
  final List<_IngredientItem> _ingredients = [];
  final List<_StepItem> _steps = [];
  final List<XFile> _selectedImages = [];
  final List<RecipeImage> _existingImages = []; // Existing images from recipe
  final Set<String> _removedImageIds = {}; // Track removed existing images
  final ImagePicker _imagePicker = ImagePicker();

  Difficulty? _selectedDifficulty;
  String? _cookingTimeError;

  bool _isSubmitting = false;
  bool _submitted = false;
  String? _error;
  String? _uploadStatus; // For showing upload progress
  bool _isEditMode = false;

  final _draftService = RecipeDraftService();


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
  }

  void _loadRecipeData(RecipeDetail recipe) {
    _titleController.text = recipe.title;
    _descriptionController.text = recipe.description ?? "";
    _cuisineController.text = recipe.cuisine ?? "";
    _tags.addAll(recipe.tags);
    _existingImages.addAll(recipe.images);
    _cookingTimeMinController.text = recipe.cookingTimeMin?.toString() ?? "";
    _cookingTimeMaxController.text = recipe.cookingTimeMax?.toString() ?? "";
    _selectedDifficulty = DifficultyApi.fromApiValue(recipe.difficulty);

    // Load ingredients
    for (final ing in recipe.ingredients) {
      final item = _IngredientItem();
      item.quantityController.text = ing.quantity?.toString() ?? "";
      item.unitController.text = ing.unit ?? "";
      item.nameController.text = ing.displayName;
      _ingredients.add(item);
    }

    // Load steps
    for (final step in recipe.steps) {
      final item = _StepItem();
      item.instructionController.text = step.instruction;
      _steps.add(item);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_isEditMode && !_submitted && _hasMeaningfulData()) {
      _saveDraft();
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _cuisineController.dispose();
    _tagController.dispose();
    _cookingTimeMinController.dispose();
    _cookingTimeMaxController.dispose();
    _scrollController.dispose();
    for (var ing in _ingredients) {
      ing.quantityController.dispose();
      ing.unitController.dispose();
      ing.nameController.dispose();
      ing.nameFocusNode.dispose();
    }
    for (var step in _steps) {
      step.instructionController.dispose();
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
        _selectedImages.isNotEmpty;
  }

  void _saveDraft() {
    _draftService.saveDraft(
      title: _titleController.text,
      description: _descriptionController.text,
      cuisine: _cuisineController.text,
      tags: List.from(_tags),
      cookingTimeMin: _cookingTimeMinController.text,
      cookingTimeMax: _cookingTimeMaxController.text,
      difficulty: _selectedDifficulty?.apiValue,
      ingredients: _ingredients
          .map((i) => {
                'quantity': i.quantityController.text,
                'unit': i.unitController.text,
                'name': i.nameController.text,
              })
          .toList(),
      steps: _steps.map((s) => s.instructionController.text).toList(),
      imagePaths: _selectedImages.map((f) => f.path).toList(),
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

    setState(() {
      _titleController.text = (draft['title'] as String?) ?? '';
      _descriptionController.text = (draft['description'] as String?) ?? '';
      _cuisineController.text = (draft['cuisine'] as String?) ?? '';
      _cookingTimeMinController.text =
          (draft['cookingTimeMin'] as String?) ?? '';
      _cookingTimeMaxController.text =
          (draft['cookingTimeMax'] as String?) ?? '';
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
        _ingredients.add(item);
      }

      final steps = (draft['steps'] as List<dynamic>?) ?? [];
      for (final step in steps) {
        final item = _StepItem();
        item.instructionController.text = (step as String?) ?? '';
        _steps.add(item);
      }

      final imagePaths = (draft['imagePaths'] as List<dynamic>?) ?? [];
      for (final path in imagePaths) {
        final p = path as String;
        if (File(p).existsSync()) {
          _selectedImages.add(XFile(p));
        }
      }
    });
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _addIngredient() {
    final newItem = _IngredientItem();
    setState(() {
      _ingredients.add(newItem);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      newItem.nameFocusNode.requestFocus();
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients[index].quantityController.dispose();
      _ingredients[index].unitController.dispose();
      _ingredients[index].nameController.dispose();
      _ingredients[index].nameFocusNode.dispose();
      _ingredients.removeAt(index);
    });
  }

  void _reorderIngredients(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _ingredients.removeAt(oldIndex);
      _ingredients.insert(newIndex, item);
    });
  }

  void _addStep() {
    setState(() {
      _steps.add(_StepItem());
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps[index].instructionController.dispose();
      _steps.removeAt(index);
    });
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, item);
    });
  }

  Future<void> _pickImage() async {
    final localizations = AppLocalizations.of(context);
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        // Check original file size before processing
        final originalSize = await File(image.path).length();
        final originalSizeMB = originalSize / (1024 * 1024);

        // Show processing indicator for large files
        if (originalSizeMB > 2) {
          setState(() {
            _uploadStatus =
                localizations?.processingImage ?? "Processing image...";
          });
        }

        // Compress and resize the image using shared utility
        final result = await ImageUtils.compressImage(File(image.path));

        setState(() {
          _uploadStatus = null;
        });

        if (result != null) {
          final compressedSize = await result.length();

          // Validate file size after compression
          if (compressedSize > ImageUtils.maxFileSizeBytes) {
            final sizeMB = (compressedSize / (1024 * 1024)).toStringAsFixed(1);
            final maxMB = (ImageUtils.maxFileSizeBytes / (1024 * 1024)).toStringAsFixed(0);
            if (mounted) {
              ErrorUtils.showError(
                context,
                localizations?.imageTooLarge(sizeMB, maxMB) ??
                    "Image is too large (${sizeMB}MB). Maximum size is ${maxMB}MB. Please choose a smaller image.",
              );
            }
            return;
          }

          setState(() {
            _selectedImages.add(XFile(result.path));
          });
        } else {
          // If compression fails, check if original is within size limit
          if (originalSize <= ImageUtils.maxFileSizeBytes) {
            setState(() {
              _selectedImages.add(image);
            });
          } else {
            if (mounted) {
              final maxMB = (ImageUtils.maxFileSizeBytes / (1024 * 1024)).toStringAsFixed(0);
              ErrorUtils.showError(
                context,
                localizations?.imageCompressionFailed(maxMB) ??
                    "Could not process image. Please choose an image smaller than ${maxMB}MB.",
              );
            }
          }
        }
      }
    } catch (e) {
      setState(() {
        _uploadStatus = null;
      });
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      final removedImage = _existingImages.removeAt(index);
      _removedImageIds.add(removedImage.id);
    });
  }

  Future<void> _submit() async {
    final localizations = AppLocalizations.of(context);
    final errors = <String>[];

    // Title is required
    if (_titleController.text.trim().isEmpty) {
      errors.add(localizations?.recipeTitleRequired ?? "Recipe title is required");
    }

    // At least one ingredient
    if (_ingredients.isEmpty) {
      errors.add(localizations?.pleaseAddAtLeastOneIngredient ?? "Please add at least one ingredient");
    } else {
      // Validate ingredient names
      for (var i = 0; i < _ingredients.length; i++) {
        if (_ingredients[i].nameController.text.trim().isEmpty) {
          errors.add(localizations?.ingredientNameRequired(i) ?? "Ingredient ${i + 1}: name is required");
        }
      }
    }

    // At least one step
    if (_steps.isEmpty) {
      errors.add(localizations?.pleaseAddAtLeastOneStep ?? "Please add at least one step");
    } else {
      // Validate step instructions
      for (var i = 0; i < _steps.length; i++) {
        if (_steps[i].instructionController.text.trim().isEmpty) {
          errors.add(localizations?.stepInstructionRequired(i) ?? "Step ${i + 1}: instruction is required");
        }
      }
    }

    // Validate cooking time
    final cookingTimeMinText = _cookingTimeMinController.text.trim();
    final cookingTimeMaxText = _cookingTimeMaxController.text.trim();

    if (cookingTimeMinText.isNotEmpty && int.tryParse(cookingTimeMinText) == null) {
      errors.add(localizations?.minCookingTimeMustBeValidNumber ?? "Minimum cooking time must be a valid number");
    }
    if (cookingTimeMaxText.isNotEmpty && int.tryParse(cookingTimeMaxText) == null) {
      errors.add(localizations?.maxCookingTimeMustBeValidNumber ?? "Maximum cooking time must be a valid number");
    }

    final cookingTimeMin = cookingTimeMinText.isEmpty ? null : int.tryParse(cookingTimeMinText);
    final cookingTimeMax = cookingTimeMaxText.isEmpty ? null : int.tryParse(cookingTimeMaxText);

    if (cookingTimeMin != null && cookingTimeMax != null && cookingTimeMin > cookingTimeMax) {
      errors.add(localizations?.minCookingTimeCannotBeGreater ?? "Minimum cooking time cannot be greater than maximum time");
    }

    // Trigger inline form field validation for visual feedback
    _formKey.currentState!.validate();

    // Show the first error via snackbar
    if (errors.isNotEmpty) {
      ErrorUtils.showSnackBar(
        context,
        errors.first,
        icon: Icons.error_outline,
        backgroundColor: Theme.of(context).colorScheme.error,
        iconColor: Colors.white,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
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

      // Convert XFile to File for upload
      final imageFiles =
          _selectedImages.map((xfile) => File(xfile.path)).toList();

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

        // Add new images
        for (int i = 0; i < imageFiles.length; i++) {
          try {
            if (mounted) {
              setState(() {
                _uploadStatus = "Uploading image ${i + 1} of ${imageFiles.length}...";
              });
            }
            await api.addRecipeImage(widget.recipeId!, imageFiles[i]);
          } catch (e) {
            // Continue even if one image upload fails
          }
        }

        // Reorder images if needed (existing images are already in the correct order)
        // The new images will be appended, so we only need to reorder if user changed order
        final allImageIds = _existingImages.map((img) => img.id).toList();
        if (allImageIds.isNotEmpty) {
          try {
            await api.reorderRecipeImages(widget.recipeId!, allImageIds);
          } catch (e) {
            // Ignore reorder errors
          }
        }
      } else {
        // Create new recipe
        final cookingTimeMinText = _cookingTimeMinController.text.trim();
        final cookingTimeMaxText = _cookingTimeMaxController.text.trim();

        final cookingTimeMin =
            cookingTimeMinText.isEmpty ? null : int.tryParse(cookingTimeMinText);
        final cookingTimeMax =
            cookingTimeMaxText.isEmpty ? null : int.tryParse(cookingTimeMaxText);

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
        ErrorUtils.showSuccess(
          context,
          _isEditMode
              ? (localizations?.recipeUpdatedSuccessfully ??
                  "Recipe updated successfully")
              : (localizations?.recipeCreatedSuccessfully ??
                  "Recipe created successfully"),
        );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Modern App Bar with Hero Image
            _buildSliverAppBar(context, theme, localizations),

            // Main Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 24),

                  // Basic Info Section
                  _buildBasicInfoSection(context, theme, localizations),

                  const SizedBox(height: 24),

                  // Cooking Details Section
                  _buildCookingDetailsSection(context, theme, localizations),

                  const SizedBox(height: 24),

                  // Tags Section
                  _buildTagsSection(context, theme, localizations),

                  const SizedBox(height: 24),

                  // Ingredients Section
                  _buildIngredientsSection(context, theme, localizations),

                  const SizedBox(height: 24),

                  // Steps Section
                  _buildStepsSection(context, theme, localizations),

                  const SizedBox(height: 32),

                  // Error message
                  if (_error != null) _buildErrorMessage(context, theme),

                  // Upload status message
                  if (_uploadStatus != null) _buildUploadStatus(context, theme),

                  // Submit button
                  _buildSubmitButton(context, theme, localizations),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(
      BuildContext context, ThemeData theme, AppLocalizations? localizations) {
    final hasImages = _existingImages.isNotEmpty || _selectedImages.isNotEmpty;

    return SliverAppBar(
      expandedHeight: hasImages ? 280 : 320,
      pinned: true,
      stretch: true,
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: _buildHeroImageSection(context, theme, localizations),
        collapseMode: CollapseMode.pin,
      ),
      title: Text(
        _isEditMode
            ? (localizations?.editRecipe ?? "Edit Recipe")
            : (localizations?.createRecipeTitle ?? "Create Recipe"),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildHeroImageSection(
      BuildContext context, ThemeData theme, AppLocalizations? localizations) {
    final hasImages = _existingImages.isNotEmpty || _selectedImages.isNotEmpty;

    return Container(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          child: hasImages
              ? _buildImageGallery(context, theme, localizations)
              : _buildEmptyImageUpload(context, theme, localizations),
        ),
      ),
    );
  }

  Widget _buildEmptyImageUpload(
      BuildContext context, ThemeData theme, AppLocalizations? localizations) {
    return GestureDetector(
      onTap: _pickImage,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
          borderRadius: 20,
          dashWidth: 8,
          dashSpace: 6,
          strokeWidth: 1.5,
        ),
        child: Container(
          height: 240,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  localizations?.addCoverPhoto ?? "Add cover photo",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  localizations?.tapToUpload ?? "Tap to upload",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGallery(
      BuildContext context, ThemeData theme, AppLocalizations? localizations) {
    final allImages = <Widget>[];

    // Add existing images
    for (var i = 0; i < _existingImages.length; i++) {
      allImages.add(_buildImageTile(
        context,
        theme,
        child: RecipeImageWidget(
          imageUrl: _existingImages[i].url,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          cacheWidth: 400,
          cacheHeight: 400,
          placeholderSize: 24,
        ),
        onRemove: () => _removeExistingImage(i),
        isFirst: i == 0 && _selectedImages.isEmpty,
      ));
    }

    // Add new images
    for (var i = 0; i < _selectedImages.length; i++) {
      allImages.add(_buildImageTile(
        context,
        theme,
        child: Image.file(
          File(_selectedImages[i].path),
          fit: BoxFit.cover,
        ),
        onRemove: () => _removeImage(i),
        isFirst: i == 0 && _existingImages.isEmpty,
      ));
    }

    // Add "add more" button
    allImages.add(_buildAddMoreImageTile(context, theme));

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: allImages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => allImages[index],
      ),
    );
  }

  Widget _buildImageTile(
    BuildContext context,
    ThemeData theme, {
    required Widget child,
    required VoidCallback onRemove,
    required bool isFirst,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: isFirst ? 180 : 120,
            height: 140,
            child: child,
          ),
        ),
        // Cover badge for first image
        if (isFirst)
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Cover",
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        // Remove button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddMoreImageTile(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 100,
        height: 140,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              size: 32,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              "Add",
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (action != null) action,
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(
      BuildContext context, ThemeData theme, AppLocalizations? localizations) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title label
        Text(
          (localizations?.title ?? "Recipe Title").toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        _buildLabeledTextField(
          controller: _titleController,
          hint: localizations?.enterRecipeTitle ?? "e.g. Grandma's Sicilian Caponata",
          theme: theme,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return localizations?.recipeTitleRequired ?? "Recipe title is required";
            }
            return null;
          },
        ),
        const SizedBox(height: 20),

        // Description label
        Text(
          (localizations?.description ?? "Description").toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        _buildLabeledTextField(
          controller: _descriptionController,
          hint: localizations?.describeYourRecipe ?? "Share the story behind this dish...",
          theme: theme,
          maxLines: 4,
        ),
      ],
      ),
    );
  }

  Widget _buildLabeledTextField({
    required TextEditingController controller,
    required String hint,
    required ThemeData theme,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.colorScheme.error,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildCookingDetailsSection(
      BuildContext context, ThemeData theme, AppLocalizations? localizations) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cuisine label
        Text(
          (localizations?.cuisine ?? "Cuisine").toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),

        // Cuisine text input
        _buildLabeledTextField(
          controller: _cuisineController,
          hint: localizations?.cuisineExample ?? 'e.g., Italian, Mexican',
          theme: theme,
        ),
        const SizedBox(height: 10),

        // Cuisine chips (scrollable)
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cuisineOptions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final option = cuisineOptions[index];
              final label = option.getLabel(localizations);
              final isSelected = _cuisineController.text == label;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _cuisineController.text = isSelected ? '' : label;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 24),

        // Prep time
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (localizations?.minTimeMinutes ?? "Prep Time (min)").toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _cookingTimeMinController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    onChanged: (_) => _validateCookingTime(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: '20',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (localizations?.maxTimeMinutes ?? "Max Time (min)").toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _cookingTimeMaxController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    onChanged: (_) => _validateCookingTime(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: '45',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_cookingTimeError != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 16, color: theme.colorScheme.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _cookingTimeError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),

        // Difficulty label
        Text(
          (localizations?.difficulty ?? "Difficulty Level").toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildDifficultyChip(
              theme,
              label: localizations?.easy ?? "Easy",
              value: Difficulty.easy,
              triangleCount: 1,
            ),
            const SizedBox(width: 10),
            _buildDifficultyChip(
              theme,
              label: localizations?.medium ?? "Medium",
              value: Difficulty.medium,
              triangleCount: 2,
            ),
            const SizedBox(width: 10),
            _buildDifficultyChip(
              theme,
              label: localizations?.hard ?? "Hard",
              value: Difficulty.hard,
              triangleCount: 3,
            ),
          ],
        ),
      ],
      ),
    );
  }

  Widget _buildDifficultyChip(
    ThemeData theme, {
    required String label,
    required Difficulty value,
    required int triangleCount,
  }) {
    final isSelected = _selectedDifficulty == value;
    final iconColor = isSelected
        ? Colors.white
        : theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDifficulty = isSelected ? null : value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  triangleCount,
                  (_) => Icon(
                    Icons.change_history_rounded,
                    color: iconColor,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildTagsSection(
      BuildContext context, ThemeData theme, AppLocalizations? localizations) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Categories label
          Text(
            (localizations?.tags ?? "Tags").toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recipeCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = recipeCategories[index];
                final label = category.getLabel(localizations);
                final isSelected = _tags.contains(label);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _tags.remove(label);
                      } else {
                        _tags.add(label);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? Colors.white
                            : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Dietary label
          Text(
            (localizations?.dietaryPreferences ?? "Dietary").toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dietaryPreferences.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final pref = dietaryPreferences[index];
                final label = pref.getLabel(localizations);
                final isSelected = _tags.contains(label);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _tags.remove(label);
                      } else {
                        _tags.add(label);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? Colors.white
                            : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Custom tag input
          Row(
            children: [
              Expanded(
                child: _buildLabeledTextField(
                  controller: _tagController,
                  hint: localizations?.addTag ?? "Add a tag...",
                  theme: theme,
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _addTag,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.add_rounded, color: theme.colorScheme.onPrimary),
                ),
              ),
            ],
          ),

          // Custom tags
          if (_tags.any((t) =>
              !recipeCategories.any((c) => c.getLabel(localizations) == t) &&
              !dietaryPreferences.any((d) => d.getLabel(localizations) == t))) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags
                  .where((t) =>
                      !recipeCategories.any((c) => c.getLabel(localizations) == t) &&
                      !dietaryPreferences.any((d) => d.getLabel(localizations) == t))
                  .map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tag,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _removeTag(tag),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIngredientsSection(
      BuildContext context, ThemeData theme, AppLocalizations? localizations) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (localizations?.ingredients ?? "Ingredients").toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              if (_ingredients.isNotEmpty)
                Text(
                  "${_ingredients.length} ${(localizations?.ingredientUnit ?? 'items').toUpperCase()}",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Ingredient tiles
          if (_ingredients.isNotEmpty) ...[
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _ingredients.length,
              onReorder: _reorderIngredients,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final animValue =
                        Curves.easeInOut.transform(animation.value);
                    final elevation = lerpDouble(0, 6, animValue)!;
                    return Material(
                      elevation: elevation,
                      borderRadius: BorderRadius.circular(16),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                return _IngredientTile(
                  key: ValueKey(_ingredients[index]),
                  ingredient: _ingredients[index],
                  index: index,
                  onRemove: () => _removeIngredient(index),
                  onAddNew: _addIngredient,
                  theme: theme,
                  localizations: localizations,
                );
              },
            ),
            const SizedBox(height: 8),
          ],

          // Empty state
          if (_ingredients.isEmpty) ...[
            _buildEmptyState(
              theme,
              icon: Icons.shopping_basket_outlined,
              message: localizations?.noIngredientsYet ?? "No ingredients yet. Add your first ingredient!",
              onTap: _addIngredient,
              localizations: localizations,
            ),
            const SizedBox(height: 12),
          ],

          // Add ingredient button (dashed)
          GestureDetector(
            onTap: _addIngredient,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  width: 1.5,
                  // Dashed border workaround via custom painter below
                ),
                color: Colors.transparent,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded,
                      color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    (localizations?.add ?? "Add Ingredient")
                        .toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
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

  Widget _buildStepsSection(
      BuildContext context, ThemeData theme, AppLocalizations? localizations) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            (localizations?.instruction ?? "Cooking Steps").toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Step tiles
          if (_steps.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                return _StepTile(
                  key: ValueKey(_steps[index]),
                  step: _steps[index],
                  stepNumber: index + 1,
                  onRemove: () => _removeStep(index),
                  onAddNew: _addStep,
                  theme: theme,
                  localizations: localizations,
                  isLast: index == _steps.length - 1,
                );
              },
            ),

          // Empty state
          if (_steps.isEmpty) ...[
            _buildEmptyState(
              theme,
              icon: Icons.format_list_numbered_outlined,
              message: localizations?.noStepsYet ?? "No steps yet. Add your first step!",
              onTap: _addStep,
              localizations: localizations,
            ),
            const SizedBox(height: 12),
          ],

          if (_steps.isNotEmpty) const SizedBox(height: 8),

          // Add step button
          GestureDetector(
            onTap: _addStep,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                color: Colors.transparent,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.format_list_bulleted_add,
                      color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    (localizations?.add ?? "Add Next Step").toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
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

  Widget _buildEmptyState(
    ThemeData theme, {
    required IconData icon,
    required String message,
    required VoidCallback onTap,
    AppLocalizations? localizations,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: double.infinity),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 28,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ThemeData theme,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    IconData? prefixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label.isNotEmpty ? label : null,
        hintText: hint,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              )
            : null,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.colorScheme.error,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadStatus(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _uploadStatus!,
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(
      BuildContext context, ThemeData theme, AppLocalizations? localizations) {
    return FilledButton(
      onPressed: _isSubmitting ? null : _submit,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: theme.colorScheme.primary,
      ),
      child: _isSubmitting
          ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.onPrimary,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isEditMode ? Icons.save_rounded : Icons.publish_rounded,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  _isEditMode
                      ? (localizations?.saveChanges ?? "Save Changes")
                      : (localizations?.publishRecipe ?? "Publish Recipe"),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

// Helper function
double? lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}

class _IngredientItem {
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final FocusNode nameFocusNode = FocusNode();
}

class _IngredientTile extends StatefulWidget {
  const _IngredientTile({
    super.key,
    required this.ingredient,
    required this.index,
    required this.onRemove,
    required this.onAddNew,
    required this.theme,
    this.localizations,
  });

  final _IngredientItem ingredient;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onAddNew;
  final ThemeData theme;
  final AppLocalizations? localizations;

  @override
  State<_IngredientTile> createState() => _IngredientTileState();
}

class _IngredientTileState extends State<_IngredientTile> {
  @override
  Widget build(BuildContext context) {
    final ingredient = widget.ingredient;
    final theme = widget.theme;
    final localizations = widget.localizations;
    final index = widget.index;
    final onRemove = widget.onRemove;
    final onAddNew = widget.onAddNew;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle — only this part initiates the reorder drag
          Listener(
            onPointerDown: (_) => FocusScope.of(context).unfocus(),
            child: ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 22,
                ),
              ),
            ),
          ),
          // Name + qty/unit fields
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: ingredient.nameController,
                  focusNode: ingredient.nameFocusNode,
                  textInputAction: TextInputAction.next,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: localizations?.ingredient ?? "Ingredient",
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                    hintText: localizations?.ingredientExample ?? "e.g., flour",
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w400,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: ingredient.quantityController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [_DecimalNumberFormatter()],
                        textInputAction: TextInputAction.next,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: localizations?.quantity ?? "Qty",
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                          hintText: localizations?.quantityExample ?? "e.g., 2",
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextFormField(
                        controller: ingredient.unitController,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => onAddNew(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: localizations?.unit ?? "Unit",
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                          hintText: localizations != null
                              ? "${localizations.quantityExample.replaceAll(RegExp(r'\d.*'), '')}${localizations.cupsHint}"
                              : "e.g., cups",
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Delete button
          Transform.translate(
            offset: const Offset(8, 0),
            child: GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem {
  final TextEditingController instructionController = TextEditingController();
}

/// Custom formatter that allows only numeric input with optional decimal point
class _DecimalNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty string
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Check if the new value is a valid decimal number
    // Allow: digits, single decimal point, but not multiple decimal points
    final regex = RegExp(r'^\d+\.?\d*$');

    if (regex.hasMatch(newValue.text)) {
      return newValue;
    }

    // If not valid, return the old value (prevent invalid input)
    return oldValue;
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    super.key,
    required this.step,
    required this.stepNumber,
    required this.onRemove,
    required this.onAddNew,
    required this.theme,
    required this.isLast,
    this.localizations,
  });

  final _StepItem step;
  final int stepNumber;
  final VoidCallback onRemove;
  final VoidCallback onAddNew;
  final ThemeData theme;
  final bool isLast;
  final AppLocalizations? localizations;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Number + connecting line
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "$stepNumber",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),

          // Text field + delete
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Stack(
                children: [
                  TextFormField(
                    controller: step.instructionController,
                    maxLines: null,
                    minLines: 2,
                    style: theme.textTheme.bodyMedium,
                    textInputAction: TextInputAction.newline,
                    onFieldSubmitted: (_) => onAddNew(),
                    decoration: InputDecoration(
                      hintText: localizations?.describeThisStep ??
                          "Describe this step...",
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.fromLTRB(14, 12, 36, 12),
                    ),
                  ),
                  // Delete button top-right
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.dashWidth,
    required this.dashSpace,
    required this.strokeWidth,
  });

  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2,
          size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final start = distance;
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      borderRadius != oldDelegate.borderRadius ||
      dashWidth != oldDelegate.dashWidth ||
      dashSpace != oldDelegate.dashSpace ||
      strokeWidth != oldDelegate.strokeWidth;
}
