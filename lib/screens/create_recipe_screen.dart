import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";

import "../api/api_client.dart";
import "../constants/cuisines.dart";
import "../constants/recipe_categories.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_api.dart";
import "../recipes/recipe_detail_models.dart";
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

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
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

  String? _selectedDifficulty; // 'easy', 'medium', 'hard'
  String? _cookingTimeError;

  bool _isSubmitting = false;
  String? _error;
  String? _uploadStatus; // For showing upload progress
  bool _isEditMode = false;


  @override
  void initState() {
    super.initState();
    _isEditMode = widget.recipeId != null && widget.recipe != null;
    if (_isEditMode && widget.recipe != null) {
      _loadRecipeData(widget.recipe!);
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
    _selectedDifficulty = recipe.difficulty;

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
    }
    for (var step in _steps) {
      step.instructionController.dispose();
    }
    super.dispose();
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
    setState(() {
      _ingredients.add(_IngredientItem());
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients[index].quantityController.dispose();
      _ingredients[index].unitController.dispose();
      _ingredients[index].nameController.dispose();
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
    if (!_formKey.currentState!.validate()) return;
    final localizations = AppLocalizations.of(context);
    if (_ingredients.isEmpty) {
      ErrorUtils.showError(
          context,
          localizations?.pleaseAddAtLeastOneIngredient ??
              "Please add at least one ingredient");
      return;
    }
    if (_steps.isEmpty) {
      ErrorUtils.showError(context,
          localizations?.pleaseAddAtLeastOneStep ?? "Please add at least one step");
      return;
    }

    // Validate ingredients
    for (var i = 0; i < _ingredients.length; i++) {
      if (_ingredients[i].nameController.text.trim().isEmpty) {
        ErrorUtils.showError(
            context,
            localizations?.ingredientNameRequired(i) ??
                "Ingredient ${i + 1}: name is required");
        return;
      }
    }

    // Validate steps
    for (var i = 0; i < _steps.length; i++) {
      if (_steps[i].instructionController.text.trim().isEmpty) {
        ErrorUtils.showError(
            context,
            localizations?.stepInstructionRequired(i) ??
                "Step ${i + 1}: instruction is required");
        return;
      }
    }

    // Validate cooking time: min should not be more than max (they can be equal)
    final cookingTimeMinText = _cookingTimeMinController.text.trim();
    final cookingTimeMaxText = _cookingTimeMaxController.text.trim();

    // Check if fields have text but are invalid
    if (cookingTimeMinText.isNotEmpty) {
      final min = int.tryParse(cookingTimeMinText);
      if (min == null) {
        ErrorUtils.showError(
            context,
            localizations?.minCookingTimeMustBeValidNumber ??
                "Minimum cooking time must be a valid number");
        return;
      }
    }
    if (cookingTimeMaxText.isNotEmpty) {
      final max = int.tryParse(cookingTimeMaxText);
      if (max == null) {
        ErrorUtils.showError(
            context,
            localizations?.maxCookingTimeMustBeValidNumber ??
                "Maximum cooking time must be a valid number");
        return;
      }
    }

    // Parse cooking time values - we already validated they're valid if text is present
    final cookingTimeMin =
        cookingTimeMinText.isEmpty ? null : int.tryParse(cookingTimeMinText);
    final cookingTimeMax =
        cookingTimeMaxText.isEmpty ? null : int.tryParse(cookingTimeMaxText);

    if (cookingTimeMin != null &&
        cookingTimeMax != null &&
        cookingTimeMin > cookingTimeMax) {
      ErrorUtils.showError(
          context,
          localizations?.minCookingTimeCannotBeGreater ??
              "Minimum cooking time cannot be greater than maximum time");
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
          difficulty: _selectedDifficulty,
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
          difficulty: _selectedDifficulty,
          ingredients: ingredients,
          steps: steps,
          images: imageFiles.isEmpty ? null : imageFiles,
        );
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
      expandedHeight: hasImages ? 280 : 200,
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            theme.colorScheme.surface,
          ],
        ),
      ),
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
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_rounded,
                size: 28,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
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
    return _buildSectionCard(
      context: context,
      theme: theme,
      title: localizations?.basicInfo ?? "Basic Info",
      icon: Icons.info_outline_rounded,
      iconColor: theme.colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          _buildModernTextField(
            controller: _titleController,
            label: "${localizations?.title ?? "Title"} *",
            hint: localizations?.enterRecipeTitle ?? "Enter recipe title",
            theme: theme,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "${localizations?.title ?? "Title"} is required";
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Description
          _buildModernTextField(
            controller: _descriptionController,
            label: localizations?.description ?? "Description",
            hint: localizations?.describeYourRecipe ?? "Describe your recipe",
            theme: theme,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildCookingDetailsSection(
      BuildContext context, ThemeData theme, AppLocalizations? localizations) {
    return _buildSectionCard(
      context: context,
      theme: theme,
      title: localizations?.cookingDetails ?? "Cooking Details",
      icon: Icons.schedule_rounded,
      iconColor: Colors.orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cuisine
          _buildModernTextField(
            controller: _cuisineController,
            label: localizations?.cuisine ?? "Cuisine",
            hint: localizations?.cuisineExample ?? "e.g., Italian, Mexican",
            theme: theme,
            prefixIcon: Icons.restaurant_rounded,
          ),
          const SizedBox(height: 8),

          // Cuisine suggestions
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cuisineOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final option = cuisineOptions[index];
                final isSelected =
                    _cuisineController.text.toLowerCase() == option.value.toLowerCase();
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _cuisineController.text = isSelected ? "" : option.value;
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected
                          ? Border.all(color: theme.colorScheme.primary, width: 1)
                          : null,
                    ),
                    child: Text(
                      option.getLabel(localizations),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Cooking Time
          Row(
            children: [
              Expanded(
                child: _buildModernTextField(
                  controller: _cookingTimeMinController,
                  label: localizations?.minTimeMinutes ?? "Min (mins)",
                  hint: "15",
                  theme: theme,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.timer_outlined,
                  onChanged: (_) => _validateCookingTime(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernTextField(
                  controller: _cookingTimeMaxController,
                  label: localizations?.maxTimeMinutes ?? "Max (mins)",
                  hint: "30",
                  theme: theme,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.timer,
                  onChanged: (_) => _validateCookingTime(),
                ),
              ),
            ],
          ),

          if (_cookingTimeError != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
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

          const SizedBox(height: 20),

          // Difficulty
          Text(
            localizations?.difficulty ?? "Difficulty",
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildDifficultyChip(
                theme,
                label: localizations?.easy ?? "Easy",
                value: "easy",
                color: Colors.green,
              ),
              const SizedBox(width: 10),
              _buildDifficultyChip(
                theme,
                label: localizations?.medium ?? "Medium",
                value: "medium",
                color: Colors.orange,
              ),
              const SizedBox(width: 10),
              _buildDifficultyChip(
                theme,
                label: localizations?.hard ?? "Hard",
                value: "hard",
                color: Colors.red,
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
    required String value,
    required Color color,
  }) {
    final isSelected = _selectedDifficulty == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDifficulty = isSelected ? null : value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                value == "easy"
                    ? Icons.sentiment_satisfied_rounded
                    : value == "medium"
                        ? Icons.sentiment_neutral_rounded
                        : Icons.local_fire_department_rounded,
                color: isSelected
                    ? color
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? color
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
    return _buildSectionCard(
      context: context,
      theme: theme,
      title: localizations?.tags ?? "Tags",
      icon: Icons.label_outline_rounded,
      iconColor: Colors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recipeCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = recipeCategories[index];
                final isSelected = _tags.contains(category.tag);
                return FilterChip(
                  selected: isSelected,
                  label: Text(category.getLabel(localizations)),
                  avatar: Icon(category.icon, size: 18),
                  visualDensity: VisualDensity.compact,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _tags.add(category.tag);
                      } else {
                        _tags.remove(category.tag);
                      }
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildModernTextField(
                  controller: _tagController,
                  label: "",
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
                  child: Icon(
                    Icons.add_rounded,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          // Only show custom (non-predefined) tags below the input
          if (_tags.any((t) => !recipeCategories.any((c) => c.tag == t))) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags
                  .where((t) => !recipeCategories.any((c) => c.tag == t))
                  .map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tag,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _removeTag(tag),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
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
    return _buildSectionCard(
      context: context,
      theme: theme,
      title: "${localizations?.ingredients ?? "Ingredients"} *",
      icon: Icons.shopping_basket_rounded,
      iconColor: Colors.green,
      action: TextButton.icon(
        onPressed: _addIngredient,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(localizations?.add ?? "Add"),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      child: _ingredients.isEmpty
          ? _buildEmptyState(
              theme,
              icon: Icons.shopping_basket_outlined,
              message: localizations?.noIngredientsYet ??
                  "No ingredients yet. Add your first ingredient!",
              onTap: _addIngredient,
              localizations: localizations,
            )
          : ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _ingredients.length,
              onReorder: _reorderIngredients,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final animValue = Curves.easeInOut.transform(animation.value);
                    final elevation = lerpDouble(0, 6, animValue)!;
                    return Material(
                      elevation: elevation,
                      borderRadius: BorderRadius.circular(12),
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
                  theme: theme,
                  localizations: localizations,
                );
              },
            ),
    );
  }

  Widget _buildStepsSection(
      BuildContext context, ThemeData theme, AppLocalizations? localizations) {
    return _buildSectionCard(
      context: context,
      theme: theme,
      title: "${localizations?.instruction ?? "Steps"} *",
      icon: Icons.format_list_numbered_rounded,
      iconColor: Colors.blue,
      action: TextButton.icon(
        onPressed: _addStep,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(localizations?.add ?? "Add"),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      child: _steps.isEmpty
          ? _buildEmptyState(
              theme,
              icon: Icons.format_list_numbered_outlined,
              message: localizations?.noStepsYet ??
                  "No steps yet. Add your first step!",
              onTap: _addStep,
              localizations: localizations,
            )
          : ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _steps.length,
              onReorder: _reorderSteps,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final animValue = Curves.easeInOut.transform(animation.value);
                    final elevation = lerpDouble(0, 6, animValue)!;
                    return Material(
                      elevation: elevation,
                      borderRadius: BorderRadius.circular(12),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                return _StepTile(
                  key: ValueKey(_steps[index]),
                  step: _steps[index],
                  stepNumber: index + 1,
                  onRemove: () => _removeStep(index),
                  theme: theme,
                  localizations: localizations,
                  isLast: index == _steps.length - 1,
                );
              },
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    localizations?.tapToAdd ?? "Tap to add",
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
}

class _IngredientTile extends StatelessWidget {
  const _IngredientTile({
    super.key,
    required this.ingredient,
    required this.index,
    required this.onRemove,
    required this.theme,
    this.localizations,
  });

  final _IngredientItem ingredient;
  final int index;
  final VoidCallback onRemove;
  final ThemeData theme;
  final AppLocalizations? localizations;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // First row: Drag handle, Quantity, Unit, Delete button
          Row(
            children: [
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Quantity
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: ingredient.quantityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [_DecimalNumberFormatter()],
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: localizations?.quantity ?? "Qty",
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    hintText: "2",
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Unit
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: ingredient.unitController,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: localizations?.unit ?? "Unit",
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    hintText: localizations?.cupsHint ?? "cups",
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Delete button
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close_rounded,
                    color: theme.colorScheme.error.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Second row: Ingredient name (full width)
          TextFormField(
            controller: ingredient.nameController,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              labelText: localizations?.ingredient ?? "Ingredient",
              labelStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              hintText: localizations?.ingredientExample ?? "e.g., flour",
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 13,
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    required this.theme,
    required this.isLast,
    this.localizations,
  });

  final _StepItem step;
  final int stepNumber;
  final VoidCallback onRemove;
  final ThemeData theme;
  final bool isLast;
  final AppLocalizations? localizations;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline indicator
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  // Step number circle
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
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  // Connecting line
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    ReorderableDragStartListener(
                      index: stepNumber - 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Instruction field
                    Expanded(
                      child: TextFormField(
                        controller: step.instructionController,
                        maxLines: 3,
                        minLines: 2,
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: localizations?.describeThisStep ??
                              "Describe this step...",
                          hintStyle: TextStyle(
                            color:
                                theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Delete button
                    GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          color: theme.colorScheme.error.withValues(alpha: 0.7),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
