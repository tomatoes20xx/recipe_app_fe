final Map<String, CommentsUIState> commentsUIStateCache = {};

class CommentsUIState {
  CommentsUIState({
    required this.collapsedIds,
    required this.fullyExpandedIds,
    this.scrollPosition = 0.0,
    this.hasInitializedCollapsedState = false,
  });

  final Set<String> collapsedIds;
  final Set<String> fullyExpandedIds;
  final double scrollPosition;
  final bool hasInitializedCollapsedState;

  CommentsUIState copyWith({
    Set<String>? collapsedIds,
    Set<String>? fullyExpandedIds,
    double? scrollPosition,
    bool? hasInitializedCollapsedState,
  }) {
    return CommentsUIState(
      collapsedIds: collapsedIds ?? this.collapsedIds,
      fullyExpandedIds: fullyExpandedIds ?? this.fullyExpandedIds,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      hasInitializedCollapsedState: hasInitializedCollapsedState ?? this.hasInitializedCollapsedState,
    );
  }
}
