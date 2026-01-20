import "package:flutter/material.dart";

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale("en"),
    Locale("ka"), // Georgian
  ];

  // App title
  String get appTitle => _localizedValues[locale.languageCode]?["appTitle"] ?? "CookBook";

  // Auth screens
  String get login => _localizedValues[locale.languageCode]?["login"] ?? "Login";
  String get signUp => _localizedValues[locale.languageCode]?["signUp"] ?? "Sign up";
  String get email => _localizedValues[locale.languageCode]?["email"] ?? "Email";
  String get password => _localizedValues[locale.languageCode]?["password"] ?? "Password";
  String get createAccount => _localizedValues[locale.languageCode]?["createAccount"] ?? "Create account";
  String get username => _localizedValues[locale.languageCode]?["username"] ?? "Username";
  String get displayName => _localizedValues[locale.languageCode]?["displayName"] ?? "Display name (optional)";
  String get passwordMin => _localizedValues[locale.languageCode]?["passwordMin"] ?? "Password (min 8)";

  // Navigation & Tooltips
  String get menu => _localizedValues[locale.languageCode]?["menu"] ?? "Menu";
  String get createRecipe => _localizedValues[locale.languageCode]?["createRecipe"] ?? "Create Recipe";
  String get notifications => _localizedValues[locale.languageCode]?["notifications"] ?? "Notifications";
  String get markAllRead => _localizedValues[locale.languageCode]?["markAllRead"] ?? "Mark all read";
  String get allNotifications => _localizedValues[locale.languageCode]?["allNotifications"] ?? "All notifications";
  String get unreadOnly => _localizedValues[locale.languageCode]?["unreadOnly"] ?? "Unread only";
  String get search => _localizedValues[locale.languageCode]?["search"] ?? "Search";
  String get logout => _localizedValues[locale.languageCode]?["logout"] ?? "Logout";

  // Common UI
  String get feed => _localizedValues[locale.languageCode]?["feed"] ?? "Feed";
  String get recent => _localizedValues[locale.languageCode]?["recent"] ?? "Recent";
  String get top => _localizedValues[locale.languageCode]?["top"] ?? "Top";
  String get sortBy => _localizedValues[locale.languageCode]?["sortBy"] ?? "Sort by";
  String get retry => _localizedValues[locale.languageCode]?["retry"] ?? "Retry";
  String get cancel => _localizedValues[locale.languageCode]?["cancel"] ?? "Cancel";
  String get delete => _localizedValues[locale.languageCode]?["delete"] ?? "Delete";
  String get add => _localizedValues[locale.languageCode]?["add"] ?? "Add";
  String get save => _localizedValues[locale.languageCode]?["save"] ?? "Save";
  String get apply => _localizedValues[locale.languageCode]?["apply"] ?? "Apply";
  String get clearAll => _localizedValues[locale.languageCode]?["clearAll"] ?? "Clear All";
  String get applyFilters => _localizedValues[locale.languageCode]?["applyFilters"] ?? "Apply Filters";

  // Feed Scopes (Drawer menu)
  String get global => _localizedValues[locale.languageCode]?["global"] ?? "Global";
  String get seeRecipesFromEveryone => _localizedValues[locale.languageCode]?["seeRecipesFromEveryone"] ?? "See recipes from everyone";
  String get following => _localizedValues[locale.languageCode]?["following"] ?? "Following";
  String get seeRecipesFromPeopleYouFollow => _localizedValues[locale.languageCode]?["seeRecipesFromPeopleYouFollow"] ?? "See recipes from people you follow";
  String get logInToSeeFollowingFeed => _localizedValues[locale.languageCode]?["logInToSeeFollowingFeed"] ?? "Log in to see Following feed";
  String get popular => _localizedValues[locale.languageCode]?["popular"] ?? "Popular";
  String get mostPopularRecipes => _localizedValues[locale.languageCode]?["mostPopularRecipes"] ?? "Most popular recipes";
  String get trending => _localizedValues[locale.languageCode]?["trending"] ?? "Trending";
  String get trendingNow => _localizedValues[locale.languageCode]?["trendingNow"] ?? "Trending now";
  String get savedRecipes => _localizedValues[locale.languageCode]?["savedRecipes"] ?? "Saved Recipes";
  String get viewYourBookmarkedRecipes => _localizedValues[locale.languageCode]?["viewYourBookmarkedRecipes"] ?? "View your bookmarked recipes";
  String get analyticsStatistics => _localizedValues[locale.languageCode]?["analyticsStatistics"] ?? "Analytics Statistics";
  String get viewTrackingStatistics => _localizedValues[locale.languageCode]?["viewTrackingStatistics"] ?? "View tracking statistics";
  String get profile => _localizedValues[locale.languageCode]?["profile"] ?? "Profile";
  String get viewProfile => _localizedValues[locale.languageCode]?["viewProfile"] ?? "View your profile";

  // Time Periods
  String get allTime => _localizedValues[locale.languageCode]?["allTime"] ?? "All Time";
  String get last30Days => _localizedValues[locale.languageCode]?["last30Days"] ?? "Last 30 Days";
  String get last7Days => _localizedValues[locale.languageCode]?["last7Days"] ?? "Last 7 Days";
  String get timePeriod => _localizedValues[locale.languageCode]?["timePeriod"] ?? "Time period";
  String get days => _localizedValues[locale.languageCode]?["days"] ?? "Days";
  String get windowDays => _localizedValues[locale.languageCode]?["windowDays"] ?? "Window days";
  String get oneDay => _localizedValues[locale.languageCode]?["oneDay"] ?? "1 day";
  String get threeDays => _localizedValues[locale.languageCode]?["threeDays"] ?? "3 days";
  String get sevenDays => _localizedValues[locale.languageCode]?["sevenDays"] ?? "7 days";
  String get fourteenDays => _localizedValues[locale.languageCode]?["fourteenDays"] ?? "14 days";
  String get thirtyDays => _localizedValues[locale.languageCode]?["thirtyDays"] ?? "30 days";
  String get listView => _localizedValues[locale.languageCode]?["listView"] ?? "List View";
  String get fullScreenView => _localizedValues[locale.languageCode]?["fullScreenView"] ?? "Full Screen View";

  // Empty States (user-visible messages)
  String get noMoreItems => _localizedValues[locale.languageCode]?["noMoreItems"] ?? "No more items";
  String get noSavedRecipes => _localizedValues[locale.languageCode]?["noSavedRecipes"] ?? "No saved recipes";
  String get startBookmarkingRecipes => _localizedValues[locale.languageCode]?["startBookmarkingRecipes"] ?? "Start bookmarking recipes to save them here";
  String get noStatisticsAvailable => _localizedValues[locale.languageCode]?["noStatisticsAvailable"] ?? "No statistics available";
  String get noRecipesFound => _localizedValues[locale.languageCode]?["noRecipesFound"] ?? "No recipes found";
  String get tryDifferentSearch => _localizedValues[locale.languageCode]?["tryDifferentSearch"] ?? "Try a different search term";
  String get noUsersFound => _localizedValues[locale.languageCode]?["noUsersFound"] ?? "No users found";
  String get notLoggedIn => _localizedValues[locale.languageCode]?["notLoggedIn"] ?? "Not logged in";
  String get errorLoadingStatistics => _localizedValues[locale.languageCode]?["errorLoadingStatistics"] ?? "Error loading statistics";
  String get noEventDataAvailable => _localizedValues[locale.languageCode]?["noEventDataAvailable"] ?? "No event data available";
  String get noRecipeDataAvailable => _localizedValues[locale.languageCode]?["noRecipeDataAvailable"] ?? "No recipe data available";
  String get noDailyEventDataAvailable => _localizedValues[locale.languageCode]?["noDailyEventDataAvailable"] ?? "No daily event data available";
  String get noEventsRecorded => _localizedValues[locale.languageCode]?["noEventsRecorded"] ?? "No events recorded";
  String get noEventsAvailable => _localizedValues[locale.languageCode]?["noEventsAvailable"] ?? "No events available";
  String get trySelectingDifferentFilter => _localizedValues[locale.languageCode]?["trySelectingDifferentFilter"] ?? "Try selecting a different filter";
  String get errorLoadingEvents => _localizedValues[locale.languageCode]?["errorLoadingEvents"] ?? "Error loading events";
  String get justNow => _localizedValues[locale.languageCode]?["justNow"] ?? "Just now";
  String get minutesAgo => _localizedValues[locale.languageCode]?["minutesAgo"] ?? "m ago";
  String get hoursAgo => _localizedValues[locale.languageCode]?["hoursAgo"] ?? "h ago";
  String get yesterday => _localizedValues[locale.languageCode]?["yesterday"] ?? "Yesterday";
  String get daysAgo => _localizedValues[locale.languageCode]?["daysAgo"] ?? "d ago";
  String get error => _localizedValues[locale.languageCode]?["error"] ?? "Error";
  String get dismiss => _localizedValues[locale.languageCode]?["dismiss"] ?? "Dismiss";
  String get unableToConnect => _localizedValues[locale.languageCode]?["unableToConnect"] ?? "Unable to connect to the server. Please check your internet connection and try again.";
  String get requestTimedOut => _localizedValues[locale.languageCode]?["requestTimedOut"] ?? "Request timed out. Please try again.";
  String get connectionInterrupted => _localizedValues[locale.languageCode]?["connectionInterrupted"] ?? "Connection was interrupted. Please try again.";
  String get needToLogIn => _localizedValues[locale.languageCode]?["needToLogIn"] ?? "You need to log in to perform this action.";
  String get noPermission => _localizedValues[locale.languageCode]?["noPermission"] ?? "You don't have permission to perform this action.";
  String get itemNotFound => _localizedValues[locale.languageCode]?["itemNotFound"] ?? "The requested item could not be found.";
  String get invalidInput => _localizedValues[locale.languageCode]?["invalidInput"] ?? "Invalid input. Please check your data and try again.";
  String get invalidRequest => _localizedValues[locale.languageCode]?["invalidRequest"] ?? "Invalid request. Please check your input and try again.";
  String get actionConflict => _localizedValues[locale.languageCode]?["actionConflict"] ?? "This action conflicts with the current state. Please refresh and try again.";
  String get fileTooLarge => _localizedValues[locale.languageCode]?["fileTooLarge"] ?? "The file is too large. Please use a smaller file.";
  String get invalidData => _localizedValues[locale.languageCode]?["invalidData"] ?? "Invalid data provided. Please check your input.";
  String get tooManyRequests => _localizedValues[locale.languageCode]?["tooManyRequests"] ?? "Too many requests. Please wait a moment and try again.";
  String get serverError => _localizedValues[locale.languageCode]?["serverError"] ?? "Server error. Please try again later.";
  String get errorOccurred => _localizedValues[locale.languageCode]?["errorOccurred"] ?? "An error occurred. Please try again.";
  String get minTimeCannotBeGreater => _localizedValues[locale.languageCode]?["minTimeCannotBeGreater"] ?? "Minimum time cannot be greater than maximum time";
  String get minCookingTimeCannotBeGreater => _localizedValues[locale.languageCode]?["minCookingTimeCannotBeGreater"] ?? "Minimum cooking time cannot be greater than maximum time";
  String get minCookingTimeMustBeValidNumber => _localizedValues[locale.languageCode]?["minCookingTimeMustBeValidNumber"] ?? "Minimum cooking time must be a valid number";
  String get maxCookingTimeMustBeValidNumber => _localizedValues[locale.languageCode]?["maxCookingTimeMustBeValidNumber"] ?? "Maximum cooking time must be a valid number";
  String get pleaseAddAtLeastOneIngredient => _localizedValues[locale.languageCode]?["pleaseAddAtLeastOneIngredient"] ?? "Please add at least one ingredient";
  String get pleaseAddAtLeastOneStep => _localizedValues[locale.languageCode]?["pleaseAddAtLeastOneStep"] ?? "Please add at least one step";
  String ingredientNameRequired(int index) => _localizedValues[locale.languageCode]?["ingredientNameRequired"]?.replaceAll("{index}", "${index + 1}") ?? "Ingredient ${index + 1}: name is required";
  String stepInstructionRequired(int index) => _localizedValues[locale.languageCode]?["stepInstructionRequired"]?.replaceAll("{index}", "${index + 1}") ?? "Step ${index + 1}: instruction is required";

  // Profile
  String get addAvatar => _localizedValues[locale.languageCode]?["addAvatar"] ?? "Add Avatar";
  String get updateAvatar => _localizedValues[locale.languageCode]?["updateAvatar"] ?? "Update Avatar";
  String get deleteAvatar => _localizedValues[locale.languageCode]?["deleteAvatar"] ?? "Delete Avatar";
  String get areYouSureDeleteAvatar => _localizedValues[locale.languageCode]?["areYouSureDeleteAvatar"] ?? "Are you sure you want to remove your avatar?";
  String get followers => _localizedValues[locale.languageCode]?["followers"] ?? "Followers";
  String get followingTitle => _localizedValues[locale.languageCode]?["followingTitle"] ?? "Following";
  String get private => _localizedValues[locale.languageCode]?["private"] ?? "Private";
  String get thisUsersFollowersListIsPrivate => _localizedValues[locale.languageCode]?["thisUsersFollowersListIsPrivate"] ?? "This user's followers list is private";
  String get noFollowers => _localizedValues[locale.languageCode]?["noFollowers"] ?? "No followers";
  String get thisUserDoesntHaveAnyFollowersYet => _localizedValues[locale.languageCode]?["thisUserDoesntHaveAnyFollowersYet"] ?? "This user doesn't have any followers yet";
  String get thisUsersFollowingListIsPrivate => _localizedValues[locale.languageCode]?["thisUsersFollowingListIsPrivate"] ?? "This user's following list is private";
  String get notFollowingAnyone => _localizedValues[locale.languageCode]?["notFollowingAnyone"] ?? "Not following anyone";
  String get thisUserIsntFollowingAnyoneYet => _localizedValues[locale.languageCode]?["thisUserIsntFollowingAnyoneYet"] ?? "This user isn't following anyone yet";

  // Create Recipe Form
  String get title => _localizedValues[locale.languageCode]?["title"] ?? "Title";
  String get enterRecipeTitle => _localizedValues[locale.languageCode]?["enterRecipeTitle"] ?? "Enter recipe title";
  String get description => _localizedValues[locale.languageCode]?["description"] ?? "Description";
  String get describeYourRecipe => _localizedValues[locale.languageCode]?["describeYourRecipe"] ?? "Describe your recipe";
  String get cuisine => _localizedValues[locale.languageCode]?["cuisine"] ?? "Cuisine";
  String get cuisineExample => _localizedValues[locale.languageCode]?["cuisineExample"] ?? "e.g., Italian, Mexican, Asian";
  String get minTimeMinutes => _localizedValues[locale.languageCode]?["minTimeMinutes"] ?? "Min Time (minutes)";
  String get maxTimeMinutes => _localizedValues[locale.languageCode]?["maxTimeMinutes"] ?? "Max Time (minutes)";
  String get difficulty => _localizedValues[locale.languageCode]?["difficulty"] ?? "Difficulty";
  String get easy => _localizedValues[locale.languageCode]?["easy"] ?? "Easy";
  String get medium => _localizedValues[locale.languageCode]?["medium"] ?? "Medium";
  String get hard => _localizedValues[locale.languageCode]?["hard"] ?? "Hard";
  String get addTag => _localizedValues[locale.languageCode]?["addTag"] ?? "Add a tag";
  String get tags => _localizedValues[locale.languageCode]?["tags"] ?? "Tags";
  String get ingredients => _localizedValues[locale.languageCode]?["ingredients"] ?? "Ingredients";
  String get cookingTimeMinutes => _localizedValues[locale.languageCode]?["cookingTimeMinutes"] ?? "Cooking Time (minutes)";
  String get min => _localizedValues[locale.languageCode]?["min"] ?? "Min";
  String get max => _localizedValues[locale.languageCode]?["max"] ?? "Max";
  String get quantity => _localizedValues[locale.languageCode]?["quantity"] ?? "Quantity";
  String get quantityExample => _localizedValues[locale.languageCode]?["quantityExample"] ?? "e.g., 2";
  String get unit => _localizedValues[locale.languageCode]?["unit"] ?? "Unit";
  String get unitExample => _localizedValues[locale.languageCode]?["unitExample"] ?? "e.g., cups";
  String get ingredient => _localizedValues[locale.languageCode]?["ingredient"] ?? "Ingredient";
  String get ingredientExample => _localizedValues[locale.languageCode]?["ingredientExample"] ?? "e.g., flour";
  String get instruction => _localizedValues[locale.languageCode]?["instruction"] ?? "Instruction";
  String get images => _localizedValues[locale.languageCode]?["images"] ?? "Images";
  String get describeThisStep => _localizedValues[locale.languageCode]?["describeThisStep"] ?? "Describe this step";
  String get createRecipeTitle => _localizedValues[locale.languageCode]?["createRecipeTitle"] ?? "Create Recipe";
  String get editRecipe => _localizedValues[locale.languageCode]?["editRecipe"] ?? "Edit Recipe";

  // Search
  String get switchToUsers => _localizedValues[locale.languageCode]?["switchToUsers"] ?? "Switch to Users";
  String get switchToRecipes => _localizedValues[locale.languageCode]?["switchToRecipes"] ?? "Switch to Recipes";
  String get filters => _localizedValues[locale.languageCode]?["filters"] ?? "Filters";
  String get searchRecipes => _localizedValues[locale.languageCode]?["searchRecipes"] ?? "Search recipes...";
  String get searchUsers => _localizedValues[locale.languageCode]?["searchUsers"] ?? "Search users...";

  // Analytics
  String get statistics => _localizedValues[locale.languageCode]?["statistics"] ?? "Statistics";
  String get events => _localizedValues[locale.languageCode]?["events"] ?? "Events";
  String get overallStatistics => _localizedValues[locale.languageCode]?["overallStatistics"] ?? "Overall Statistics";
  String get eventsByType => _localizedValues[locale.languageCode]?["eventsByType"] ?? "Events by Type";
  String get topRecipesLast30Days => _localizedValues[locale.languageCode]?["topRecipesLast30Days"] ?? "Top Recipes (Last 30 Days)";
  String get dailyEventsLast30Days => _localizedValues[locale.languageCode]?["dailyEventsLast30Days"] ?? "Daily Events (Last 30 Days)";
  String get totalEvents => _localizedValues[locale.languageCode]?["totalEvents"] ?? "Total Events";
  String get uniqueUsers => _localizedValues[locale.languageCode]?["uniqueUsers"] ?? "Unique Users";
  String get uniqueRecipes => _localizedValues[locale.languageCode]?["uniqueRecipes"] ?? "Unique Recipes";
  String get last24Hours => _localizedValues[locale.languageCode]?["last24Hours"] ?? "Last 24 Hours";
  String get last7DaysStat => _localizedValues[locale.languageCode]?["last7DaysStat"] ?? "Last 7 Days";
  String get last30DaysStat => _localizedValues[locale.languageCode]?["last30DaysStat"] ?? "Last 30 Days";
  String get total => _localizedValues[locale.languageCode]?["total"] ?? "Total";
  String get eventTimeline => _localizedValues[locale.languageCode]?["eventTimeline"] ?? "Event Timeline";
  String get views => _localizedValues[locale.languageCode]?["views"] ?? "Views";
  String get likes => _localizedValues[locale.languageCode]?["likes"] ?? "Likes";
  String get bookmarks => _localizedValues[locale.languageCode]?["bookmarks"] ?? "Bookmarks";
  String get comments => _localizedValues[locale.languageCode]?["comments"] ?? "Comments";
  String get searches => _localizedValues[locale.languageCode]?["searches"] ?? "Searches";
  String get all => _localizedValues[locale.languageCode]?["all"] ?? "All";
  String get user => _localizedValues[locale.languageCode]?["user"] ?? "User";
  String get recipe => _localizedValues[locale.languageCode]?["recipe"] ?? "Recipe";
  String get eventsText => _localizedValues[locale.languageCode]?["eventsText"] ?? "events";

  // Recipe Detail
  String get deleteRecipe => _localizedValues[locale.languageCode]?["deleteRecipe"] ?? "Delete Recipe";
  String get areYouSureDeleteRecipe => _localizedValues[locale.languageCode]?["areYouSureDeleteRecipe"] ?? "Are you sure you want to delete";
  String get thisActionCannotBeUndone => _localizedValues[locale.languageCode]?["thisActionCannotBeUndone"] ?? "This action cannot be undone.";
  String get recipeDeletedSuccessfully => _localizedValues[locale.languageCode]?["recipeDeletedSuccessfully"] ?? "Recipe deleted successfully";
  String get notFound => _localizedValues[locale.languageCode]?["notFound"] ?? "Not found";
  String get somethingWentWrong => _localizedValues[locale.languageCode]?["somethingWentWrong"] ?? "Something went wrong";
  String get steps => _localizedValues[locale.languageCode]?["steps"] ?? "Steps";
  String get noStepsYet => _localizedValues[locale.languageCode]?["noStepsYet"] ?? "No steps yet. Add one to get started!";

  // Language
  String get english => _localizedValues[locale.languageCode]?["english"] ?? "English";
  String get georgian => _localizedValues[locale.languageCode]?["georgian"] ?? "Georgian";
  String get language => _localizedValues[locale.languageCode]?["language"] ?? "Language";
  String get changeAppLanguage => _localizedValues[locale.languageCode]?["changeAppLanguage"] ?? "Change app language";

  // Settings
  String get settings => _localizedValues[locale.languageCode]?["settings"] ?? "Settings";
  String get appearance => _localizedValues[locale.languageCode]?["appearance"] ?? "Appearance";
  String get themeMode => _localizedValues[locale.languageCode]?["themeMode"] ?? "Theme Mode";
  String get system => _localizedValues[locale.languageCode]?["system"] ?? "System";
  String get light => _localizedValues[locale.languageCode]?["light"] ?? "Light";
  String get dark => _localizedValues[locale.languageCode]?["dark"] ?? "Dark";
  String get account => _localizedValues[locale.languageCode]?["account"] ?? "Account";
  String get about => _localizedValues[locale.languageCode]?["about"] ?? "About";
  String get version => _localizedValues[locale.languageCode]?["version"] ?? "Version";
  String get followSystemTheme => _localizedValues[locale.languageCode]?["followSystemTheme"] ?? "Follow system theme";
  String get lightTheme => _localizedValues[locale.languageCode]?["lightTheme"] ?? "Light theme";
  String get darkTheme => _localizedValues[locale.languageCode]?["darkTheme"] ?? "Dark theme";
  String get englishLanguage => _localizedValues[locale.languageCode]?["englishLanguage"] ?? "English";
  String get georgianLanguage => _localizedValues[locale.languageCode]?["georgianLanguage"] ?? "ქართული";
  String get helpAndSupport => _localizedValues[locale.languageCode]?["helpAndSupport"] ?? "Help & Support";
  String get termsAndPrivacy => _localizedValues[locale.languageCode]?["termsAndPrivacy"] ?? "Terms & Privacy";
  String get termsOfService => _localizedValues[locale.languageCode]?["termsOfService"] ?? "Terms of Service";
  String get privacyPolicy => _localizedValues[locale.languageCode]?["privacyPolicy"] ?? "Privacy Policy";

  static const Map<String, Map<String, String>> _localizedValues = {
    "en": {
      "appTitle": "CookBook",
      "login": "Login",
      "signUp": "Sign up",
      "email": "Email",
      "password": "Password",
      "createAccount": "Create account",
      "username": "Username",
      "displayName": "Display name (optional)",
      "passwordMin": "Password (min 8)",
      "menu": "Menu",
      "createRecipe": "Create Recipe",
      "notifications": "Notifications",
      "markAllRead": "Mark all read",
      "allNotifications": "All notifications",
      "unreadOnly": "Unread only",
      "search": "Search",
      "logout": "Logout",
      "feed": "Feed",
      "recent": "Recent",
      "top": "Top",
      "sortBy": "Sort by",
      "retry": "Retry",
      "cancel": "Cancel",
      "delete": "Delete",
      "add": "Add",
      "save": "Save",
      "apply": "Apply",
      "clearAll": "Clear All",
      "applyFilters": "Apply Filters",
      "global": "Global",
      "seeRecipesFromEveryone": "See recipes from everyone",
      "following": "Following",
      "seeRecipesFromPeopleYouFollow": "See recipes from people you follow",
      "logInToSeeFollowingFeed": "Log in to see Following feed",
      "popular": "Popular",
      "mostPopularRecipes": "Most popular recipes",
      "trending": "Trending",
      "trendingNow": "Trending now",
      "savedRecipes": "Saved Recipes",
      "viewYourBookmarkedRecipes": "View your bookmarked recipes",
      "analyticsStatistics": "Analytics Statistics",
      "viewTrackingStatistics": "View tracking statistics",
      "profile": "Profile",
      "viewProfile": "View your profile",
      "allTime": "All Time",
      "last30Days": "Last 30 Days",
      "last7Days": "Last 7 Days",
      "timePeriod": "Time period",
      "days": "Days",
      "windowDays": "Window days",
      "oneDay": "1 day",
      "threeDays": "3 days",
      "sevenDays": "7 days",
      "fourteenDays": "14 days",
      "thirtyDays": "30 days",
      "listView": "List View",
      "fullScreenView": "Full Screen View",
      "noMoreItems": "No more items",
      "noSavedRecipes": "No saved recipes",
      "startBookmarkingRecipes": "Start bookmarking recipes to save them here",
      "noStatisticsAvailable": "No statistics available",
      "noRecipesFound": "No recipes found",
      "tryDifferentSearch": "Try a different search term",
      "noUsersFound": "No users found",
      "notLoggedIn": "Not logged in",
      "errorLoadingStatistics": "Error loading statistics",
      "noEventDataAvailable": "No event data available",
      "noRecipeDataAvailable": "No recipe data available",
      "noDailyEventDataAvailable": "No daily event data available",
      "noEventsRecorded": "No events recorded",
      "noEventsAvailable": "No events available",
      "trySelectingDifferentFilter": "Try selecting a different filter",
      "errorLoadingEvents": "Error loading events",
      "justNow": "Just now",
      "minutesAgo": "m ago",
      "hoursAgo": "h ago",
      "yesterday": "Yesterday",
      "daysAgo": "d ago",
      "error": "Error",
      "addAvatar": "Add Avatar",
      "updateAvatar": "Update Avatar",
      "deleteAvatar": "Delete Avatar",
      "areYouSureDeleteAvatar": "Are you sure you want to remove your avatar?",
      "followers": "Followers",
      "followingTitle": "Following",
      "private": "Private",
      "thisUsersFollowersListIsPrivate": "This user's followers list is private",
      "noFollowers": "No followers",
      "thisUserDoesntHaveAnyFollowersYet": "This user doesn't have any followers yet",
      "thisUsersFollowingListIsPrivate": "This user's following list is private",
      "notFollowingAnyone": "Not following anyone",
      "thisUserIsntFollowingAnyoneYet": "This user isn't following anyone yet",
      "title": "Title",
      "enterRecipeTitle": "Enter recipe title",
      "description": "Description",
      "describeYourRecipe": "Describe your recipe",
      "cuisine": "Cuisine",
      "cuisineExample": "e.g., Italian, Mexican, Asian",
      "minTimeMinutes": "Min Time (minutes)",
      "maxTimeMinutes": "Max Time (minutes)",
      "difficulty": "Difficulty",
      "easy": "Easy",
      "medium": "Medium",
      "hard": "Hard",
      "addTag": "Add a tag",
      "tags": "Tags",
      "ingredients": "Ingredients",
      "cookingTimeMinutes": "Cooking Time (minutes)",
      "min": "Min",
      "max": "Max",
      "quantity": "Quantity",
      "quantityExample": "e.g., 2",
      "unit": "Unit",
      "unitExample": "e.g., cups",
      "ingredient": "Ingredient",
      "ingredientExample": "e.g., flour",
      "instruction": "Instruction",
      "describeThisStep": "Describe this step",
      "images": "Images",
      "createRecipeTitle": "Create Recipe",
      "editRecipe": "Edit Recipe",
      "switchToUsers": "Switch to Users",
      "switchToRecipes": "Switch to Recipes",
      "filters": "Filters",
      "searchRecipes": "Search recipes...",
      "searchUsers": "Search users...",
      "statistics": "Statistics",
      "events": "Events",
      "overallStatistics": "Overall Statistics",
      "eventsByType": "Events by Type",
      "topRecipesLast30Days": "Top Recipes (Last 30 Days)",
      "dailyEventsLast30Days": "Daily Events (Last 30 Days)",
      "totalEvents": "Total Events",
      "uniqueUsers": "Unique Users",
      "uniqueRecipes": "Unique Recipes",
      "last24Hours": "Last 24 Hours",
      "last7DaysStat": "Last 7 Days",
      "last30DaysStat": "Last 30 Days",
      "total": "Total",
      "eventTimeline": "Event Timeline",
      "views": "Views",
      "likes": "Likes",
      "bookmarks": "Bookmarks",
      "comments": "Comments",
      "searches": "Searches",
      "all": "All",
      "user": "User",
      "recipe": "Recipe",
      "eventsText": "events",
      "english": "English",
      "georgian": "Georgian",
      "language": "Language",
      "changeAppLanguage": "Change app language",
      "deleteRecipe": "Delete Recipe",
      "areYouSureDeleteRecipe": "Are you sure you want to delete",
      "thisActionCannotBeUndone": "This action cannot be undone.",
      "recipeDeletedSuccessfully": "Recipe deleted successfully",
      "notFound": "Not found",
      "somethingWentWrong": "Something went wrong",
      "steps": "Steps",
      "noStepsYet": "No steps yet. Add one to get started!",
      "settings": "Settings",
      "appearance": "Appearance",
      "themeMode": "Theme Mode",
      "system": "System",
      "light": "Light",
      "dark": "Dark",
      "account": "Account",
      "about": "About",
      "version": "Version",
      "followSystemTheme": "Follow system theme",
      "lightTheme": "Light theme",
      "darkTheme": "Dark theme",
      "englishLanguage": "English",
      "georgianLanguage": "ქართული",
      "helpAndSupport": "Help & Support",
      "termsAndPrivacy": "Terms & Privacy",
      "termsOfService": "Terms of Service",
      "privacyPolicy": "Privacy Policy",
      "dismiss": "Dismiss",
      "unableToConnect": "Unable to connect to the server. Please check your internet connection and try again.",
      "requestTimedOut": "Request timed out. Please try again.",
      "connectionInterrupted": "Connection was interrupted. Please try again.",
      "needToLogIn": "You need to log in to perform this action.",
      "noPermission": "You don't have permission to perform this action.",
      "itemNotFound": "The requested item could not be found.",
      "invalidInput": "Invalid input. Please check your data and try again.",
      "invalidRequest": "Invalid request. Please check your input and try again.",
      "actionConflict": "This action conflicts with the current state. Please refresh and try again.",
      "fileTooLarge": "The file is too large. Please use a smaller file.",
      "invalidData": "Invalid data provided. Please check your input.",
      "tooManyRequests": "Too many requests. Please wait a moment and try again.",
      "serverError": "Server error. Please try again later.",
      "errorOccurred": "An error occurred. Please try again.",
      "minTimeCannotBeGreater": "Minimum time cannot be greater than maximum time",
      "minCookingTimeCannotBeGreater": "Minimum cooking time cannot be greater than maximum time",
      "minCookingTimeMustBeValidNumber": "Minimum cooking time must be a valid number",
      "maxCookingTimeMustBeValidNumber": "Maximum cooking time must be a valid number",
      "pleaseAddAtLeastOneIngredient": "Please add at least one ingredient",
      "pleaseAddAtLeastOneStep": "Please add at least one step",
      "ingredientNameRequired": "Ingredient {index}: name is required",
      "stepInstructionRequired": "Step {index}: instruction is required",
    },
    "ka": {
      "appTitle": "CookBook",
      "login": "შესვლა",
      "signUp": "რეგისტრაცია",
      "email": "ელფოსტა",
      "password": "პაროლი",
      "createAccount": "ანგარიშის შექმნა",
      "username": "მომხმარებლის სახელი",
      "displayName": "საჩვენებელი სახელი (არასავალდებულო)",
      "passwordMin": "პაროლი (მინ. 8)",
      "menu": "მენიუ",
      "createRecipe": "რეცეპტის შექმნა",
      "notifications": "შეტყობინებები",
      "markAllRead": "ყველას წაკითხულად მონიშვნა",
      "allNotifications": "ყველა შეტყობინება",
      "unreadOnly": "მხოლოდ წაუკითხავი",
      "search": "ძიება",
      "logout": "გასვლა",
      "feed": "გვერდი",
      "recent": "ბოლო",
      "top": "ტოპ",
      "sortBy": "დალაგება",
      "retry": "ხელახლა ცდა",
      "cancel": "გაუქმება",
      "delete": "წაშლა",
      "add": "დამატება",
      "save": "შენახვა",
      "apply": "გამოყენება",
      "clearAll": "ყველას გასუფთავება",
      "applyFilters": "ფილტრების გამოყენება",
      "global": "გლობალური",
      "seeRecipesFromEveryone": "იხილეთ რეცეპტები ყველასგან",
      "following": "გამოწერილი",
      "seeRecipesFromPeopleYouFollow": "იხილეთ რეცეპტები გამოწერილი ადამიანებისგან",
      "logInToSeeFollowingFeed": "შედით სისტემაში გამოწერილი გვერდის სანახავად",
      "popular": "პოპულარული",
      "mostPopularRecipes": "ყველაზე პოპულარული რეცეპტები",
      "trending": "ტრენდული",
      "trendingNow": "ახლა ტრენდული",
      "savedRecipes": "შენახული რეცეპტები",
      "viewYourBookmarkedRecipes": "იხილეთ თქვენი დაბუქმარკული რეცეპტები",
      "analyticsStatistics": "ანალიტიკური სტატისტიკა",
      "viewTrackingStatistics": "თვალყურის დევნების სტატისტიკის ნახვა",
      "profile": "პროფილი",
      "viewProfile": "თქვენი პროფილის ნახვა",
      "allTime": "ყველა დრო",
      "last30Days": "ბოლო 30 დღე",
      "last7Days": "ბოლო 7 დღე",
      "timePeriod": "დროის პერიოდი",
      "days": "დღეები",
      "windowDays": "ფანჯრის დღეები",
      "oneDay": "1 დღე",
      "threeDays": "3 დღე",
      "sevenDays": "7 დღე",
      "fourteenDays": "14 დღე",
      "thirtyDays": "30 დღე",
      "listView": "სიის ხედი",
      "fullScreenView": "სრულ ეკრანის ხედი",
      "noMoreItems": "მეტი ელემენტი არ არის",
      "noSavedRecipes": "შენახული რეცეპტები არ არის",
      "startBookmarkingRecipes": "დაიწყეთ რეცეპტების დაბუქმარკვა მათ აქ შესანახად",
      "noStatisticsAvailable": "სტატისტიკა მიუწვდომელია",
      "noRecipesFound": "რეცეპტები არ მოიძებნა",
      "tryDifferentSearch": "სცადეთ სხვა საძიებო ტერმინი",
      "noUsersFound": "მომხმარებლები არ მოიძებნა",
      "notLoggedIn": "არ ხართ შესული",
      "errorLoadingStatistics": "სტატისტიკის ჩატვირთვის შეცდომა",
      "noEventDataAvailable": "მოვლენების მონაცემები მიუწვდომელია",
      "noRecipeDataAvailable": "რეცეპტების მონაცემები მიუწვდომელია",
      "noDailyEventDataAvailable": "ყოველდღიური მოვლენების მონაცემები მიუწვდომელია",
      "noEventsRecorded": "მოვლენები არ არის ჩაწერილი",
      "noEventsAvailable": "მოვლენები მიუწვდომელია",
      "trySelectingDifferentFilter": "სცადეთ სხვა ფილტრის არჩევა",
      "errorLoadingEvents": "მოვლენების ჩატვირთვის შეცდომა",
      "justNow": "ახლა",
      "minutesAgo": "წუთის წინ",
      "hoursAgo": "საათის წინ",
      "yesterday": "გუშინ",
      "daysAgo": "დღის წინ",
      "error": "შეცდომა",
      "addAvatar": "ავატარის დამატება",
      "updateAvatar": "ავატარის განახლება",
      "deleteAvatar": "ავატარის წაშლა",
      "areYouSureDeleteAvatar": "დარწმუნებული ხართ, რომ გსურთ თქვენი ავატარის წაშლა?",
      "followers": "მიმდევრები",
      "followingTitle": "გამოწერილი",
      "private": "პირადი",
      "thisUsersFollowersListIsPrivate": "ამ მომხმარებლის მიმდევრების სია პირადია",
      "noFollowers": "მიმდევრები არ არის",
      "thisUserDoesntHaveAnyFollowersYet": "ამ მომხმარებელს ჯერ არ აქვს მიმდევრები",
      "thisUsersFollowingListIsPrivate": "ამ მომხმარებლის გამოწერების სია პირადია",
      "notFollowingAnyone": "არავის არ გამოწერს",
      "thisUserIsntFollowingAnyoneYet": "ეს მომხმარებელი ჯერ არავის არ გამოწერს",
      "title": "სათაური",
      "enterRecipeTitle": "შეიყვანეთ რეცეპტის სათაური",
      "description": "აღწერა",
      "describeYourRecipe": "აღწერეთ თქვენი რეცეპტი",
      "cuisine": "სამზარეულო",
      "cuisineExample": "მაგ., იტალიური, მექსიკური, აზიური",
      "minTimeMinutes": "მინ. დრო (წუთები)",
      "maxTimeMinutes": "მაქს. დრო (წუთები)",
      "difficulty": "სირთულე",
      "easy": "მარტივი",
      "medium": "საშუალო",
      "hard": "რთული",
      "addTag": "ტეგის დამატება",
      "tags": "ტეგები",
      "ingredients": "ინგრედიენტები",
      "cookingTimeMinutes": "მომზადების დრო (წუთები)",
      "min": "მინ",
      "max": "მაქს",
      "quantity": "რაოდენობა",
      "quantityExample": "მაგ., 2",
      "unit": "ერთეული",
      "unitExample": "მაგ., ჭიქა",
      "ingredient": "ინგრედიენტი",
      "ingredientExample": "მაგ., ფქვილი",
      "instruction": "ინსტრუქცია",
      "describeThisStep": "აღწერეთ ეს ნაბიჯი",
      "images": "სურათები",
      "createRecipeTitle": "რეცეპტის შექმნა",
      "editRecipe": "რეცეპტის რედაქტირება",
      "switchToUsers": "მომხმარებლებზე გადართვა",
      "switchToRecipes": "რეცეპტებზე გადართვა",
      "filters": "ფილტრები",
      "searchRecipes": "რეცეპტების ძიება...",
      "searchUsers": "მომხმარებლების ძიება...",
      "statistics": "სტატისტიკა",
      "events": "მოვლენები",
      "overallStatistics": "ზოგადი სტატისტიკა",
      "eventsByType": "მოვლენები ტიპის მიხედვით",
      "topRecipesLast30Days": "ტოპ რეცეპტები (ბოლო 30 დღე)",
      "dailyEventsLast30Days": "ყოველდღიური მოვლენები (ბოლო 30 დღე)",
      "totalEvents": "სულ მოვლენები",
      "uniqueUsers": "უნიკალური მომხმარებლები",
      "uniqueRecipes": "უნიკალური რეცეპტები",
      "last24Hours": "ბოლო 24 საათი",
      "last7DaysStat": "ბოლო 7 დღე",
      "last30DaysStat": "ბოლო 30 დღე",
      "total": "სულ",
      "eventTimeline": "მოვლენების ვადები",
      "views": "ნახვები",
      "likes": "მოწონებები",
      "bookmarks": "ჩანიშნულები",
      "comments": "კომენტარები",
      "searches": "ძიებები",
      "all": "ყველა",
      "user": "მომხმარებელი",
      "recipe": "რეცეპტი",
      "eventsText": "მოვლენები",
      "english": "ინგლისური",
      "georgian": "ქართული",
      "language": "ენა",
      "changeAppLanguage": "აპლიკაციის ენის შეცვლა",
      "deleteRecipe": "რეცეპტის წაშლა",
      "areYouSureDeleteRecipe": "დარწმუნებული ხართ, რომ გსურთ წაშლა",
      "thisActionCannotBeUndone": "ეს ქმედება შეუქცევადია.",
      "recipeDeletedSuccessfully": "რეცეპტი წარმატებით წაიშალა",
      "notFound": "არ მოიძებნა",
      "somethingWentWrong": "რაღაც შეცდომა მოხდა",
      "steps": "ნაბიჯები",
      "noStepsYet": "ნაბიჯები ჯერ არ არის. დაამატეთ ერთი დასაწყებად!",
      "settings": "პარამეტრები",
      "appearance": "გარეგნობა",
      "themeMode": "თემის რეჟიმი",
      "system": "სისტემა",
      "light": "ნათელი",
      "dark": "მუქი",
      "account": "ანგარიში",
      "about": "შესახებ",
      "version": "ვერსია",
      "followSystemTheme": "სისტემის თემის მიხედვით",
      "lightTheme": "ნათელი თემა",
      "darkTheme": "მუქი თემა",
      "englishLanguage": "ინგლისური",
      "georgianLanguage": "ქართული",
      "helpAndSupport": "დახმარება და მხარდაჭერა",
      "termsAndPrivacy": "წესები და კონფიდენციალურობა",
      "termsOfService": "მომსახურების წესები",
      "privacyPolicy": "კონფიდენციალურობის პოლიტიკა",
      "dismiss": "დახურვა",
      "unableToConnect": "სერვერთან დაკავშირება ვერ მოხერხდა. გთხოვთ შეამოწმოთ ინტერნეტ კავშირი და სცადოთ ხელახლა.",
      "requestTimedOut": "მოთხოვნა დრო ამოიწურა. გთხოვთ სცადოთ ხელახლა.",
      "connectionInterrupted": "კავშირი შეწყდა. გთხოვთ სცადოთ ხელახლა.",
      "needToLogIn": "ამ ქმედების შესასრულებლად საჭიროა შესვლა.",
      "noPermission": "ამ ქმედების შესრულების უფლება არ გაქვთ.",
      "itemNotFound": "მოთხოვნილი ელემენტი ვერ მოიძებნა.",
      "invalidInput": "არასწორი მონაცემები. გთხოვთ შეამოწმოთ თქვენი მონაცემები და სცადოთ ხელახლა.",
      "invalidRequest": "არასწორი მოთხოვნა. გთხოვთ შეამოწმოთ თქვენი შეყვანილი მონაცემები და სცადოთ ხელახლა.",
      "actionConflict": "ეს ქმედება ეწინააღმდეგება მიმდინარე მდგომარეობას. გთხოვთ განაახლოთ და სცადოთ ხელახლა.",
      "fileTooLarge": "ფაილი ძალიან დიდია. გთხოვთ გამოიყენოთ უფრო პატარა ფაილი.",
      "invalidData": "მოწოდებული მონაცემები არასწორია. გთხოვთ შეამოწმოთ თქვენი შეყვანილი მონაცემები.",
      "tooManyRequests": "ძალიან ბევრი მოთხოვნა. გთხოვთ მოიცადოთ და სცადოთ ხელახლა.",
      "serverError": "სერვერის შეცდომა. გთხოვთ სცადოთ მოგვიანებით.",
      "errorOccurred": "შეცდომა მოხდა. გთხოვთ სცადოთ ხელახლა.",
      "minTimeCannotBeGreater": "მინიმალური დრო არ შეიძლება იყოს მაქსიმალურზე მეტი",
      "minCookingTimeCannotBeGreater": "მინიმალური მომზადების დრო არ შეიძლება იყოს მაქსიმალურზე მეტი",
      "minCookingTimeMustBeValidNumber": "მინიმალური მომზადების დრო უნდა იყოს სწორი რიცხვი",
      "maxCookingTimeMustBeValidNumber": "მაქსიმალური მომზადების დრო უნდა იყოს სწორი რიცხვი",
      "pleaseAddAtLeastOneIngredient": "გთხოვთ დაამატოთ მინიმუმ ერთი ინგრედიენტი",
      "pleaseAddAtLeastOneStep": "გთხოვთ დაამატოთ მინიმუმ ერთი ნაბიჯი",
      "ingredientNameRequired": "ინგრედიენტი {index}: სახელი აუცილებელია",
      "stepInstructionRequired": "ნაბიჯი {index}: ინსტრუქცია აუცილებელია",
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.contains(locale);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
