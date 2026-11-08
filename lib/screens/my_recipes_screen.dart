import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../feed/feed_models.dart";
import "../localization/app_localizations.dart";
import "../recipes/recipe_detail_screen.dart";
import "../shopping/shopping_list_controller.dart";
import "../theme/app_tokens.dart";
import "../users/liked_recipes_controller.dart";
import "../users/user_api.dart";
import "../users/user_models.dart";
import "../users/user_recipes_controller.dart";
import "../utils/paginated_list_controller.dart";
import "../widgets/common/profile_stats_card.dart";
import "../widgets/common/recipe_grid_tile.dart";
import "../widgets/common/underline_tab.dart";
import "../widgets/empty_state_widget.dart";

/// Your full recipe list, the recipes you liked, and the likes your recipes
/// received. Opened from the Profile tab ("See all" and the recipes stat).
class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({
    super.key,
    required this.auth,
    required this.apiClient,
    required this.shoppingListController,
    required this.username,
    this.initialTab = 0,
  });

  final AuthController auth;
  final ApiClient apiClient;
  final ShoppingListController shoppingListController;
  final String username;

  /// 0 = your recipes, 1 = liked.
  final int initialTab;

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final UserRecipesController _mine;
  late final LikedRecipesController _liked;

  /// Source of the summary numbers; null while loading.
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _tabController.addListener(_onTabChanged);
    final userApi = UserApi(widget.apiClient);
    _mine = UserRecipesController(userApi: userApi, username: widget.username);
    _liked = LikedRecipesController(userApi: userApi);
    _loadSummary();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _mine.dispose();
    _liked.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSummary() async {
    try {
      final profile = await UserApi(widget.apiClient).getUserProfile(widget.username);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  /// Like the old own-profile grid, the list isn't reloaded on return; pull
  /// to refresh picks up recipes deleted or unliked on the detail screen.
  void _openRecipe(FeedItem recipe) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RecipeDetailScreen(
        recipeId: recipe.id,
        apiClient: widget.apiClient,
        auth: widget.auth,
        shoppingListController: widget.shoppingListController,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final tabs = [l?.myRecipes ?? "My recipes", l?.profileTabLiked ?? "Liked"];

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: t.ink),
        title: Text(
          l?.recipes ?? "Recipes",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.ink),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ProfileStatsCard(
              stats: [
                ProfileStat(value: _profile?.recipesCount, label: l?.recipes ?? "Recipes"),
                ProfileStat(value: _profile?.totalLikesCount, label: l?.totalLikes ?? "Total Likes"),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: UnderlineTab(
                      label: tabs[i],
                      isActive: _tabController.index == i,
                      onTap: () => _tabController.animateTo(i),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RecipeListPage(
                  controller: _mine,
                  onRefreshSummary: _loadSummary,
                  onOpen: _openRecipe,
                  emptyIcon: Icons.restaurant_menu_outlined,
                  emptyTitle: l?.noRecipesYet ?? "No recipes yet",
                  emptyDescription: l?.createYourFirstRecipe ?? "Create your first recipe!",
                ),
                _RecipeListPage(
                  controller: _liked,
                  onRefreshSummary: _loadSummary,
                  onOpen: _openRecipe,
                  emptyIcon: Icons.favorite_border,
                  emptyTitle: l?.noLikedRecipesYet ?? "No liked recipes yet",
                  emptyDescription: l?.likedRecipesEmptyDescription ?? "Recipes you like will appear here",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tab's 2-column grid with infinite scroll and pull to refresh. Kept
/// alive so each tab keeps its scroll position; loads the first time shown.
class _RecipeListPage extends StatefulWidget {
  const _RecipeListPage({
    required this.controller,
    required this.onRefreshSummary,
    required this.onOpen,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyDescription,
  });

  final PaginatedListController<FeedItem> controller;
  final Future<void> Function() onRefreshSummary;
  final ValueChanged<FeedItem> onOpen;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyDescription;

  @override
  State<_RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<_RecipeListPage> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _scrollController.addListener(_onScroll);
    if (widget.controller.items.isEmpty && !widget.controller.isLoading) {
      widget.controller.loadInitial();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Same trigger as ProfileScreen's grid: load more within 300px of the end.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 300) return;
    widget.controller.loadMore();
  }

  /// Empty, error and loading states still need to scroll for pull to refresh.
  Widget _fill(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: constraints.maxHeight, child: child)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppTokens.of(context);
    final l = AppLocalizations.of(context);
    final controller = widget.controller;
    final items = controller.items;

    final Widget body;
    if (controller.isLoading && items.isEmpty) {
      body = _fill(Center(child: CircularProgressIndicator(color: t.brandInk)));
    } else if (controller.error != null && items.isEmpty) {
      body = _fill(Center(
        child: TextButton(
          onPressed: controller.loadInitial,
          style: TextButton.styleFrom(foregroundColor: t.brandInk),
          child: Text(l?.retry ?? "Retry"),
        ),
      ));
    } else if (items.isEmpty) {
      body = _fill(Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyStateWidget(
          icon: widget.emptyIcon,
          title: widget.emptyTitle,
          description: widget.emptyDescription,
        ),
      ));
    } else {
      final rows = (items.length + 1) ~/ 2;
      body = ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: rows + (controller.isLoadingMore ? 1 : 0),
        itemBuilder: (context, row) {
          if (row >= rows) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: t.brandInk)),
            );
          }
          final i = row * 2;
          return Padding(
            padding: EdgeInsets.only(bottom: row < rows - 1 ? 16 : 0),
            child: RecipeGridRow(
              left: items[i],
              right: i + 1 < items.length ? items[i + 1] : null,
              onTap: widget.onOpen,
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      color: t.brandInk,
      onRefresh: () => Future.wait([controller.refresh(), widget.onRefreshSummary()]),
      child: body,
    );
  }
}
