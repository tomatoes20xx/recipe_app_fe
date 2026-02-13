import "package:flutter/material.dart";
import "../analytics/analytics_api.dart";
import "../analytics/analytics_models.dart";
import "../analytics/analytics_stats_controller.dart";
import "../analytics/analytics_events_controller.dart";
import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "../shopping/shopping_list_controller.dart";
import "../utils/ui_utils.dart";
import "../widgets/engagement_stat_widget.dart";
import "../widgets/section_title_widget.dart";

class AnalyticsStatsScreen extends StatefulWidget {
  const AnalyticsStatsScreen({
    super.key,
    required this.apiClient,
    required this.auth,
    required this.shoppingListController,
  });

  final ApiClient apiClient;
  final AuthController auth;
  final ShoppingListController shoppingListController;

  @override
  State<AnalyticsStatsScreen> createState() => _AnalyticsStatsScreenState();
}

class _AnalyticsStatsScreenState extends State<AnalyticsStatsScreen> with SingleTickerProviderStateMixin {
  late final AnalyticsStatsController statsController;
  late final AnalyticsEventsController eventsController;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final analyticsApi = AnalyticsApi(widget.apiClient);
    statsController = AnalyticsStatsController(analyticsApi: analyticsApi);
    eventsController = AnalyticsEventsController(analyticsApi: analyticsApi);
    _tabController = TabController(length: 2, vsync: this);
    statsController.addListener(_onStatsChanged);
    eventsController.addListener(_onEventsChanged);
    statsController.loadStats();
    eventsController.loadInitial();
  }

  void _onStatsChanged() {
    if (mounted) setState(() {});
  }

  void _onEventsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    statsController.removeListener(_onStatsChanged);
    statsController.dispose();
    eventsController.removeListener(_onEventsChanged);
    eventsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(localizations?.analyticsStatistics ?? "Analytics Statistics");
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Tab(icon: const Icon(Icons.bar_chart), text: localizations?.statistics ?? "Statistics");
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Tab(icon: const Icon(Icons.list), text: localizations?.events ?? "Events");
              },
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatsTab(),
          _buildEventsTab(),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return RefreshIndicator(
      onRefresh: statsController.refresh,
      child: _buildStatsContent(),
    );
  }

  Widget _buildStatsContent() {
    if (statsController.isLoading && statsController.stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (statsController.error != null && statsController.stats == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations?.errorLoadingStatistics ?? "Error loading statistics",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                );
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                statsController.error!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ElevatedButton(
                  onPressed: () => statsController.loadStats(),
                  child: Text(localizations?.retry ?? "Retry"),
                );
              },
            ),
          ],
        ),
      );
    }

    if (statsController.stats == null) {
      return Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return Center(child: Text(localizations?.noStatisticsAvailable ?? "No statistics available"));
        },
      );
    }

    final stats = statsController.stats!;

    return Builder(
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Overall Statistics
            SectionTitleWidget(
              text: localizations?.overallStatistics ?? "Overall Statistics",
            ),
            const SizedBox(height: 12),
            _buildOverallStats(stats.overall),
            const SizedBox(height: 24),
            // Events by Type
            SectionTitleWidget(
              text: localizations?.eventsByType ?? "Events by Type",
            ),
            const SizedBox(height: 12),
            _buildEventsByType(stats.byType),
            const SizedBox(height: 24),
            // Top Recipes
            SectionTitleWidget(
              text: localizations?.topRecipesLast30Days ?? "Top Recipes (Last 30 Days)",
            ),
            const SizedBox(height: 12),
            _buildTopRecipes(stats.topRecipes),
            const SizedBox(height: 24),
            // Daily Events Chart
            SectionTitleWidget(
              text: localizations?.dailyEventsLast30Days ?? "Daily Events (Last 30 Days)",
            ),
            const SizedBox(height: 12),
            _buildDailyEventsChart(stats.dailyEvents),
          ],
        );
      },
    );
  }


  Widget _buildOverallStats(OverallStats overall) {
    return Builder(
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatRow(localizations?.totalEvents ?? "Total Events", overall.totalEvents.toString(), Icons.event),
                const Divider(),
                _buildStatRow(localizations?.uniqueUsers ?? "Unique Users", overall.uniqueUsers.toString(), Icons.people),
                const Divider(),
                _buildStatRow(localizations?.uniqueRecipes ?? "Unique Recipes", overall.uniqueRecipes.toString(), Icons.restaurant),
                const Divider(),
                _buildStatRow(localizations?.last24Hours ?? "Last 24 Hours", overall.eventsLast24h.toString(), Icons.today),
                const Divider(),
                _buildStatRow(localizations?.last7DaysStat ?? "Last 7 Days", overall.eventsLast7d.toString(), Icons.calendar_view_week),
                const Divider(),
                _buildStatRow(localizations?.last30DaysStat ?? "Last 30 Days", overall.eventsLast30d.toString(), Icons.calendar_month),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsByType(List<EventByType> events) {
    if (events.isEmpty) {
      return Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text(localizations?.noEventDataAvailable ?? "No event data available")),
            ),
          );
        },
      );
    }

    return Card(
      child: Column(
        children: events.map((event) {
          final isLast = event == events.last;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatEventType(event.eventType, context),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Builder(
                            builder: (context) {
                              final localizations = AppLocalizations.of(context);
                              return Text(
                                "${localizations?.total ?? "Total"}: ${event.total}",
                                style: Theme.of(context).textTheme.bodySmall,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          event.last24h.toString(),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        Text(
                          "24h",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          event.last7d.toString(),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                        ),
                        Text(
                          "7d",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatEventType(String type, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    switch (type) {
      case "view":
        return localizations?.views ?? "Views";
      case "like":
        return localizations?.likes ?? "Likes";
      case "bookmark":
        return localizations?.bookmarks ?? "Bookmarks";
      case "comment":
        return localizations?.comments ?? "Comments";
      case "search":
        return localizations?.searches ?? "Searches";
      case "share":
        return "Shares";
      case "filter_applied":
        return "Filters Applied";
      default:
        return type.replaceAll("_", " ").split(" ").map((w) => w[0].toUpperCase() + w.substring(1)).join(" ");
    }
  }

  Widget _buildTopRecipes(List<TopRecipe> recipes) {
    if (recipes.isEmpty) {
      return Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text(localizations?.noRecipeDataAvailable ?? "No recipe data available")),
            ),
          );
        },
      );
    }

    return Card(
      child: Column(
        children: recipes.asMap().entries.map((entry) {
          final index = entry.key;
          final recipe = entry.value;
          final isLast = index == recipes.length - 1;
          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    "${index + 1}",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  recipe.recipeTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${recipe.authorDisplayName ?? recipe.authorUsername} • @${recipe.authorUsername}"),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      children: [
                        EngagementStatWidget(
                          icon: Icons.visibility,
                          value: recipe.views,
                          style: EngagementStatStyle.mini,
                        ),
                        EngagementStatWidget(
                          icon: Icons.favorite,
                          value: recipe.likes,
                          style: EngagementStatStyle.mini,
                        ),
                        EngagementStatWidget(
                          icon: Icons.bookmark,
                          value: recipe.bookmarks,
                          style: EngagementStatStyle.mini,
                        ),
                        EngagementStatWidget(
                          icon: Icons.comment,
                          value: recipe.comments,
                          style: EngagementStatStyle.mini,
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      "${recipe.totalEvents} ${localizations?.eventsText ?? "events"}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    );
                  },
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(
                        recipeId: recipe.recipeId,
                        apiClient: widget.apiClient,
                        auth: widget.auth,
                        shoppingListController: widget.shoppingListController,
                      ),
                    ),
                  );
                },
              ),
              if (!isLast) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }


  Widget _buildDailyEventsChart(List<DailyEvent> dailyEvents) {
    if (dailyEvents.isEmpty) {
      return Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text(localizations?.noDailyEventDataAvailable ?? "No daily event data available")),
            ),
          );
        },
      );
    }

    // Simple bar chart representation
    final maxValue = dailyEvents.map((e) => e.total).reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) {
      return Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text(localizations?.noEventsRecorded ?? "No events recorded")),
            ),
          );
        },
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations?.eventTimeline ?? "Event Timeline",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: dailyEvents.length,
                itemBuilder: (context, index) {
                  final event = dailyEvents[index];
                  final height = (event.total / maxValue) * 180;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Tooltip(
                          message: "${formatDate(event.date)}\nTotal: ${event.total}\nViews: ${event.views}\nLikes: ${event.likes}",
                          child: Container(
                            width: 30,
                            height: height,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${event.date.day}/${event.date.month}",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsTab() {
    return RefreshIndicator(
      onRefresh: eventsController.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final metrics = notification.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent - 300) {
              eventsController.loadMore();
            }
          }
          return false;
        },
        child: _buildEventsContent(),
      ),
    );
  }

  Widget _buildEventsContent() {
    if (eventsController.isLoading && eventsController.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (eventsController.error != null && eventsController.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations?.errorLoadingEvents ?? "Error loading events",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                );
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                eventsController.error!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ElevatedButton(
                  onPressed: () => eventsController.loadInitial(),
                  child: Text(localizations?.retry ?? "Retry"),
                );
              },
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Filters - always show, even when empty
        _buildEventFilters(),
        // Events List or Empty State
        Expanded(
          child: eventsController.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_note_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            localizations?.noEventsAvailable ?? "No events available",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                          );
                        },
                      ),
                      if (eventsController.eventTypeFilter != null) ...[
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              localizations?.trySelectingDifferentFilter ?? "Try selecting a different filter",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: eventsController.items.length + (eventsController.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= eventsController.items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final event = eventsController.items[index];
                    return _buildEventItem(event);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEventFilters() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.filters ?? "Filters",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: Text(localizations?.all ?? "All"),
                          selected: eventsController.eventTypeFilter == null,
                          onSelected: (selected) {
                            if (selected) {
                              eventsController.loadInitial();
                            }
                          },
                        ),
                        FilterChip(
                          label: Text(localizations?.views ?? "Views"),
                          selected: eventsController.eventTypeFilter == "view",
                          onSelected: (selected) {
                            eventsController.loadInitial(eventType: selected ? "view" : null);
                          },
                        ),
                        FilterChip(
                          label: Text(localizations?.likes ?? "Likes"),
                          selected: eventsController.eventTypeFilter == "like",
                          onSelected: (selected) {
                            eventsController.loadInitial(eventType: selected ? "like" : null);
                          },
                        ),
                        FilterChip(
                          label: Text(localizations?.bookmarks ?? "Bookmarks"),
                          selected: eventsController.eventTypeFilter == "bookmark",
                          onSelected: (selected) {
                            eventsController.loadInitial(eventType: selected ? "bookmark" : null);
                          },
                        ),
                        FilterChip(
                          label: Text(localizations?.comments ?? "Comments"),
                          selected: eventsController.eventTypeFilter == "comment",
                          onSelected: (selected) {
                            eventsController.loadInitial(eventType: selected ? "comment" : null);
                          },
                        ),
                        FilterChip(
                          label: Text(localizations?.searches ?? "Searches"),
                          selected: eventsController.eventTypeFilter == "search",
                          onSelected: (selected) {
                            eventsController.loadInitial(eventType: selected ? "search" : null);
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem(AnalyticsEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          _getEventIcon(event.eventType),
          color: _getEventColor(event.eventType),
        ),
        title: Text(
          _formatEventType(event.eventType, context),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.userUsername != null)
                  Text("${localizations?.user ?? "User"}: @${event.userUsername}"),
                if (event.recipeTitle != null)
                  Text("${localizations?.recipe ?? "Recipe"}: ${event.recipeTitle}"),
                Text(
                  formatDate(event.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            );
          },
        ),
        trailing: event.recipeId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 16),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(
                        recipeId: event.recipeId!,
                        apiClient: widget.apiClient,
                        auth: widget.auth,
                        shoppingListController: widget.shoppingListController,
                      ),
                    ),
                  );
                },
              )
            : null,
        onTap: event.recipeId != null
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(
                      recipeId: event.recipeId!,
                      apiClient: widget.apiClient,
                      auth: widget.auth,
                      shoppingListController: widget.shoppingListController,
                    ),
                  ),
                );
              }
            : null,
      ),
    );
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case "view":
        return Icons.visibility;
      case "like":
        return Icons.favorite;
      case "bookmark":
        return Icons.bookmark;
      case "comment":
        return Icons.comment;
      case "search":
        return Icons.search;
      case "share":
        return Icons.share;
      default:
        return Icons.event;
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case "view":
        return Colors.blue;
      case "like":
        return Colors.red;
      case "bookmark":
        return Colors.purple;
      case "comment":
        return Colors.orange;
      case "search":
        return Colors.green;
      case "share":
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
