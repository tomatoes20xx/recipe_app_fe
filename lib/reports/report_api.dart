import "../api/api_client.dart";
import "report_models.dart";

class ReportApi {
  ReportApi(this._client);

  final ApiClient _client;

  /// Creates a report for a recipe, comment, or user.
  /// Returns successfully (204 No Content) for both new and duplicate reports (idempotent).
  ///
  /// Throws [ApiException] with appropriate status code:
  /// - 400: Invalid request (bad UUID, invalid enum, reason too short/long)
  /// - 404: Target not found (recipe/comment/user doesn't exist or is deleted)
  /// - 401: Not authenticated
  /// - 500: Server error
  Future<void> createReport(CreateReportRequest request) async {
    await _client.post(
      "/reports",
      body: request.toJson(),
      auth: true,
    );
    // Backend returns 204 No Content on success, which _client.post handles as null
  }

  /// Convenience method to report a recipe
  Future<void> reportRecipe({
    required String recipeId,
    required String reason,
  }) async {
    await createReport(CreateReportRequest(
      targetType: ReportTargetType.recipe,
      targetId: recipeId,
      reason: reason,
    ));
  }

  /// Convenience method to report a comment
  Future<void> reportComment({
    required String commentId,
    required String reason,
  }) async {
    await createReport(CreateReportRequest(
      targetType: ReportTargetType.comment,
      targetId: commentId,
      reason: reason,
    ));
  }

  /// Convenience method to report a user
  Future<void> reportUser({
    required String userId,
    required String reason,
  }) async {
    await createReport(CreateReportRequest(
      targetType: ReportTargetType.user,
      targetId: userId,
      reason: reason,
    ));
  }
}
