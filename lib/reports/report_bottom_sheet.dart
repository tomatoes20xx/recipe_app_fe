import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../localization/app_localizations.dart";
import "../utils/error_utils.dart";
import "report_api.dart";
import "report_models.dart";

/// Shows a bottom sheet to report content (recipe, comment, or user).
///
/// Returns `true` if the report was successfully submitted, `false` otherwise.
Future<bool> showReportBottomSheet({
  required BuildContext context,
  required ReportTargetType targetType,
  required String targetId,
  required ApiClient apiClient,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ReportBottomSheet(
      targetType: targetType,
      targetId: targetId,
      apiClient: apiClient,
    ),
  );

  return result ?? false;
}

class _ReportBottomSheet extends StatefulWidget {
  const _ReportBottomSheet({
    required this.targetType,
    required this.targetId,
    required this.apiClient,
  });

  final ReportTargetType targetType;
  final String targetId;
  final ApiClient apiClient;

  @override
  State<_ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<_ReportBottomSheet> {
  ReportReason? _selectedReason;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String _getTitle(AppLocalizations? localizations) {
    switch (widget.targetType) {
      case ReportTargetType.recipe:
        return localizations?.reportRecipe ?? "Report Recipe";
      case ReportTargetType.comment:
        return localizations?.reportComment ?? "Report Comment";
      case ReportTargetType.user:
        return localizations?.reportUser ?? "Report User";
    }
  }

  Future<void> _submitReport() async {
    final localizations = AppLocalizations.of(context);

    if (_selectedReason == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.reportPleaseSelectReason ??
            "Please select a reason for reporting",
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final reportApi = ReportApi(widget.apiClient);

      // Build the reason string - use the selected reason with optional details
      String reason = _selectedReason!.value;
      final additionalDetails = _detailsController.text.trim();
      if (additionalDetails.isNotEmpty) {
        reason = "$reason: $additionalDetails";
      }

      await reportApi.createReport(CreateReportRequest(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: reason,
      ));

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.reportSuccess ?? "Report submitted successfully",
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      // Close the bottom sheet with success
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      // Handle specific error cases
      String errorMessage = localizations?.reportFailed ?? "Failed to submit report";

      if (e.statusCode == 404) {
        errorMessage = localizations?.reportContentNotFound ?? "Content not found";
      } else if (e.statusCode == 401) {
        errorMessage = localizations?.reportLoginRequired ?? "Please log in to report content";
      } else if (e.message.isNotEmpty) {
        errorMessage = e.message;
      }

      ErrorUtils.showError(context, errorMessage);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);
      ErrorUtils.showError(
        context,
        localizations?.reportFailed ?? "Failed to submit report",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Text(
                  _getTitle(localizations),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  localizations?.whyReporting ?? "Why are you reporting this?",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),

                // Reason selection
                Text(
                  localizations?.selectReportReason ?? "Select a reason",
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                // Reason chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ReportReason.values.map((reason) {
                    final isSelected = _selectedReason == reason;
                    return FilterChip(
                      label: Text(_getReasonLabel(reason, localizations)),
                      selected: isSelected,
                      onSelected: _isSubmitting
                          ? null
                          : (selected) {
                              setState(() {
                                _selectedReason = selected ? reason : null;
                              });
                            },
                      selectedColor: colorScheme.primaryContainer,
                      checkmarkColor: colorScheme.onPrimaryContainer,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Additional details (optional)
                TextField(
                  controller: _detailsController,
                  enabled: !_isSubmitting,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: localizations?.reportAdditionalDetails ??
                        "Additional details (optional)",
                    hintText: localizations?.reportAdditionalDetailsHint ??
                        "Provide more context if needed",
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                FilledButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  child: _isSubmitting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : Text(
                          localizations?.reportSubmit ?? "Submit Report",
                        ),
                ),

                // Cancel button
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(localizations?.cancel ?? "Cancel"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getReasonLabel(ReportReason reason, AppLocalizations? localizations) {
    switch (reason) {
      case ReportReason.spam:
        return localizations?.reportReasonSpam ?? reason.value;
      case ReportReason.inappropriate:
        return localizations?.reportReasonInappropriate ?? reason.value;
      case ReportReason.harassment:
        return localizations?.reportReasonHarassment ?? reason.value;
      case ReportReason.copyright:
        return localizations?.reportReasonCopyright ?? reason.value;
      case ReportReason.misinformation:
        return localizations?.reportReasonMisinformation ?? reason.value;
      case ReportReason.other:
        return localizations?.reportReasonOther ?? reason.value;
    }
  }
}
