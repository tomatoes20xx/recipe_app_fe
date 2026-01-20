import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:image/image.dart" as img;

import "../api/api_client.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_api.dart";
import "../recipes/recipe_detail_models.dart";
import "../utils/error_utils.dart";
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

  final List<String> _tags = [];
  final List<_IngredientItem> _ingredients = [];
  final List<_StepItem> _steps = [];
  final List<XFile> _selectedImages = [];
  final List<RecipeImage> _existingImages = []; // Existing images from recipe
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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        // Compress and resize the image before adding it for faster uploads
        final compressedFile = await _compressImage(File(image.path));
        if (compressedFile != null) {
          setState(() {
            _selectedImages.add(XFile(compressedFile.path));
          });
        } else {
          // If compression fails, use original
          setState(() {
            _selectedImages.add(image);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    }
  }

  /// Compresses and resizes an image to reduce file size
  /// Max dimensions: 1920x1920, Quality: 85% (balanced for quality and speed)
  Future<File?> _compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      
      if (originalImage == null) return null;

      // Calculate new dimensions (max 1920px on longest side)
      int width = originalImage.width;
      int height = originalImage.height;
      const maxDimension = 1920;
      
      if (width > maxDimension || height > maxDimension) {
        if (width > height) {
          height = (height * maxDimension / width).round();
          width = maxDimension;
        } else {
          width = (width * maxDimension / height).round();
          height = maxDimension;
        }
      }

      // Resize the image
      final resizedImage = img.copyResize(
        originalImage,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      );

      // Convert to JPEG with 85% quality
      final jpegBytes = img.encodeJpg(resizedImage, quality: 85);
      
      // Save to a temporary file
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedFile = File('${tempDir.path}/compressed_$timestamp.jpg');
      await compressedFile.writeAsBytes(jpegBytes);
      
      return compressedFile;
    } catch (e) {
      // If compression fails, return null to use original
      return null;
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ingredients.isEmpty) {
        ErrorUtils.showError(context, "Please add at least one ingredient");
      return;
    }
    if (_steps.isEmpty) {
        ErrorUtils.showError(context, "Please add at least one step");
      return;
    }

    // Validate ingredients
    for (var i = 0; i < _ingredients.length; i++) {
      if (_ingredients[i].nameController.text.trim().isEmpty) {
        ErrorUtils.showError(context, "Ingredient ${i + 1}: name is required");
        return;
      }
    }

    // Validate steps
    for (var i = 0; i < _steps.length; i++) {
      if (_steps[i].instructionController.text.trim().isEmpty) {
        ErrorUtils.showError(context, "Step ${i + 1}: instruction is required");
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
        ErrorUtils.showError(context, "Minimum cooking time must be a valid number");
        return;
      }
    }
    if (cookingTimeMaxText.isNotEmpty) {
      final max = int.tryParse(cookingTimeMaxText);
      if (max == null) {
        ErrorUtils.showError(context, "Maximum cooking time must be a valid number");
        return;
      }
    }
    
    // Parse cooking time values - we already validated they're valid if text is present
    final cookingTimeMin = cookingTimeMinText.isEmpty
        ? null
        : (int.tryParse(cookingTimeMinText) ?? null);
    final cookingTimeMax = cookingTimeMaxText.isEmpty
        ? null
        : (int.tryParse(cookingTimeMaxText) ?? null);

    if (cookingTimeMin != null && cookingTimeMax != null && cookingTimeMin > cookingTimeMax) {
      ErrorUtils.showError(context, "Minimum cooking time cannot be greater than maximum time");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final ingredients = _ingredients
          .asMap()
          .entries
          .map((e) {
            final qty = e.value.quantityController.text.trim();
            final unit = e.value.unitController.text.trim();
            final name = e.value.nameController.text.trim();
            
            // Build ingredient - normalized_name is likely auto-generated by backend, don't send it
            final parsedQty = qty.isNotEmpty ? double.tryParse(qty) : null;
            final ingredient = <String, dynamic>{
              "display_name": name,
              "sort_order": e.key,
            };
            
            // Add optional fields only if they have values
            if (parsedQty != null) {
              ingredient["quantity"] = parsedQty;
            }
            if (unit.isNotEmpty) {
              ingredient["unit"] = unit;
            }
            
            return ingredient;
          })
          .toList();

      final steps = _steps
          .asMap()
          .entries
          .map((e) => {
                "instruction": e.value.instructionController.text.trim(),
                "sort_order": e.key,
              })
          .toList();

      final api = RecipeApi(widget.apiClient);
      
      // Convert XFile to File for upload
      final imageFiles = _selectedImages
          .map((xfile) => File(xfile.path))
          .toList();
      
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
        // Only send fields that are being updated (partial update)
        // For ingredients and steps: only send if user wants to update them
        // For now, we'll only send metadata fields (title, description, cuisine, tags)
        // Ingredients and steps require full replace, so we'll handle them separately if needed
        final cookingTimeMinText = _cookingTimeMinController.text.trim();
        final cookingTimeMaxText = _cookingTimeMaxController.text.trim();
        
        final cookingTimeMin = cookingTimeMinText.isEmpty
            ? null
            : int.tryParse(cookingTimeMinText);
        final cookingTimeMax = cookingTimeMaxText.isEmpty
            ? null
            : int.tryParse(cookingTimeMaxText);

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
          // Don't send ingredients/steps unless explicitly updating them
          // This allows partial updates of just metadata
          ingredients: null,
          steps: null,
        );
        
        // Note: Image updates would need a separate endpoint if supported
        // For now, we only update metadata via PATCH
      } else {
        // Create new recipe
        final cookingTimeMinText = _cookingTimeMinController.text.trim();
        final cookingTimeMaxText = _cookingTimeMaxController.text.trim();
        
        final cookingTimeMin = cookingTimeMinText.isEmpty
            ? null
            : int.tryParse(cookingTimeMinText);
        final cookingTimeMax = cookingTimeMaxText.isEmpty
            ? null
            : int.tryParse(cookingTimeMaxText);

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
        ErrorUtils.showSuccess(
          context,
          _isEditMode ? "Recipe updated successfully" : "Recipe created successfully",
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorUtils.getUserFriendlyMessage(e);
          _isSubmitting = false;
          _uploadStatus = null;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              _isEditMode ? (localizations?.editRecipe ?? "Edit Recipe") : (localizations?.createRecipeTitle ?? "Create Recipe"),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            );
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: "${localizations?.title ?? "Title"} *",
                    hintText: localizations?.enterRecipeTitle ?? "Enter recipe title",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "${localizations?.title ?? "Title"} is required";
                    }
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Description
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: localizations?.description ?? "Description",
                    hintText: localizations?.describeYourRecipe ?? "Describe your recipe",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
                  maxLines: 4,
                );
              },
            ),
            const SizedBox(height: 16),

            // Cuisine
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return TextFormField(
                  controller: _cuisineController,
                  decoration: InputDecoration(
                    labelText: localizations?.cuisine ?? "Cuisine",
                    hintText: localizations?.cuisineExample ?? "e.g., Italian, Mexican, Asian",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Cooking Time
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cookingTimeMinController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: localizations?.minTimeMinutes ?? "Min Time (minutes)",
                              hintText: "0",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          prefixIcon: const Icon(Icons.timer_outlined),
                        ),
                        onChanged: (value) {
                          // Clear error when user starts typing
                          if (_cookingTimeError != null) {
                            setState(() {
                              _cookingTimeError = null;
                            });
                          }
                          // Validate in real-time if both fields have values
                          final min = value.trim().isEmpty ? null : int.tryParse(value.trim());
                          final max = _cookingTimeMaxController.text.trim().isEmpty
                              ? null
                              : int.tryParse(_cookingTimeMaxController.text.trim());
                          if (min != null && max != null && min > max) {
                            setState(() {
                              _cookingTimeError = "Minimum time cannot be greater than maximum time";
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _cookingTimeMaxController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: localizations?.maxTimeMinutes ?? "Max Time (minutes)",
                              hintText: "120",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          prefixIcon: const Icon(Icons.timer),
                        ),
                        onChanged: (value) {
                          // Clear error when user starts typing
                          if (_cookingTimeError != null) {
                            setState(() {
                              _cookingTimeError = null;
                            });
                          }
                          // Validate in real-time if both fields have values
                          final max = value.trim().isEmpty ? null : int.tryParse(value.trim());
                          final min = _cookingTimeMinController.text.trim().isEmpty
                              ? null
                              : int.tryParse(_cookingTimeMinController.text.trim());
                          if (min != null && max != null && min > max) {
                            setState(() {
                              _cookingTimeError = "Minimum time cannot be greater than maximum time";
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (_cookingTimeError != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      _cookingTimeError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Difficulty
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.difficulty ?? "Difficulty",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String?>(
                        segments: [
                          ButtonSegment<String?>(value: "easy", label: Text(localizations?.easy ?? "Easy")),
                          ButtonSegment<String?>(value: "medium", label: Text(localizations?.medium ?? "Medium")),
                          ButtonSegment<String?>(value: "hard", label: Text(localizations?.hard ?? "Hard")),
                        ],
                    selected: _selectedDifficulty != null ? {_selectedDifficulty} : <String?>{},
                    onSelectionChanged: (Set<String?> newSelection) {
                      setState(() {
                        // Allow deselection: if clicking the same option, deselect it
                        if (newSelection.isEmpty || newSelection.first == _selectedDifficulty) {
                          _selectedDifficulty = null;
                        } else {
                          _selectedDifficulty = newSelection.firstOrNull;
                        }
                      });
                    },
                    multiSelectionEnabled: false,
                    emptySelectionAllowed: true,
                        style: SegmentedButton.styleFrom(
                          fixedSize: const Size.fromHeight(40),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Images
            _SectionTitle("Images"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Existing images (in edit mode)
                ..._existingImages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final image = entry.value;
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: RecipeImageWidget(
                          imageUrl: image.url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          cacheWidth: 200,
                          cacheHeight: 200,
                          placeholderSize: 20,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeExistingImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                // New images
                ..._selectedImages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final image = entry.value;
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(image.path),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.white),
                            onPressed: () => _removeImage(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 32,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Add",
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tags
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(localizations?.tags ?? "Tags"),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            decoration: InputDecoration(
                              hintText: localizations?.addTag ?? "Add a tag",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _addTag,
                          icon: const Icon(Icons.add_circle_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                    if (_tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            onDeleted: () => _removeTag(tag),
                            deleteIcon: const Icon(Icons.close, size: 18),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            // Ingredients
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SectionTitle("${localizations?.ingredients ?? "Ingredients"} *"),
                        TextButton.icon(
                          onPressed: _addIngredient,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(localizations?.add ?? "Add"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._ingredients.asMap().entries.map((entry) {
                      final index = entry.key;
                      final ingredient = entry.value;
                      return _IngredientField(
                        ingredient: ingredient,
                        onRemove: () => _removeIngredient(index),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            // Steps
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SectionTitle("${localizations?.instruction ?? "Steps"} *"),
                        TextButton.icon(
                          onPressed: _addStep,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(localizations?.add ?? "Add"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._steps.asMap().entries.map((entry) {
                      final index = entry.key;
                      final step = entry.value;
                      return _StepField(
                        step: step,
                        stepNumber: index + 1,
                        onRemove: () => _removeStep(index),
                      );
                    }),
                    if (_steps.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            "No steps yet. Add one to get started!",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),

            // Error message
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Upload status message
            if (_uploadStatus != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _uploadStatus!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Submit button
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isEditMode 
                            ? (localizations?.editRecipe ?? "Edit Recipe")
                            : (localizations?.createRecipeTitle ?? "Create Recipe"),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
    );
  }
}

class _IngredientItem {
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
}

class _IngredientField extends StatelessWidget {
  const _IngredientField({required this.ingredient, required this.onRemove});
  final _IngredientItem ingredient;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return TextFormField(
                    controller: ingredient.quantityController,
                    decoration: InputDecoration(
                      labelText: localizations?.quantity ?? "Quantity",
                      hintText: localizations?.quantityExample ?? "e.g., 2",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      _DecimalNumberFormatter(),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return TextFormField(
                    controller: ingredient.unitController,
                    decoration: InputDecoration(
                      labelText: localizations?.unit ?? "Unit",
                      hintText: localizations?.unitExample ?? "e.g., cups",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return TextFormField(
                    controller: ingredient.nameController,
                    decoration: InputDecoration(
                      labelText: "${localizations?.ingredient ?? "Ingredient"} *",
                      hintText: localizations?.ingredientExample ?? "e.g., flour",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
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

class _StepField extends StatelessWidget {
  const _StepField({
    required this.step,
    required this.stepNumber,
    required this.onRemove,
  });
  final _StepItem step;
  final int stepNumber;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                "$stepNumber",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return TextFormField(
                    controller: step.instructionController,
                    decoration: InputDecoration(
                      labelText: "${localizations?.instruction ?? "Instruction"} *",
                      hintText: localizations?.describeThisStep ?? "Describe this step",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                maxLines: 3,
              );
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }
}

