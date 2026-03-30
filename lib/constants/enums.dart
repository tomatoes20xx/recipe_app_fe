enum FeedScope { global, following, popular, trending }

extension FeedScopeApi on FeedScope {
  String get apiValue => switch (this) {
        FeedScope.global    => 'global',
        FeedScope.following => 'following',
        FeedScope.popular   => 'popular',
        FeedScope.trending  => 'trending',
      };
}

enum FeedSort { recent, top }

extension FeedSortApi on FeedSort {
  String get apiValue => switch (this) {
        FeedSort.recent => 'recent',
        FeedSort.top    => 'top',
      };
}

enum PopularPeriod { allTime, last30Days, last7Days }

extension PopularPeriodApi on PopularPeriod {
  String get apiValue => switch (this) {
        PopularPeriod.allTime    => 'all_time',
        PopularPeriod.last30Days => '30d',
        PopularPeriod.last7Days  => '7d',
      };
}

enum Difficulty { easy, medium, hard }

extension DifficultyApi on Difficulty {
  String get apiValue => switch (this) {
        Difficulty.easy   => 'easy',
        Difficulty.medium => 'medium',
        Difficulty.hard   => 'hard',
      };

  static Difficulty? fromApiValue(String? value) => switch (value?.toLowerCase()) {
        'easy'   => Difficulty.easy,
        'medium' => Difficulty.medium,
        'hard'   => Difficulty.hard,
        _        => null,
      };
}
