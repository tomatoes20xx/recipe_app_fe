import "dart:io";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../api/api_client.dart";
import "../auth/auth_api.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../utils/error_utils.dart";
import "../utils/image_utils.dart";

class UsernameSelectionScreen extends StatefulWidget {
  const UsernameSelectionScreen({
    super.key,
    required this.tempToken,
    required this.suggestedDisplayName,
    required this.authApi,
    required this.authController,
    this.avatarUrl,
    this.email,
  });

  final String tempToken;
  final String? suggestedDisplayName;
  final AuthApi authApi;
  final AuthController authController;
  final String? avatarUrl;
  final String? email;

  @override
  State<UsernameSelectionScreen> createState() => _UsernameSelectionScreenState();
}

class _UsernameSelectionScreenState extends State<UsernameSelectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isLoading = false;
  File? _selectedAvatarFile;

  @override
  void initState() {
    super.initState();
    // Pre-fill suggested display name
    if (widget.suggestedDisplayName != null) {
      _displayNameController.text = widget.suggestedDisplayName!;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    final localizations = AppLocalizations.of(context);

    if (value == null || value.trim().isEmpty) {
      return localizations?.usernameRequired ?? "Username is required";
    }

    final username = value.trim();

    if (username.length < 3) {
      return localizations?.usernameTooShort ?? "Username must be at least 3 characters";
    }

    if (username.length > 30) {
      return localizations?.usernameTooLong ?? "Username must be at most 30 characters";
    }

    // Check valid characters (alphanumeric and underscore)
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return localizations?.usernameInvalidCharacters ?? "Username can only contain letters, numbers, and underscores";
    }

    return null;
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null) return;

      // Compress the image before storing
      final compressedFile = await ImageUtils.compressAvatar(File(image.path));
      final fileToStore = compressedFile ?? File(image.path);

      setState(() {
        _selectedAvatarFile = fileToStore;
      });
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    }
  }

  Future<void> _completeSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final displayName = _displayNameController.text.trim();
      final bio = _bioController.text.trim();

      // Step 1: Call complete-oauth endpoint
      await widget.authApi.completeOAuth(
        tempToken: widget.tempToken,
        username: username,
        displayName: displayName.isNotEmpty ? displayName : null,
        bio: bio.isNotEmpty ? bio : null,
      );

      // Step 2: Bootstrap auth to load user data and get the new token
      await widget.authController.bootstrap();

      // Step 3: Upload avatar if user selected one
      if (_selectedAvatarFile != null) {
        try {
          await widget.authApi.uploadAvatar(_selectedAvatarFile!);
          // Refresh user data to get updated avatar URL
          await widget.authController.bootstrap();
        } catch (e) {
          // Don't block signup if avatar upload fails
          // User can upload avatar later from profile
          debugPrint('Avatar upload failed: $e');
        }
      }

      if (mounted) {
        // Success - navigate to home
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.statusCode == 409) {
          // Username already taken
          ErrorUtils.showError(
            context,
            AppLocalizations.of(context)?.usernameTaken ?? "Username is already taken. Please choose another.",
          );
        } else if (e.statusCode == 401) {
          // Token expired
          ErrorUtils.showError(
            context,
            AppLocalizations.of(context)?.sessionExpired ?? "Session expired. Please sign in again.",
          );
          Navigator.of(context).pop();
        } else {
          ErrorUtils.showError(context, e);
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Avatar with upload functionality
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _isLoading ? null : _pickAvatar,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: _selectedAvatarFile != null
                            ? FileImage(_selectedAvatarFile!)
                            : (widget.avatarUrl != null
                                ? NetworkImage(widget.avatarUrl!) as ImageProvider
                                : null),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        child: _selectedAvatarFile == null && widget.avatarUrl == null
                            ? Icon(
                                Icons.person,
                                size: 50,
                                color: theme.colorScheme.onSurfaceVariant,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Email with verified badge
              if (widget.email != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.email,
                        size: 18,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.email!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.verified,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Welcome header
              Text(
                localizations?.welcomeToYummy ?? "Welcome to Yummy!",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                localizations?.completeYourProfile ?? "Complete your profile to get started",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Username field
              Text(
                localizations?.username ?? "Username",
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _usernameController,
                enabled: !_isLoading,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: localizations?.enterUsername ?? "Enter username",
                  prefixText: "@",
                  prefixIcon: const Icon(Icons.alternate_email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  helperText: localizations?.usernameHelper ?? "3-30 characters, letters, numbers, and underscores only",
                  helperMaxLines: 2,
                ),
                validator: _validateUsername,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 24),

              // Display Name field
              Text(
                localizations?.displayName ?? "Display Name",
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _displayNameController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: localizations?.enterDisplayName ?? "Enter display name (optional)",
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 24),

              // Bio field
              Text(
                localizations?.bio ?? "Bio",
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bioController,
                enabled: !_isLoading,
                maxLines: 3,
                maxLength: 160,
                decoration: InputDecoration(
                  hintText: localizations?.enterBio ?? "Tell us about yourself (optional)",
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 50),
                    child: Icon(Icons.edit_note),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _completeSignup(),
              ),
              const SizedBox(height: 24),

              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        localizations?.profileSetupInfo ?? "Your username is permanent and cannot be changed. Display name and bio can be updated anytime from your profile.",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _completeSignup,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          localizations?.continueButton ?? "Continue",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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
