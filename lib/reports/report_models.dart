/// Report target types matching backend enums
enum ReportTargetType {
  recipe("recipe"),
  comment("comment"),
  user("user");

  const ReportTargetType(this.value);
  final String value;
}

/// Common report reasons for better UX
/// Note: Backend accepts any string 1-500 chars, these are just suggestions
enum ReportReason {
  spam("Spam or misleading content"),
  inappropriate("Inappropriate or offensive content"),
  harassment("Harassment or bullying"),
  copyright("Copyright violation"),
  misinformation("Misinformation or harmful advice"),
  other("Other");

  const ReportReason(this.value);
  final String value;
}

/// Request body for creating a report
class CreateReportRequest {
  final ReportTargetType targetType;
  final String targetId;
  final String reason;

  CreateReportRequest({
    required this.targetType,
    required this.targetId,
    required this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      "targetType": targetType.value,
      "targetId": targetId,
      "reason": reason,
    };
  }
}
