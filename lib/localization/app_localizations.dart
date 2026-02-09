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
  String get appTitle => _localizedValues[locale.languageCode]?["appTitle"] ?? "Yummy";

  // Auth screens
  String get login => _localizedValues[locale.languageCode]?["login"] ?? "Login";
  String get signUp => _localizedValues[locale.languageCode]?["signUp"] ?? "Sign up";
  String get email => _localizedValues[locale.languageCode]?["email"] ?? "Email";
  String get emailHint => _localizedValues[locale.languageCode]?["emailHint"] ?? "Enter your email";
  String get password => _localizedValues[locale.languageCode]?["password"] ?? "Password";
  String get passwordHint => _localizedValues[locale.languageCode]?["passwordHint"] ?? "Enter your password";
  String get createAccount => _localizedValues[locale.languageCode]?["createAccount"] ?? "Create account";
  String get username => _localizedValues[locale.languageCode]?["username"] ?? "Username";
  String get displayName => _localizedValues[locale.languageCode]?["displayName"] ?? "Display name (optional)";
  String get passwordMin => _localizedValues[locale.languageCode]?["passwordMin"] ?? "Password (min 8)";
  String get continueWithGoogle => _localizedValues[locale.languageCode]?["continueWithGoogle"] ?? "Continue with Google";
  String get orContinue => _localizedValues[locale.languageCode]?["orContinue"] ?? "or continue";
  String get rememberMe => _localizedValues[locale.languageCode]?["rememberMe"] ?? "Remember me";
  String get forgotPassword => _localizedValues[locale.languageCode]?["forgotPassword"] ?? "Forgot password?";
  String get forgotPasswordComingSoon => _localizedValues[locale.languageCode]?["forgotPasswordComingSoon"] ?? "Forgot password feature coming soon!";
  String get dontHaveAccount => _localizedValues[locale.languageCode]?["dontHaveAccount"] ?? "Don't have an account?";
  String get googleSignInFailed => _localizedValues[locale.languageCode]?["googleSignInFailed"] ?? "Google Sign-In failed. Please try again.";
  String get showPassword => _localizedValues[locale.languageCode]?["showPassword"] ?? "Show password";
  String get hidePassword => _localizedValues[locale.languageCode]?["hidePassword"] ?? "Hide password";
  String get appTagline => _localizedValues[locale.languageCode]?["appTagline"] ?? "Your Recipe Journey";

  // Navigation & Tooltips
  String get menu => _localizedValues[locale.languageCode]?["menu"] ?? "Menu";
  String get createRecipe => _localizedValues[locale.languageCode]?["createRecipe"] ?? "Create Recipe";
  String get notifications => _localizedValues[locale.languageCode]?["notifications"] ?? "Notifications";
  String get markAllRead => _localizedValues[locale.languageCode]?["markAllRead"] ?? "Mark all read";
  String get allNotifications => _localizedValues[locale.languageCode]?["allNotifications"] ?? "All notifications";
  String get unreadOnly => _localizedValues[locale.languageCode]?["unreadOnly"] ?? "Unread only";
  String get search => _localizedValues[locale.languageCode]?["search"] ?? "Search";
  String get logout => _localizedValues[locale.languageCode]?["logout"] ?? "Logout";
  String get logoutConfirmation => _localizedValues[locale.languageCode]?["logoutConfirmation"] ?? "Are you sure you want to log out?";

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
  String get noResultsFound => _localizedValues[locale.languageCode]?["noResultsFound"] ?? "No results found";
  String get noRecentSearches => _localizedValues[locale.languageCode]?["noRecentSearches"] ?? "No recent searches";
  String get searchHistoryWillAppear => _localizedValues[locale.languageCode]?["searchHistoryWillAppear"] ?? "Your search history will appear here";
  String get recentSearches => _localizedValues[locale.languageCode]?["recentSearches"] ?? "Recent Searches";
  String get users => _localizedValues[locale.languageCode]?["users"] ?? "Users";
  String get recipes => _localizedValues[locale.languageCode]?["recipes"] ?? "Recipes";
  String get seeAll => _localizedValues[locale.languageCode]?["seeAll"] ?? "See all";
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
  String get totalLikes => _localizedValues[locale.languageCode]?["totalLikes"] ?? "Total Likes";
  String get private => _localizedValues[locale.languageCode]?["private"] ?? "Private";
  String get thisUsersFollowersListIsPrivate => _localizedValues[locale.languageCode]?["thisUsersFollowersListIsPrivate"] ?? "This user's followers list is private";
  String get noFollowers => _localizedValues[locale.languageCode]?["noFollowers"] ?? "No followers";
  String get thisUserDoesntHaveAnyFollowersYet => _localizedValues[locale.languageCode]?["thisUserDoesntHaveAnyFollowersYet"] ?? "This user doesn't have any followers yet";
  String get thisUsersFollowingListIsPrivate => _localizedValues[locale.languageCode]?["thisUsersFollowingListIsPrivate"] ?? "This user's following list is private";
  String get notFollowingAnyone => _localizedValues[locale.languageCode]?["notFollowingAnyone"] ?? "Not following anyone";
  String get thisUserIsntFollowingAnyoneYet => _localizedValues[locale.languageCode]?["thisUserIsntFollowingAnyoneYet"] ?? "This user isn't following anyone yet";
  String get privacy => _localizedValues[locale.languageCode]?["privacy"] ?? "Privacy";
  String get privateFollowers => _localizedValues[locale.languageCode]?["privateFollowers"] ?? "Private Followers";
  String get privateFollowing => _localizedValues[locale.languageCode]?["privateFollowing"] ?? "Private Following";
  String get hideYourFollowersListFromOthers => _localizedValues[locale.languageCode]?["hideYourFollowersListFromOthers"] ?? "Hide your followers list from others";
  String get hideYourFollowingListFromOthers => _localizedValues[locale.languageCode]?["hideYourFollowingListFromOthers"] ?? "Hide your following list from others";

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
  String get processingImage => _localizedValues[locale.languageCode]?["processingImage"] ?? "Processing image...";
  String imageTooLarge(String sizeMB, String maxMB) =>
      (_localizedValues[locale.languageCode]?["imageTooLarge"] ?? "Image is too large ({sizeMB}MB). Maximum size is {maxMB}MB. Please choose a smaller image.")
          .replaceAll("{sizeMB}", sizeMB)
          .replaceAll("{maxMB}", maxMB);
  String imageCompressionFailed(String maxMB) =>
      (_localizedValues[locale.languageCode]?["imageCompressionFailed"] ?? "Could not process image. Please choose an image smaller than {maxMB}MB.")
          .replaceAll("{maxMB}", maxMB);
  String get describeThisStep => _localizedValues[locale.languageCode]?["describeThisStep"] ?? "Describe this step";
  String get createRecipeTitle => _localizedValues[locale.languageCode]?["createRecipeTitle"] ?? "Create Recipe";
  String get editRecipe => _localizedValues[locale.languageCode]?["editRecipe"] ?? "Edit Recipe";

  // Search
  String get switchToUsers => _localizedValues[locale.languageCode]?["switchToUsers"] ?? "Switch to Users";
  String get switchToRecipes => _localizedValues[locale.languageCode]?["switchToRecipes"] ?? "Switch to Recipes";
  String get filters => _localizedValues[locale.languageCode]?["filters"] ?? "Filters";
  String get searchRecipes => _localizedValues[locale.languageCode]?["searchRecipes"] ?? "Search recipes...";
  String get searchUsers => _localizedValues[locale.languageCode]?["searchUsers"] ?? "Search users...";

  // Pantry Search (Cook with What I Have)
  String get cookWithWhatIHave => _localizedValues[locale.languageCode]?["cookWithWhatIHave"] ?? "Cook with What I Have";
  String get findRecipesWithIngredients => _localizedValues[locale.languageCode]?["findRecipesWithIngredients"] ?? "Find recipes based on ingredients you have";
  String get addIngredientsToStart => _localizedValues[locale.languageCode]?["addIngredientsToStart"] ?? "Add ingredients to start";
  String get addIngredientsDescription => _localizedValues[locale.languageCode]?["addIngredientsDescription"] ?? "Add the ingredients you have and we'll find recipes you can make";
  String get tryDifferentIngredients => _localizedValues[locale.languageCode]?["tryDifferentIngredients"] ?? "Try adding different ingredients or lowering the match threshold";
  String get enterIngredient => _localizedValues[locale.languageCode]?["enterIngredient"] ?? "Enter an ingredient...";
  String get matchThreshold => _localizedValues[locale.languageCode]?["matchThreshold"] ?? "Match threshold:";
  String get findRecipes => _localizedValues[locale.languageCode]?["findRecipes"] ?? "Find Recipes";
  String get missing => _localizedValues[locale.languageCode]?["missing"] ?? "Missing";

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
  String get recipeCreatedSuccessfully => _localizedValues[locale.languageCode]?["recipeCreatedSuccessfully"] ?? "Recipe created successfully";
  String get recipeUpdatedSuccessfully => _localizedValues[locale.languageCode]?["recipeUpdatedSuccessfully"] ?? "Recipe updated successfully";
  String get notFound => _localizedValues[locale.languageCode]?["notFound"] ?? "Not found";
  String get somethingWentWrong => _localizedValues[locale.languageCode]?["somethingWentWrong"] ?? "Something went wrong";
  String get steps => _localizedValues[locale.languageCode]?["steps"] ?? "Steps";
  String get noStepsYet => _localizedValues[locale.languageCode]?["noStepsYet"] ?? "No steps yet. Add one to get started!";
  String get noIngredientsYet => _localizedValues[locale.languageCode]?["noIngredientsYet"] ?? "No ingredients yet. Add your first ingredient!";
  String get addCoverPhoto => _localizedValues[locale.languageCode]?["addCoverPhoto"] ?? "Add cover photo";
  String get tapToUpload => _localizedValues[locale.languageCode]?["tapToUpload"] ?? "Tap to upload";
  String get basicInfo => _localizedValues[locale.languageCode]?["basicInfo"] ?? "Basic Info";
  String get cookingDetails => _localizedValues[locale.languageCode]?["cookingDetails"] ?? "Cooking Details";
  String get saveChanges => _localizedValues[locale.languageCode]?["saveChanges"] ?? "Save Changes";
  String get publishRecipe => _localizedValues[locale.languageCode]?["publishRecipe"] ?? "Publish Recipe";

  // Language
  String get english => _localizedValues[locale.languageCode]?["english"] ?? "English";
  String get georgian => _localizedValues[locale.languageCode]?["georgian"] ?? "Georgian";
  String get language => _localizedValues[locale.languageCode]?["language"] ?? "Language";
  String get changeAppLanguage => _localizedValues[locale.languageCode]?["changeAppLanguage"] ?? "Change app language";

  // Settings
  String get settings => _localizedValues[locale.languageCode]?["settings"] ?? "Settings";
  String get appPreferences => _localizedValues[locale.languageCode]?["appPreferences"] ?? "App preferences";
  String get feedPreferences => _localizedValues[locale.languageCode]?["feedPreferences"] ?? "Feed Preferences";
  String get quickAccess => _localizedValues[locale.languageCode]?["quickAccess"] ?? "Quick Access";
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
  
  // Help & Support
  String get helpWelcomeTitle => _localizedValues[locale.languageCode]?["helpWelcomeTitle"] ?? "Welcome to Help & Support";
  String get helpWelcomeMessage => _localizedValues[locale.languageCode]?["helpWelcomeMessage"] ?? "I'm a solo developer working on Yummy. While I don't have a dedicated support team, I'm here to help! Please check the FAQs below first, and if you still need assistance, feel free to reach out.";
  String get faq => _localizedValues[locale.languageCode]?["faq"] ?? "Frequently Asked Questions";
  String get faqHowToCreateRecipe => _localizedValues[locale.languageCode]?["faqHowToCreateRecipe"] ?? "How do I create a recipe?";
  String get faqHowToCreateRecipeAnswer => _localizedValues[locale.languageCode]?["faqHowToCreateRecipeAnswer"] ?? "Tap the '+' button in the navigation bar. Fill in the recipe details including title, description, ingredients, steps, and images, then save.";
  String get faqHowToSaveRecipe => _localizedValues[locale.languageCode]?["faqHowToSaveRecipe"] ?? "How do I save a recipe?";
  String get faqHowToSaveRecipeAnswer => _localizedValues[locale.languageCode]?["faqHowToSaveRecipeAnswer"] ?? "When viewing a recipe, tap the bookmark icon to save it. You can view all your saved recipes from the menu under 'Saved Recipes'.";
  String get faqHowToSearch => _localizedValues[locale.languageCode]?["faqHowToSearch"] ?? "How do I search for recipes?";
  String get faqHowToSearchAnswer => _localizedValues[locale.languageCode]?["faqHowToSearchAnswer"] ?? "Use the search icon in the navigation bar. You can search by recipe name, ingredients, or cuisine type. Use filters to narrow down your search results.";
  String get faqHowToFollowUser => _localizedValues[locale.languageCode]?["faqHowToFollowUser"] ?? "How do I follow other users?";
  String get faqHowToFollowUserAnswer => _localizedValues[locale.languageCode]?["faqHowToFollowUserAnswer"] ?? "Visit a user's profile and tap the 'Follow' button. You'll see their recipes in your 'Following' feed.";
  String get faqAccountIssues => _localizedValues[locale.languageCode]?["faqAccountIssues"] ?? "I'm having trouble with my account. What should I do?";
  String get faqAccountIssuesAnswer => _localizedValues[locale.languageCode]?["faqAccountIssuesAnswer"] ?? "Try logging out and logging back in. If you've forgotten your password, use the password reset option on the login screen. If issues persist, contact us using the information below.";
  String get faqAppNotWorking => _localizedValues[locale.languageCode]?["faqAppNotWorking"] ?? "The app isn't working properly. What can I do?";
  String get faqAppNotWorkingAnswer => _localizedValues[locale.languageCode]?["faqAppNotWorkingAnswer"] ?? "First, try closing and reopening the app. If that doesn't help, try restarting your device. Make sure you have a stable internet connection. If the problem continues, please report it using the bug reporting section below.";
  String get reportIssues => _localizedValues[locale.languageCode]?["reportIssues"] ?? "Report Issues & Bugs";
  String get reportIssuesInstructions => _localizedValues[locale.languageCode]?["reportIssuesInstructions"] ?? "When reporting a bug or issue, please include:";
  String get reportIssuesAppVersion => _localizedValues[locale.languageCode]?["reportIssuesAppVersion"] ?? "App version (shown below)";
  String get reportIssuesDeviceInfo => _localizedValues[locale.languageCode]?["reportIssuesDeviceInfo"] ?? "Your device type and OS version";
  String get reportIssuesStepsToReproduce => _localizedValues[locale.languageCode]?["reportIssuesStepsToReproduce"] ?? "Steps to reproduce the issue";
  String get reportIssuesScreenshots => _localizedValues[locale.languageCode]?["reportIssuesScreenshots"] ?? "Screenshots if possible";
  String get reportIssuesExpectedBehavior => _localizedValues[locale.languageCode]?["reportIssuesExpectedBehavior"] ?? "What you expected to happen";
  String get reportIssuesNote => _localizedValues[locale.languageCode]?["reportIssuesNote"] ?? "Note: As a solo developer, I may not be able to respond immediately, but I review all reports and work on fixes in order of priority.";
  String get contactUs => _localizedValues[locale.languageCode]?["contactUs"] ?? "Contact Us";
  String get contactEmail => _localizedValues[locale.languageCode]?["contactEmail"] ?? "Email Support";
  String get copyEmailAddress => _localizedValues[locale.languageCode]?["copyEmailAddress"] ?? "Copy Email Address";
  String get copyEmailAddressSubtitle => _localizedValues[locale.languageCode]?["copyEmailAddressSubtitle"] ?? "Copy the support email to your clipboard";
  String get emailCopiedToClipboard => _localizedValues[locale.languageCode]?["emailCopiedToClipboard"] ?? "Email address copied to clipboard";
  String get appInformation => _localizedValues[locale.languageCode]?["appInformation"] ?? "App Information";
  String get appDescription => _localizedValues[locale.languageCode]?["appDescription"] ?? "Your personal recipe collection and sharing platform";
  String get versionCopiedToClipboard => _localizedValues[locale.languageCode]?["versionCopiedToClipboard"] ?? "Version copied to clipboard";
  String get termsOfService => _localizedValues[locale.languageCode]?["termsOfService"] ?? "Terms of Service";
  String get privacyPolicy => _localizedValues[locale.languageCode]?["privacyPolicy"] ?? "Privacy Policy";
  
  // Terms of Service sections
  String get termsAcceptanceTitle => _localizedValues[locale.languageCode]?["termsAcceptanceTitle"] ?? "1. Acceptance of Terms";
  String get termsAcceptanceContent => _localizedValues[locale.languageCode]?["termsAcceptanceContent"] ?? "By accessing and using Yummy, you accept and agree to be bound by the terms and provision of this agreement.";
  String get termsLicenseTitle => _localizedValues[locale.languageCode]?["termsLicenseTitle"] ?? "2. Use License";
  String get termsLicenseContent => _localizedValues[locale.languageCode]?["termsLicenseContent"] ?? "Permission is granted to temporarily use Yummy for personal, non-commercial purposes. This license does not include:\n\n• Reselling or sublicensing the service\n• Using the service for any commercial purpose\n• Removing any copyright or proprietary notations";
  String get termsAccountsTitle => _localizedValues[locale.languageCode]?["termsAccountsTitle"] ?? "3. User Accounts";
  String get termsAccountsContent => _localizedValues[locale.languageCode]?["termsAccountsContent"] ?? "You are responsible for maintaining the confidentiality of your account credentials. You agree to:\n\n• Provide accurate and complete information\n• Keep your password secure\n• Notify us immediately of any unauthorized use";
  String get termsContentTitle => _localizedValues[locale.languageCode]?["termsContentTitle"] ?? "4. User Content";
  String get termsContentContent => _localizedValues[locale.languageCode]?["termsContentContent"] ?? "You retain ownership of content you post on Yummy. By posting content, you grant us a license to use, modify, and display your content on the platform.";
  String get termsProhibitedTitle => _localizedValues[locale.languageCode]?["termsProhibitedTitle"] ?? "5. Prohibited Uses";
  String get termsProhibitedContent => _localizedValues[locale.languageCode]?["termsProhibitedContent"] ?? "You may not use Yummy to:\n\n• Violate any laws or regulations\n• Infringe on intellectual property rights\n• Post harmful, offensive, or illegal content\n• Spam or harass other users";
  String get termsTerminationTitle => _localizedValues[locale.languageCode]?["termsTerminationTitle"] ?? "6. Termination";
  String get termsTerminationContent => _localizedValues[locale.languageCode]?["termsTerminationContent"] ?? "We reserve the right to terminate or suspend your account at any time for violations of these terms.";
  String get termsChangesTitle => _localizedValues[locale.languageCode]?["termsChangesTitle"] ?? "7. Changes to Terms";
  String get termsChangesContent => _localizedValues[locale.languageCode]?["termsChangesContent"] ?? "We reserve the right to modify these terms at any time. Continued use of the service after changes constitutes acceptance of the new terms.";
  
  // Privacy Policy sections
  String get privacyCollectTitle => _localizedValues[locale.languageCode]?["privacyCollectTitle"] ?? "1. Information We Collect";
  String get privacyCollectContent => _localizedValues[locale.languageCode]?["privacyCollectContent"] ?? "We collect information that you provide directly to us, including:\n\n• Account information (username, email, display name)\n• Content you create (recipes, comments, images)\n• Usage data and analytics\n• Device information and identifiers";
  String get privacyUseTitle => _localizedValues[locale.languageCode]?["privacyUseTitle"] ?? "2. How We Use Your Information";
  String get privacyUseContent => _localizedValues[locale.languageCode]?["privacyUseContent"] ?? "We use the information we collect to:\n\n• Provide and improve our services\n• Personalize your experience\n• Communicate with you about your account\n• Analyze usage patterns and trends\n• Ensure security and prevent fraud";
  String get privacySharingTitle => _localizedValues[locale.languageCode]?["privacySharingTitle"] ?? "3. Information Sharing";
  String get privacySharingContent => _localizedValues[locale.languageCode]?["privacySharingContent"] ?? "We do not sell your personal information. We may share your information only:\n\n• With your consent\n• To comply with legal obligations\n• To protect our rights and safety\n• With service providers who assist us (under strict confidentiality agreements)";
  String get privacySecurityTitle => _localizedValues[locale.languageCode]?["privacySecurityTitle"] ?? "4. Data Security";
  String get privacySecurityContent => _localizedValues[locale.languageCode]?["privacySecurityContent"] ?? "We implement appropriate technical and organizational measures to protect your personal information. However, no method of transmission over the internet is 100% secure.";
  String get privacyRightsTitle => _localizedValues[locale.languageCode]?["privacyRightsTitle"] ?? "5. Your Rights";
  String get privacyRightsContent => _localizedValues[locale.languageCode]?["privacyRightsContent"] ?? "You have the right to:\n\n• Access your personal information\n• Correct inaccurate information\n• Delete your account and data\n• Opt-out of certain data processing\n• Export your data";
  String get privacyCookiesTitle => _localizedValues[locale.languageCode]?["privacyCookiesTitle"] ?? "6. Cookies and Tracking";
  String get privacyCookiesContent => _localizedValues[locale.languageCode]?["privacyCookiesContent"] ?? "We use cookies and similar technologies to enhance your experience, analyze usage, and assist with marketing efforts. You can control cookies through your browser settings.";
  String get privacyChildrenTitle => _localizedValues[locale.languageCode]?["privacyChildrenTitle"] ?? "7. Children's Privacy";
  String get privacyChildrenContent => _localizedValues[locale.languageCode]?["privacyChildrenContent"] ?? "Yummy is not intended for users under the age of 13. We do not knowingly collect personal information from children under 13.";
  String get privacyChangesTitle => _localizedValues[locale.languageCode]?["privacyChangesTitle"] ?? "8. Changes to Privacy Policy";
  String get privacyChangesContent => _localizedValues[locale.languageCode]?["privacyChangesContent"] ?? "We may update this privacy policy from time to time. We will notify you of any material changes by posting the new policy on this page.";
  String get privacyContactTitle => _localizedValues[locale.languageCode]?["privacyContactTitle"] ?? "9. Contact Us";
  String get privacyContactContent => _localizedValues[locale.languageCode]?["privacyContactContent"] ?? "If you have questions about this privacy policy, please contact us through the app settings or support channels.";
  String get acceptTermsText => _localizedValues[locale.languageCode]?["acceptTermsText"] ?? "I accept the ";
  String get acceptTermsFull => _localizedValues[locale.languageCode]?["acceptTermsFull"] ?? "I have read and accept the Terms & Privacy Policy";
  String get viewFullTerms => _localizedValues[locale.languageCode]?["viewFullTerms"] ?? "View Full Terms & Privacy Policy";
  String get termsSummary => _localizedValues[locale.languageCode]?["termsSummary"] ?? "Key points: You are responsible for your account, you retain ownership of your content, and you agree not to use the service for prohibited purposes.";
  String get privacySummary => _localizedValues[locale.languageCode]?["privacySummary"] ?? "We collect information you provide, usage data, and device information. We use this to provide and improve our services, personalize your experience, and ensure security. We do not sell your personal information.";
  String get privacyRightsSummary => _localizedValues[locale.languageCode]?["privacyRightsSummary"] ?? "You have the right to access, correct, delete, and export your data. You can opt-out of certain data processing.";
  
  // Email Verification
  String get verifyEmail => _localizedValues[locale.languageCode]?["verifyEmail"] ?? "Verify Email";
  String get verifyEmailTitle => _localizedValues[locale.languageCode]?["verifyEmailTitle"] ?? "Verify Your Email";
  String verifyEmailMessage(String email) => _localizedValues[locale.languageCode]?["verifyEmailMessage"]?.replaceAll("{email}", email) ?? "We've sent a verification code to $email. Please enter it below to verify your email address.";
  String get verificationCode => _localizedValues[locale.languageCode]?["verificationCode"] ?? "Verification Code";
  String get enterVerificationCode => _localizedValues[locale.languageCode]?["enterVerificationCode"] ?? "Enter the code from your email";
  String get verify => _localizedValues[locale.languageCode]?["verify"] ?? "Verify";
  String get resendVerificationCode => _localizedValues[locale.languageCode]?["resendVerificationCode"] ?? "Resend Code";
  String get verificationEmailSent => _localizedValues[locale.languageCode]?["verificationEmailSent"] ?? "Verification email sent!";
  String get pleaseEnterVerificationCode => _localizedValues[locale.languageCode]?["pleaseEnterVerificationCode"] ?? "Please enter the verification code";

  // Password Reset
  String get resetPassword => _localizedValues[locale.languageCode]?["resetPassword"] ?? "Reset Password";
  String get resetPasswordTitle => _localizedValues[locale.languageCode]?["resetPasswordTitle"] ?? "Reset Your Password";
  String get resetPasswordMessage => _localizedValues[locale.languageCode]?["resetPasswordMessage"] ?? "Enter your email address and we'll send you a code to reset your password.";
  String resetCodeMessage(String email) => _localizedValues[locale.languageCode]?["resetCodeMessage"]?.replaceAll("{email}", email) ?? "We've sent a 6-digit code to $email. Enter it below along with your new password.";
  String get resetCode => _localizedValues[locale.languageCode]?["resetCode"] ?? "Reset Code";
  String get enterResetCode => _localizedValues[locale.languageCode]?["enterResetCode"] ?? "Enter Reset Code";
  String get sendResetCode => _localizedValues[locale.languageCode]?["sendResetCode"] ?? "Send Reset Code";
  String get resendCode => _localizedValues[locale.languageCode]?["resendCode"] ?? "Resend Code";
  String get resetCodeSent => _localizedValues[locale.languageCode]?["resetCodeSent"] ?? "Reset code sent!";
  String get newPassword => _localizedValues[locale.languageCode]?["newPassword"] ?? "New Password";
  String get enterNewPassword => _localizedValues[locale.languageCode]?["enterNewPassword"] ?? "Enter new password";
  String get confirmPassword => _localizedValues[locale.languageCode]?["confirmPassword"] ?? "Confirm Password";
  String get enterPasswordAgain => _localizedValues[locale.languageCode]?["enterPasswordAgain"] ?? "Enter password again";
  String get passwordsDoNotMatch => _localizedValues[locale.languageCode]?["passwordsDoNotMatch"] ?? "Passwords do not match";
  String get passwordTooShort => _localizedValues[locale.languageCode]?["passwordTooShort"] ?? "Password must be at least 8 characters";
  String get passwordResetSuccess => _localizedValues[locale.languageCode]?["passwordResetSuccess"] ?? "Password reset successfully!";
  String get pleaseEnterResetCode => _localizedValues[locale.languageCode]?["pleaseEnterResetCode"] ?? "Please enter the reset code";
  String get pleaseEnterPassword => _localizedValues[locale.languageCode]?["pleaseEnterPassword"] ?? "Please enter a password";
  String get pleaseEnterEmail => _localizedValues[locale.languageCode]?["pleaseEnterEmail"] ?? "Please enter your email address";
  String get invalidEmail => _localizedValues[locale.languageCode]?["invalidEmail"] ?? "Please enter a valid email address";
  String get backToLogin => _localizedValues[locale.languageCode]?["backToLogin"] ?? "Back to Login";
  String get enterEmail => _localizedValues[locale.languageCode]?["enterEmail"] ?? "Enter your email";

  // App Tour
  String get tourWelcomeTitle => _localizedValues[locale.languageCode]?["tourWelcomeTitle"] ?? "Welcome to Yummy! 👋";
  String get tourWelcomeDescription => _localizedValues[locale.languageCode]?["tourWelcomeDescription"] ?? "This is your home feed. Discover amazing recipes from the community and find your next meal inspiration!";
  String get tourSearchTitle => _localizedValues[locale.languageCode]?["tourSearchTitle"] ?? "Search Recipes 🔍";
  String get tourSearchDescription => _localizedValues[locale.languageCode]?["tourSearchDescription"] ?? "Find recipes by name, ingredients, or cuisine type.";
  String get tourCreateTitle => _localizedValues[locale.languageCode]?["tourCreateTitle"] ?? "Share Your Recipes ✨";
  String get tourCreateDescription => _localizedValues[locale.languageCode]?["tourCreateDescription"] ?? "Tap here to create and share your own recipes with the community. Add photos, ingredients, and steps!";
  String get tourNotificationsTitle => _localizedValues[locale.languageCode]?["tourNotificationsTitle"] ?? "Stay Updated 🔔";
  String get tourNotificationsDescription => _localizedValues[locale.languageCode]?["tourNotificationsDescription"] ?? "Get notified when someone likes your recipes, follows you, or comments on your posts!";
  String get tourMenuTitle => _localizedValues[locale.languageCode]?["tourMenuTitle"] ?? "More Features 📱";
  String get tourMenuDescription => _localizedValues[locale.languageCode]?["tourMenuDescription"] ?? "Access saved recipes, notifications, settings, and more from the menu.";
  String get tourSortTitle => _localizedValues[locale.languageCode]?["tourSortTitle"] ?? "Sort Your Feed 🔽";
  String get tourSortDescription => _localizedValues[locale.languageCode]?["tourSortDescription"] ?? "Switch between Recent (newest first) and Top (most popular) posts. Choose what matters to you!";
  String get tourViewToggleTitle => _localizedValues[locale.languageCode]?["tourViewToggleTitle"] ?? "Switch Views 👁️";
  String get tourViewToggleDescription => _localizedValues[locale.languageCode]?["tourViewToggleDescription"] ?? "Toggle between list view and full-screen immersive view for a different browsing experience!";
  String get tourTapToContinue => _localizedValues[locale.languageCode]?["tourTapToContinue"] ?? "Tap the highlighted area to continue";
  String get tourAllSet => _localizedValues[locale.languageCode]?["tourAllSet"] ?? "You're all set! Enjoy using Yummy! 🎉";

  static const Map<String, Map<String, String>> _localizedValues = {
    "en": {
      "appTitle": "Yummy",
      "login": "Login",
      "signUp": "Sign up",
      "email": "Email",
      "emailHint": "Enter your email",
      "password": "Password",
      "passwordHint": "Enter your password",
      "createAccount": "Create account",
      "username": "Username",
      "displayName": "Display name (optional)",
      "passwordMin": "Password (min 8)",
      "continueWithGoogle": "Continue with Google",
      "orContinue": "or continue",
      "rememberMe": "Remember me",
      "forgotPassword": "Forgot password?",
      "forgotPasswordComingSoon": "Forgot password feature coming soon!",
      "dontHaveAccount": "Don't have an account?",
      "googleSignInFailed": "Google Sign-In failed. Please try again.",
      "showPassword": "Show password",
      "hidePassword": "Hide password",
      "appTagline": "Your Recipe Journey",
      "menu": "Menu",
      "createRecipe": "Create Recipe",
      "notifications": "Notifications",
      "markAllRead": "Mark all read",
      "allNotifications": "All notifications",
      "unreadOnly": "Unread only",
      "search": "Search",
      "logout": "Logout",
      "logoutConfirmation": "Are you sure you want to log out?",
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
      "noResultsFound": "No results found",
      "noRecentSearches": "No recent searches",
      "searchHistoryWillAppear": "Your search history will appear here",
      "recentSearches": "Recent Searches",
      "users": "Users",
      "recipes": "Recipes",
      "seeAll": "See all",
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
      "totalLikes": "Total Likes",
      "private": "Private",
      "thisUsersFollowersListIsPrivate": "This user's followers list is private",
      "noFollowers": "No followers",
      "thisUserDoesntHaveAnyFollowersYet": "This user doesn't have any followers yet",
      "thisUsersFollowingListIsPrivate": "This user's following list is private",
      "notFollowingAnyone": "Not following anyone",
      "thisUserIsntFollowingAnyoneYet": "This user isn't following anyone yet",
      "privacy": "Privacy",
      "privateFollowers": "Private Followers",
      "privateFollowing": "Private Following",
      "hideYourFollowersListFromOthers": "Hide your followers list from others",
      "hideYourFollowingListFromOthers": "Hide your following list from others",
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
      "cookWithWhatIHave": "Cook with What I Have",
      "findRecipesWithIngredients": "Find recipes based on ingredients you have",
      "addIngredientsToStart": "Add ingredients to start",
      "addIngredientsDescription": "Add the ingredients you have and we'll find recipes you can make",
      "tryDifferentIngredients": "Try adding different ingredients or lowering the match threshold",
      "enterIngredient": "Enter an ingredient...",
      "matchThreshold": "Match threshold:",
      "findRecipes": "Find Recipes",
      "missing": "Missing",
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
      "recipeCreatedSuccessfully": "Recipe created successfully",
      "recipeUpdatedSuccessfully": "Recipe updated successfully",
      "notFound": "Not found",
      "somethingWentWrong": "Something went wrong",
      "steps": "Steps",
      "noStepsYet": "No steps yet. Add one to get started!",
      "noIngredientsYet": "No ingredients yet. Add your first ingredient!",
      "addCoverPhoto": "Add cover photo",
      "tapToUpload": "Tap to upload",
      "basicInfo": "Basic Info",
      "cookingDetails": "Cooking Details",
      "saveChanges": "Save Changes",
      "publishRecipe": "Publish Recipe",
      "settings": "Settings",
      "appPreferences": "App preferences",
      "feedPreferences": "Feed Preferences",
      "quickAccess": "Quick Access",
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
      "termsAcceptanceTitle": "1. Acceptance of Terms",
      "termsAcceptanceContent": "By accessing and using Yummy, you accept and agree to be bound by the terms and provision of this agreement.",
      "termsLicenseTitle": "2. Use License",
      "termsLicenseContent": "Permission is granted to temporarily use Yummy for personal, non-commercial purposes. This license does not include:\n\n• Reselling or sublicensing the service\n• Using the service for any commercial purpose\n• Removing any copyright or proprietary notations",
      "termsAccountsTitle": "3. User Accounts",
      "termsAccountsContent": "You are responsible for maintaining the confidentiality of your account credentials. You agree to:\n\n• Provide accurate and complete information\n• Keep your password secure\n• Notify us immediately of any unauthorized use",
      "termsContentTitle": "4. User Content",
      "termsContentContent": "You retain ownership of content you post on Yummy. By posting content, you grant us a license to use, modify, and display your content on the platform.",
      "termsProhibitedTitle": "5. Prohibited Uses",
      "termsProhibitedContent": "You may not use Yummy to:\n\n• Violate any laws or regulations\n• Infringe on intellectual property rights\n• Post harmful, offensive, or illegal content\n• Spam or harass other users",
      "termsTerminationTitle": "6. Termination",
      "termsTerminationContent": "We reserve the right to terminate or suspend your account at any time for violations of these terms.",
      "termsChangesTitle": "7. Changes to Terms",
      "termsChangesContent": "We reserve the right to modify these terms at any time. Continued use of the service after changes constitutes acceptance of the new terms.",
      "privacyCollectTitle": "1. Information We Collect",
      "privacyCollectContent": "We collect information that you provide directly to us, including:\n\n• Account information (username, email, display name)\n• Content you create (recipes, comments, images)\n• Usage data and analytics\n• Device information and identifiers",
      "privacyUseTitle": "2. How We Use Your Information",
      "privacyUseContent": "We use the information we collect to:\n\n• Provide and improve our services\n• Personalize your experience\n• Communicate with you about your account\n• Analyze usage patterns and trends\n• Ensure security and prevent fraud",
      "privacySharingTitle": "3. Information Sharing",
      "privacySharingContent": "We do not sell your personal information. We may share your information only:\n\n• With your consent\n• To comply with legal obligations\n• To protect our rights and safety\n• With service providers who assist us (under strict confidentiality agreements)",
      "privacySecurityTitle": "4. Data Security",
      "privacySecurityContent": "We implement appropriate technical and organizational measures to protect your personal information. However, no method of transmission over the internet is 100% secure.",
      "privacyRightsTitle": "5. Your Rights",
      "privacyRightsContent": "You have the right to:\n\n• Access your personal information\n• Correct inaccurate information\n• Delete your account and data\n• Opt-out of certain data processing\n• Export your data",
      "privacyCookiesTitle": "6. Cookies and Tracking",
      "privacyCookiesContent": "We use cookies and similar technologies to enhance your experience, analyze usage, and assist with marketing efforts. You can control cookies through your browser settings.",
      "privacyChildrenTitle": "7. Children's Privacy",
      "privacyChildrenContent": "Yummy is not intended for users under the age of 13. We do not knowingly collect personal information from children under 13.",
      "privacyChangesTitle": "8. Changes to Privacy Policy",
      "privacyChangesContent": "We may update this privacy policy from time to time. We will notify you of any material changes by posting the new policy on this page.",
      "privacyContactTitle": "9. Contact Us",
      "privacyContactContent": "If you have questions about this privacy policy, please contact us through the app settings or support channels.",
      "acceptTermsText": "I accept the ",
      "acceptTermsFull": "I have read and accept the Terms & Privacy Policy",
      "viewFullTerms": "View Full Terms & Privacy Policy",
      "termsSummary": "Key points: You are responsible for your account, you retain ownership of your content, and you agree not to use the service for prohibited purposes.",
      "privacySummary": "We collect information you provide, usage data, and device information. We use this to provide and improve our services, personalize your experience, and ensure security. We do not sell your personal information.",
      "privacyRightsSummary": "You have the right to access, correct, delete, and export your data. You can opt-out of certain data processing.",
      "verifyEmail": "Verify Email",
      "verifyEmailTitle": "Verify Your Email",
      "verifyEmailMessage": "We've sent a verification code to {email}. Please enter it below to verify your email address.",
      "verificationCode": "Verification Code",
      "enterVerificationCode": "Enter the code from your email",
      "verify": "Verify",
      "resendVerificationCode": "Resend Code",
      "verificationEmailSent": "Verification email sent!",
      "pleaseEnterVerificationCode": "Please enter the verification code",
      "resetPassword": "Reset Password",
      "resetPasswordTitle": "Reset Your Password",
      "resetPasswordMessage": "Enter your email address and we'll send you a code to reset your password.",
      "resetCodeMessage": "We've sent a 6-digit code to {email}. Enter it below along with your new password.",
      "resetCode": "Reset Code",
      "enterResetCode": "Enter Reset Code",
      "sendResetCode": "Send Reset Code",
      "resendCode": "Resend Code",
      "resetCodeSent": "Reset code sent!",
      "newPassword": "New Password",
      "enterNewPassword": "Enter new password",
      "confirmPassword": "Confirm Password",
      "enterPasswordAgain": "Enter password again",
      "passwordsDoNotMatch": "Passwords do not match",
      "passwordTooShort": "Password must be at least 8 characters",
      "passwordResetSuccess": "Password reset successfully!",
      "pleaseEnterResetCode": "Please enter the reset code",
      "pleaseEnterPassword": "Please enter a password",
      "pleaseEnterEmail": "Please enter your email address",
      "invalidEmail": "Please enter a valid email address",
      "backToLogin": "Back to Login",
      "enterEmail": "Enter your email",
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
      "helpWelcomeTitle": "Welcome to Help & Support",
      "helpWelcomeMessage": "I'm a solo developer working on Yummy. While I don't have a dedicated support team, I'm here to help! Please check the FAQs below first, and if you still need assistance, feel free to reach out.",
      "faq": "Frequently Asked Questions",
      "faqHowToCreateRecipe": "How do I create a recipe?",
      "faqHowToCreateRecipeAnswer": "Tap the '+' button in the navigation bar. Fill in the recipe details including title, description, ingredients, steps, and images, then save.",
      "faqHowToSaveRecipe": "How do I save a recipe?",
      "faqHowToSaveRecipeAnswer": "When viewing a recipe, tap the bookmark icon to save it. You can view all your saved recipes from the menu under 'Saved Recipes'.",
      "faqHowToSearch": "How do I search for recipes?",
      "faqHowToSearchAnswer": "Use the search icon in the navigation bar. You can search by recipe name, ingredients, or cuisine type. Use filters to narrow down your search results.",
      "faqHowToFollowUser": "How do I follow other users?",
      "faqHowToFollowUserAnswer": "Visit a user's profile and tap the 'Follow' button. You'll see their recipes in your 'Following' feed.",
      "faqAccountIssues": "I'm having trouble with my account. What should I do?",
      "faqAccountIssuesAnswer": "Try logging out and logging back in. If you've forgotten your password, use the password reset option on the login screen. If issues persist, contact us using the information below.",
      "faqAppNotWorking": "The app isn't working properly. What can I do?",
      "faqAppNotWorkingAnswer": "First, try closing and reopening the app. If that doesn't help, try restarting your device. Make sure you have a stable internet connection. If the problem continues, please report it using the bug reporting section below.",
      "reportIssues": "Report Issues & Bugs",
      "reportIssuesInstructions": "When reporting a bug or issue, please include:",
      "reportIssuesAppVersion": "App version (shown below)",
      "reportIssuesDeviceInfo": "Your device type and OS version",
      "reportIssuesStepsToReproduce": "Steps to reproduce the issue",
      "reportIssuesScreenshots": "Screenshots if possible",
      "reportIssuesExpectedBehavior": "What you expected to happen",
      "reportIssuesNote": "Note: As a solo developer, I may not be able to respond immediately, but I review all reports and work on fixes in order of priority.",
      "contactUs": "Contact Us",
      "contactEmail": "Email Support",
      "copyEmailAddress": "Copy Email Address",
      "copyEmailAddressSubtitle": "Copy the support email to your clipboard",
      "emailCopiedToClipboard": "Email address copied to clipboard",
      "appInformation": "App Information",
      "appDescription": "Your personal recipe collection and sharing platform",
      "versionCopiedToClipboard": "Version copied to clipboard",
      "tourWelcomeTitle": "Welcome to Yummy! 👋",
      "tourWelcomeDescription": "This is your home feed. Discover amazing recipes from the community and find your next meal inspiration!",
      "tourSearchTitle": "Search Recipes 🔍",
      "tourSearchDescription": "Find recipes by name, ingredients, or cuisine type.",
      "tourCreateTitle": "Share Your Recipes ✨",
      "tourCreateDescription": "Tap here to create and share your own recipes with the community. Add photos, ingredients, and steps!",
      "tourNotificationsTitle": "Stay Updated 🔔",
      "tourNotificationsDescription": "Get notified when someone likes your recipes, follows you, or comments on your posts!",
      "tourMenuTitle": "More Features 📱",
      "tourMenuDescription": "Access saved recipes, notifications, settings, and more from the menu.",
      "tourSortTitle": "Sort Your Feed 🔽",
      "tourSortDescription": "Switch between Recent (newest first) and Top (most popular) posts. Choose what matters to you!",
      "tourViewToggleTitle": "Switch Views 👁️",
      "tourViewToggleDescription": "Toggle between list view and full-screen immersive view for a different browsing experience!",
      "tourTapToContinue": "Tap the highlighted area to continue",
      "tourAllSet": "You're all set! Enjoy using Yummy! 🎉",
    },
    "ka": {
      "appTitle": "Yummy",
      "login": "შესვლა",
      "signUp": "რეგისტრაცია",
      "email": "ელ-ფოსტა",
      "emailHint": "შეიყვანეთ თქვენი ელ-ფოსტა",
      "password": "პაროლი",
      "passwordHint": "შეიყვანეთ თქვენი პაროლი",
      "createAccount": "ანგარიშის შექმნა",
      "username": "მომხმარებლის სახელი",
      "displayName": "როგორ გინდათ თქვენი სახელი გამოჩნდეს? (არასავალდებულო)",
      "passwordMin": "პაროლი (მინ. 8)",
      "continueWithGoogle": "გაგრძელება Google-ით",
      "orContinue": "ან გაგრძელება",
      "rememberMe": "დამახსოვრება",
      "forgotPassword": "დაგავიწყდათ პაროლი?",
      "forgotPasswordComingSoon": "პაროლის აღდგენის ფუნქცია მალე გამოჩნდება!",
      "dontHaveAccount": "არ გაქვთ ანგარიში?",
      "googleSignInFailed": "Google-ით შესვლა ვერ მოხერხდა. გთხოვთ, სცადოთ თავიდან.",
      "showPassword": "პაროლის ჩვენება",
      "hidePassword": "პაროლის დამალვა",
      "appTagline": "თქვენი რეცეპტების მოგზაურობა",
      "menu": "მენიუ",
      "createRecipe": "რეცეპტის შექმნა",
      "notifications": "შეტყობინებები",
      "markAllRead": "ყველას წაკითხულად მონიშვნა",
      "allNotifications": "ყველა შეტყობინება",
      "unreadOnly": "მხოლოდ წაუკითხავი",
      "search": "ძიება",
      "logout": "გასვლა",
      "logoutConfirmation": "დარწმუნებული ხართ, რომ გსურთ გასვლა?",
      "feed": "არხი",
      "recent": "უახლესი",
      "top": "ყველაზე პოპულარული",
      "sortBy": "დალაგების კრიტერიუმი",
      "retry": "ხელახლა ცდა",
      "cancel": "გაუქმება",
      "delete": "წაშლა",
      "add": "დამატება",
      "save": "შენახვა",
      "apply": "გამოყენება",
      "clearAll": "ყველას გასუფთავება",
      "applyFilters": "გაფილტვრა",
      "global": "გლობალური",
      "seeRecipesFromEveryone": "იხილეთ რეცეპტები ყველასგან",
      "following": "გამოწერილი",
      "seeRecipesFromPeopleYouFollow": "იხილეთ რეცეპტები გამოწერილი მომხმარებლებისგან",
      "logInToSeeFollowingFeed": "შედით სისტემაში გამოწერილი გვერდის სანახავად",
      "popular": "პოპულარული",
      "mostPopularRecipes": "ყველაზე პოპულარული რეცეპტები",
      "trending": "ტრენდული",
      "trendingNow": "ახლა ტრენდული",
      "savedRecipes": "შენახული რეცეპტები",
      "viewYourBookmarkedRecipes": "იხილეთ თქვენი შენახული რეცეპტები",
      "analyticsStatistics": "ანალიტიკური სტატისტიკა",
      "viewTrackingStatistics": "ნახვების სტატისტიკის ნახვა",
      "profile": "პროფილი",
      "viewProfile": "პროფილის ნახვა",
      "allTime": "ყველა დროის",
      "last30Days": "ბოლო 30 დღე",
      "last7Days": "ბოლო 7 დღე",
      "timePeriod": "პერიოდი",
      "days": "დღეები",
      "windowDays": "დროის ინტერვალი (დღეებში)",
      "oneDay": "1 დღე",
      "threeDays": "3 დღე",
      "sevenDays": "7 დღე",
      "fourteenDays": "14 დღე",
      "thirtyDays": "30 დღე",
      "listView": "სიის ხედი",
      "fullScreenView": "სრული ეკრანის ხედი",
      "noMoreItems": "მეტი ელემენტი არ არის",
      "noSavedRecipes": "შენახული რეცეპტები ცარიელია",
      "startBookmarkingRecipes": "დაიწყეთ რეცეპტების შენახვა აქ გამოსაჩენად",
      "noStatisticsAvailable": "სტატისტიკა მიუწვდომელია",
      "noRecipesFound": "რეცეპტი არ მოიძებნა",
      "tryDifferentSearch": "სცადეთ სხვა საძიებო სიტყვა",
      "noUsersFound": "მომხმარებელი არ მოიძებნა",
      "noResultsFound": "შედეგები არ მოიძებნა",
      "noRecentSearches": "ბოლო ძიებები არ არის",
      "searchHistoryWillAppear": "თქვენი ძიების ისტორია აქ გამოჩნდება",
      "recentSearches": "ბოლო ძიებები",
      "users": "მომხმარებლები",
      "recipes": "რეცეპტები",
      "seeAll": "ყველას ნახვა",
      "notLoggedIn": "არ ხართ შესული",
      "errorLoadingStatistics": "სტატისტიკის ჩატვირთვის შეცდომა",
      "noEventDataAvailable": "მოვლენების მონაცემები მიუწვდომელია",
      "noRecipeDataAvailable": "რეცეპტების მონაცემები მიუწვდომელია",
      "noDailyEventDataAvailable": "ყოველდღიური მოვლენების მონაცემები მიუწვდომელია",
      "noEventsRecorded": "მოვლენები არ არის",
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
      "followers": "გამომწერები",
      "followingTitle": "გამოწერილი",
      "totalLikes": "მოწონებები",
      "private": "პირადი",
      "thisUsersFollowersListIsPrivate": "ამ მომხმარებლის მიმდევრების სია დახურულია",
      "noFollowers": "გამომწერები არ არიან",
      "thisUserDoesntHaveAnyFollowersYet": "ამ მომხმარებელს ჯერ არ ყავს გამომწერები",
      "thisUsersFollowingListIsPrivate": "ამ მომხმარებლის გამოწერების სია დახურულია",
      "notFollowingAnyone": "არავინ ყავს გამომოწერილი",
      "thisUserIsntFollowingAnyoneYet": "ამ მომხმარებელს ჯერ არვინ ყავს გამოწერილი",
      "privacy": "კონფიდენციალურობა",
      "privateFollowers": "პირადი გამომწერები",
      "privateFollowing": "პირადი გამოწერები",
      "hideYourFollowersListFromOthers": "დამალეთ თქვენი გამომწერების სია სხვებისგან",
      "hideYourFollowingListFromOthers": "დამალეთ თქვენი გამოწერების სია სხვებისგან",
      "title": "სათაური",
      "enterRecipeTitle": "შეიყვანეთ რეცეპტის სათაური",
      "description": "აღწერა",
      "describeYourRecipe": "შეიყვანეთ რეცეპტის აღწერა",
      "cuisine": "სამზარეულო",
      "cuisineExample": "მაგ., იტალიური, მექსიკური, აზიური",
      "minTimeMinutes": "მინ. დრო (წუთები)",
      "maxTimeMinutes": "მაქს. დრო (წუთები)",
      "difficulty": "სირთულე",
      "easy": "მარტივი",
      "medium": "საშუალო",
      "hard": "რთული",
      "addTag": "თეგის დამატება",
      "tags": "თეგები",
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
      "cookWithWhatIHave": "რა მაქვს იმით მოვამზადო",
      "findRecipesWithIngredients": "იპოვეთ რეცეპტები იმ ინგრედიენტებით, რაც გაქვთ",
      "addIngredientsToStart": "დაამატეთ ინგრედიენტები დასაწყებად",
      "addIngredientsDescription": "დაამატეთ ინგრედიენტები, რომლებიც გაქვთ და ჩვენ ვიპოვით რეცეპტებს, რომლებიც შეგიძლიათ მოამზადოთ",
      "tryDifferentIngredients": "სცადეთ სხვა ინგრედიენტების დამატება ან შემცირეთ შესაბამისობის ზღვარი",
      "enterIngredient": "შეიყვანეთ ინგრედიენტი...",
      "matchThreshold": "შესაბამისობის ზღვარი:",
      "findRecipes": "რეცეპტების პოვნა",
      "missing": "აკლია",
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
      "eventTimeline": "მოვლენების ინტერვალები",
      "views": "ნახვები",
      "likes": "მოწონებები",
      "bookmarks": "შენახულები",
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
      "recipeCreatedSuccessfully": "რეცეპტი წარმატებით შეიქმნა",
      "recipeUpdatedSuccessfully": "რეცეპტი წარმატებით განახლდა",
      "notFound": "არ მოიძებნა",
      "somethingWentWrong": "რაღაც შეცდომა მოხდა",
      "steps": "ნაბიჯები",
      "noStepsYet": "ნაბიჯი ჯერ არ არის. დაამატეთ დასაწყებად!",
      "noIngredientsYet": "ინგრედიენტები ჯერ არ არის. დაამატეთ პირველი!",
      "addCoverPhoto": "დაამატეთ გარეკანის ფოტო",
      "tapToUpload": "შეეხეთ ატვირთვისთვის",
      "basicInfo": "ძირითადი ინფორმაცია",
      "cookingDetails": "მომზადების დეტალები",
      "saveChanges": "ცვლილებების შენახვა",
      "publishRecipe": "რეცეპტის გამოქვეყნება",
      "settings": "პარამეტრები",
      "appPreferences": "აპის პარამეტრები",
      "feedPreferences": "ფიდის პარამეტრები",
      "quickAccess": "სწრაფი წვდომა",
      "appearance": "გაფორმება",
      "themeMode": "გაფორმების რეჟიმი",
      "system": "სისტემა",
      "light": "ნათელი",
      "dark": "მუქი",
      "account": "პროფილი",
      "about": "შესახებ",
      "version": "ვერსია",
      "followSystemTheme": "სისტემის გაფორმების მიხედვით",
      "lightTheme": "ნათელი გაფორმება",
      "darkTheme": "მუქი გაფორმება",
      "englishLanguage": "ინგლისური",
      "georgianLanguage": "ქართული",
      "helpAndSupport": "დახმარება და მხარდაჭერა",
      "termsAndPrivacy": "წესები და კონფიდენციალურობა",
      "termsOfService": "მომსახურების წესები",
      "privacyPolicy": "კონფიდენციალურობის პოლიტიკა",
      "termsAcceptanceTitle": "1. წესების თანხმობა",
      "termsAcceptanceContent": "Yummy-ის გამოყენებით თქვენ ეთანხმებით ამ შეთანხმების წესებსა და დებულებებს.",
      "termsLicenseTitle": "2. გამოყენების ლიცენზია",
      "termsLicenseContent": "ნებართვა გაქვთ Yummy-ის აპლიკაცია გაოიყენოთ პირადი, არაკომერციული მიზნებისთვის. ეს ლიცენზია არ მოიცავს:\n\n• სერვისის გადაყიდვას ან ქვე-ლიცენზირებას\n• სერვისის გამოყენებას ნებისმიერი კომერციული მიზნით\n• საავტორო უფლებების ან საკუთრებითი აღნიშვნების მოხსნას",
      "termsAccountsTitle": "3. მომხმარებლის ანგარიშები",
      "termsAccountsContent": "თქვენ პასუხისმგებელი ხართ თქვენი ანგარიშის მონაცემების კონფიდენციალურობის შენარჩუნებაზე. თქვენ ეთანხმებით:\n\n• ზუსტი და სრული ინფორმაციის მიწოდებას\n• პაროლის უსაფრთხო შენარჩუნებას\n• ნებისმიერი არაავტორიზებული გამოყენების შესახებ დაუყოვნებლივ შეტყობინებას",
      "termsContentTitle": "4. მომხმარებლის კონტენტი",
      "termsContentContent": "თქვენ რჩებით Yummy-ზე გამოქვეყნებული კონტენტის მფლობელად. კონტენტის გამოქვეყნებით, თქვენ გვაძლევთ კონტენტის გამოყენების, შეცვლისა და პლატფორმაზე ჩვენების უფლებას.",
      "termsProhibitedTitle": "5. აკრძალული გამოყენება",
      "termsProhibitedContent": "თქვენ არ შეგიძლიათ Yummy-ის გამოყენება:\n\n• ნებისმიერი კანონის ან რეგულაციის დარღვევისთვის\n• ინტელექტუალური საკუთრების უფლებების დარღვევისთვის\n• მავნე, შეურაცხმყოფელი ან უკანონო კონტენტის გამოსაქვეყნებლად\n• სპამის ან სხვა მომხმარებლების შევიწროებისთვის",
      "termsTerminationTitle": "6. შეწყვეტა",
      "termsTerminationContent": "ჩვენ ვიტოვებთ უფლებას დავხუროთ ან შევაჩეროთ თქვენი ანგარიში ნებისმიერ დროს ამ წესების დარღვევის შემთხვევაში.",
      "termsChangesTitle": "7. წესების ცვლილებები",
      "termsChangesContent": "ჩვენ ვიტოვებთ უფლებას, შევცვალოთ ეს წესები ნებისმიერ დროს. სერვისის გამოყენების გაგრძელება ცვლილებების შემდეგ ნიშნავს ახალ წესებზე თანხმობას.",
      "privacyCollectTitle": "1. ინფორმაცია, რომელსაც ვაგროვებთ",
      "privacyCollectContent": "ჩვენ ვაგროვებთ ინფორმაციას, რომელსაც პირდაპირ გვაწვდით, მათ შორის:\n\n• ანგარიშის ინფორმაცია (მომხმარებლის სახელი, ელფოსტა, საჩვენებელი სახელი)\n• თქვენ მიერ შექმნილი კონტენტი (რეცეპტები, კომენტარები, სურათები)\n• გამოყენების მონაცემები და ანალიტიკა\n• მოწყობილობის ინფორმაცია და იდენტიფიკატორები",
      "privacyUseTitle": "2. როგორ ვიყენებთ თქვენს ინფორმაციას",
      "privacyUseContent": "ჩვენ ვიყენებთ შეგროვებულ ინფორმაციას:\n\n• ჩვენი სერვისების მიწოდებისა და გაუმჯობესებისთვის\n• თქვენი გამოცდილების პერსონალიზაციისთვის\n• თქვენი ანგარიშის შესახებ კომუნიკაციისთვის\n• გამოყენების ნიმუშებისა და ტენდენციების ანალიზისთვის\n• უსაფრთხოების უზრუნველსაყოფად და თაღლითობის თავიდან ასაცილებლად",
      "privacySharingTitle": "3. ინფორმაციის გაზიარება",
      "privacySharingContent": "ჩვენ არ ვყიდით თქვენს პირად ინფორმაციას. ჩვენ შეიძლება გავაზიაროთ თქვენი ინფორმაცია მხოლოდ:\n\n• თქვენი თანხმობით\n• კანონიერი ვალდებულებების შესასრულებლად\n• ჩვენი უფლებებისა და უსაფრთხოების დასაცავად\n• სერვისების მიმწოდებლებთან, რომლებიც გვეხმარებიან (მკაცრი კონფიდენციალურობის შეთანხმებებით)",
      "privacySecurityTitle": "4. მონაცემების უსაფრთხოება",
      "privacySecurityContent": "ჩვენ ვიყენებთ შესაბამის ტექნიკურ და ორგანიზაციულ ზომებს თქვენი პირადი ინფორმაციის დასაცავად. თუმცა, ინტერნეტით გადაცემის არცერთი მეთოდი არ არის 100% უსაფრთხო.",
      "privacyRightsTitle": "5. თქვენი უფლებები",
      "privacyRightsContent": "თქვენ გაქვთ უფლება:\n\n• წვდომა თქვენს პირად ინფორმაციაზე\n• არასწორი ინფორმაციის შესწორება\n• თქვენი ანგარიშისა და მონაცემების წაშლა\n• ზოგიერთი მონაცემის დამუშავებაზე უარის თქმა\n• თქვენი მონაცემების ექსპორტი",
      "privacyCookiesTitle": "6. ქუქი და თვალყური",
      "privacyCookiesContent": "ჩვენ ვიყენებთ ქუქის და მსგავს ტექნოლოგიებს თქვენი გამოცდილებისა და მარკეტინგული წვდომის გასაუმჯობესებლად, გამოყენების ანალიზისთვის.",
      "privacyChildrenTitle": "7. ბავშვების კონფიდენციალურობა",
      "privacyChildrenContent": "Yummy არ არის განკუთვნილი 13 წლამდე მომხმარებლებისთვის. ჩვენ შეგნებულად არ ვაგროვებთ პირად ინფორმაციას 13 წლამდე ბავშვებისგან.",
      "privacyChangesTitle": "8. კონფიდენციალურობის პოლიტიკის ცვლილებები",
      "privacyChangesContent": "ჩვენ შეიძლება დროდადრო განვაახლოთ ჩვენი კონფიდენციალურობის პოლიტიკა. ჩვენ შეგატყობინებთ ნებისმიერი მნიშვნელოვანი ცვლილების შესახებ ახალი პოლიტიკის ამ გვერდზე განთავსებით.",
      "privacyContactTitle": "9. დაგვიკავშირდით",
      "privacyContactContent": "თუ გაქვთ კითხვები ამ კონფიდენციალურობის პოლიტიკის შესახებ, გთხოვთ დაგვიკავშირდეთ აპლიკაციის პარამეტრებით ან მხარდაჭერის არხებით.",
      "acceptTermsText": "ვეთანხმები ",
      "acceptTermsFull": "მე წავიკითხე და ვეთანხმები წესებსა და კონფიდენციალურობის პოლიტიკას",
      "viewFullTerms": "წესებისა და კონფიდენციალურობის პოლიტიკის სრული ნახვა",
      "termsSummary": "მთავარი პუნქტები: თქვენ პასუხისმგებელი ხართ თქვენი ანგარიშისთვის, თქვენ რჩებით თქვენი კონტენტის მფლობელად და თქვენ ეთანხმებით, რომ არ გამოიყენებთ სერვისს აკრძალული მიზნებისთვის.",
      "privacySummary": "ჩვენ ვაგროვებთ თქვენ მიერ მოწოდებულ ინფორმაციას, გამოყენების მონაცემებსა და მოწყობილობის ინფორმაციას. ჩვენ ვიყენებთ ამას ჩვენი სერვისების მიწოდებისა და გაუმჯობესებისთვის, თქვენი გამოცდილების პერსონალიზაციისა და უსაფრთხოების უზრუნველსაყოფად. ჩვენ არ ვყიდით თქვენს პირად ინფორმაციას.",
      "privacyRightsSummary": "თქვენ გაქვთ უფლება წვდომა, შესწორება, წაშლა და ექსპორტი თქვენი მონაცემების. თქვენ შეგიძლიათ უარი თქვათ ზოგიერთი მონაცემების დამუშავებიდან.",
      "verifyEmail": "ელფოსტის დადასტურება",
      "verifyEmailTitle": "დაადასტურეთ თქვენი ელფოსტა",
      "verifyEmailMessage": "ჩვენ გავაგზავნეთ დადასტურების კოდი {email}-ზე. გთხოვთ შეიყვანოთ იგი ქვემოთ თქვენი ელფოსტის მისამართის დასადასტურებლად.",
      "verificationCode": "დადასტურების კოდი",
      "enterVerificationCode": "შეიყვანეთ კოდი თქვენი ელფოსტიდან",
      "verify": "დადასტურება",
      "resendVerificationCode": "კოდის ხელახლა გაგზავნა",
      "verificationEmailSent": "დადასტურების ელფოსტა გაიგზავნა!",
      "pleaseEnterVerificationCode": "გთხოვთ შეიყვანოთ დადასტურების კოდი",
      "resetPassword": "პაროლის აღდგენა",
      "resetPasswordTitle": "აღადგინეთ თქვენი პაროლი",
      "resetPasswordMessage": "შეიყვანეთ თქვენი ელფოსტის მისამართი და ჩვენ გამოგიგზავნით კოდს პაროლის აღსადგენად.",
      "resetCodeMessage": "ჩვენ გავაგზავნეთ 6-ნიშნა კოდი {email}-ზე. შეიყვანეთ იგი ქვემოთ ახალ პაროლთან ერთად.",
      "resetCode": "აღდგენის კოდი",
      "enterResetCode": "შეიყვანეთ აღდგენის კოდი",
      "sendResetCode": "აღდგენის კოდის გაგზავნა",
      "resendCode": "კოდის ხელახლა გაგზავნა",
      "resetCodeSent": "აღდგენის კოდი გაიგზავნა!",
      "newPassword": "ახალი პაროლი",
      "enterNewPassword": "შეიყვანეთ ახალი პაროლი",
      "confirmPassword": "პაროლის დადასტურება",
      "enterPasswordAgain": "შეიყვანეთ პაროლი ხელახლა",
      "passwordsDoNotMatch": "პაროლები არ ემთხვევა",
      "passwordTooShort": "პაროლი უნდა იყოს მინიმუმ 8 სიმბოლო",
      "passwordResetSuccess": "პაროლი წარმატებით აღდგა!",
      "pleaseEnterResetCode": "გთხოვთ შეიყვანოთ აღდგენის კოდი",
      "pleaseEnterPassword": "გთხოვთ შეიყვანოთ პაროლი",
      "pleaseEnterEmail": "გთხოვთ შეიყვანოთ თქვენი ელფოსტის მისამართი",
      "invalidEmail": "გთხოვთ შეიყვანოთ ვალიდური ელფოსტის მისამართი",
      "backToLogin": "შესვლაზე დაბრუნება",
      "enterEmail": "შეიყვანეთ თქვენი ელფოსტა",
      "dismiss": "დახურვა",
      "unableToConnect": "სერვერთან დაკავშირება ვერ მოხერხდა. გთხოვთ შეამოწმოთ ინტერნეტ-კავშირი და სცადოთ ხელახლა.",
      "requestTimedOut": "მოთხოვნის დრო ამოიწურა. გთხოვთ სცადოთ ხელახლა.",
      "connectionInterrupted": "კავშირი შეწყდა. გთხოვთ სცადოთ ხელახლა.",
      "needToLogIn": "ამ ქმედების შესასრულებლად საჭიროა შესვლა.",
      "noPermission": "ამ ქმედების შესრულების უფლება არ გაქვთ.",
      "itemNotFound": "მოთხოვნილი ელემენტი ვერ მოიძებნა.",
      "invalidInput": "არასწორი მონაცემები. გთხოვთ შეამოწმოთ თქვენი მონაცემები და სცადოთ ხელახლა.",
      "invalidRequest": "არასწორი მოთხოვნა. გთხოვთ შეამოწმოთ შეყვანილი მონაცემები და სცადოთ ხელახლა.",
      "actionConflict": "ეს ქმედება ეწინააღმდეგება მიმდინარე მდგომარეობას. გთხოვთ განაახლოთ და სცადოთ ხელახლა.",
      "fileTooLarge": "ფაილი ძალიან დიდია. გთხოვთ გამოიყენოთ უფრო პატარა ფაილი.",
      "invalidData": "მოწოდებული მონაცემები არასწორია. გთხოვთ შეამოწმოთ შეყვანილი მონაცემები.",
      "tooManyRequests": "ძალიან ბევრი მოთხოვნა. გთხოვთ მოიცადოთ და სცადოთ ხელახლა.",
      "serverError": "სერვერის შეცდომა. გთხოვთ სცადოთ მოგვიანებით.",
      "errorOccurred": "შეცდომა. გთხოვთ სცადოთ ხელახლა.",
      "minTimeCannotBeGreater": "მინიმალური დრო არ შეიძლება იყოს მაქსიმალურ დროზე მეტი",
      "minCookingTimeCannotBeGreater": "მინიმალური მომზადების დრო არ შეიძლება იყოს მაქსიმალურ დროზე მეტი",
      "minCookingTimeMustBeValidNumber": "მინიმალური მომზადების დრო უნდა იყოს სწორი რიცხვი",
      "maxCookingTimeMustBeValidNumber": "მაქსიმალური მომზადების დრო უნდა იყოს სწორი რიცხვი",
      "pleaseAddAtLeastOneIngredient": "გთხოვთ დაამატოთ მინიმუმ ერთი ინგრედიენტი",
      "pleaseAddAtLeastOneStep": "გთხოვთ დაამატოთ მინიმუმ ერთი ნაბიჯი",
      "ingredientNameRequired": "ინგრედიენტი {index}: სახელი აუცილებელია",
      "stepInstructionRequired": "ნაბიჯი {index}: ინსტრუქცია აუცილებელია",
      "helpWelcomeTitle": "კეთილი იყოს თქვენი მობრძანება დახმარებისა და მხარდაჭერის გვერდზე",
      "helpWelcomeMessage": "Yummy-ზე მუშაობს მხოლოდ ერთი დეველოპერი. მიუხედავად იმისა, რომ არ მყავს გამოყოფილი მხარდაჭერის გუნდი, შევეცდები ყველაფერში დაგეხმაროთ! გთხოვთ ჯერ გადახედოთ ხშირად დასმულ კითხვებს, და თუ კვლავ დაგჭირდებათ დახმარება, დამიკავშირდით.",
      "faq": "ხშირად დასმული კითხვები",
      "faqHowToCreateRecipe": "როგორ შევქმნა რეცეპტი?",
      "faqHowToCreateRecipeAnswer": "დააჭირეთ '+' ღილაკს ნავიგაციის ზოლში. შეავსეთ რეცეპტის დეტალები, მათ შორის სათაური, აღწერა, ინგრედიენტები, ნაბიჯები, სურათები და შეინახეთ.",
      "faqHowToSaveRecipe": "როგორ შევინახო რეცეპტი?",
      "faqHowToSaveRecipeAnswer": "რეცეპტის ნახვისას, დააჭირეთ სანიშნის ხატულას მის შესანახად. თქვენ შეგიძლიათ ნახოთ ყველა თქვენი შენახული რეცეპტი მენიუდან 'შენახული რეცეპტები'.",
      "faqHowToSearch": "როგორ ვიპოვო რეცეპტი?",
      "faqHowToSearchAnswer": "გამოიყენეთ ძიების ხატულა ნავიგაციის ზოლში. თქვენ შეგიძლიათ ძიება რეცეპტის სახელით, ინგრედიენტებით ან სამზარეულოს ტიპით. გამოიყენეთ ფილტრები შედეგების შესამცირებლად.",
      "faqHowToFollowUser": "როგორ გამოვიწერო სხვა მომხმარებელი?",
      "faqHowToFollowUserAnswer": "ეწვიეთ მომხმარებლის პროფილს და დააჭირეთ 'გამოწერა' ღილაკს. თქვენ ნახავთ მათ რეცეპტებს თქვენს 'გამოწერილი' არხში.",
      "faqAccountIssues": "პრობლემა მაქვს ჩემს ანგარიშთან. რა უნდა გავაკეთო?",
      "faqAccountIssuesAnswer": "სცადეთ აპლიკაციიდან გასვლა და ხელახლა შესვლა. თუ დაგავიწყდათ პაროლი, გამოიყენეთ პაროლის აღდგენის ოფცია შესვლის ეკრანზე. თუ პრობლემა ისევ გაქვთ, დაგვიკავშირდით ქვემოთ მოცემული ინფორმაციის გამოყენებით.",
      "faqAppNotWorking": "აპლიკაცია სწორად არ მუშაობს. რა შემიძლია გავაკეთო?",
      "faqAppNotWorkingAnswer": "ჯერ სცადეთ აპლიკაციის დახურვა და ხელახლა გახსნა. თუ ეს არ დაგეხმარათ, სცადეთ მოწყობილობის გადატვირთვა. დარწმუნდით, რომ გაქვთ სტაბილური ინტერნეტ-კავშირი. თუ პრობლემა არ მოგვარდა, გთხოვთ შეგვატყობინოთ ამის შესახებ შეცდომების შეტყობინების განყოფილების გამოყენებით.",
      "reportIssues": "პრობლემებისა და შეცდომების შეტყობინება",
      "reportIssuesInstructions": "შეცდომის ან პრობლემის შეტყობინებისას, გთხოვთ მოგვაწოდოთ შემდეგი ინფორმაცია:",
      "reportIssuesAppVersion": "აპლიკაციის ვერსია (ნაჩვენებია ქვემოთ)",
      "reportIssuesDeviceInfo": "თქვენი მოწყობილობის ტიპი და OS ვერსია",
      "reportIssuesStepsToReproduce": "ნაბიჯები პრობლემის გამოსაწვევად",
      "reportIssuesScreenshots": "სურათები, თუ შესაძლებელია",
      "reportIssuesExpectedBehavior": "რას მოელოდით რომ მოხდებოდა",
      "reportIssuesNote": "შენიშვნა: როგორც სოლო დეველოპერს, შეიძლება არ შემეძლოს დაუყოვნებლივ პასუხის გაცემა, მაგრამ მე განვიხილავ ყველა შეტყობინებას და ვმუშაობ გამოსწორებებზე პრიორიტეტის მიხედვით.",
      "contactUs": "დაგვიკავშირდით",
      "contactEmail": "ელფოსტის მხარდაჭერა",
      "copyEmailAddress": "ელფოსტის მისამართის კოპირება",
      "copyEmailAddressSubtitle": "დააკოპირეთ მხარდაჭერის ელფოსტა თქვენს ბუფერში",
      "emailCopiedToClipboard": "ელფოსტის მისამართი დაკოპირდა ბუფერში",
      "appInformation": "აპლიკაციის ინფორმაცია",
      "appDescription": "თქვენი პერსონალური რეცეპტების კოლექცია და გაზიარების პლატფორმა",
      "versionCopiedToClipboard": "ვერსია დაკოპირდა ბუფერში",
      "tourWelcomeTitle": "კეთილი იყოს თქვენი მობრძანება Yummy-ში! 👋",
      "tourWelcomeDescription": "ეს არის თქვენი მთავარი არხი. აღმოაჩინეთ საოცარი რეცეპტები მომხმარებლებისგან და იპოვეთ თქვენი შემდეგი კერძის იდეა!",
      "tourSearchTitle": "რეცეპტების ძიება 🔍",
      "tourSearchDescription": "იპოვეთ რეცეპტები სახელით, ინგრედიენტებით ან სამზარეულოს ტიპით.",
      "tourCreateTitle": "გააზიარეთ თქვენი რეცეპტები ✨",
      "tourCreateDescription": "დააჭირეთ აქ თქვენი რეცეპტის შესაქმნელად და სხვა მომხმარებლებთან გასაზიარებლად. დაამატეთ ფოტოები, ინგრედიენტები და ნაბიჯები!",
      "tourNotificationsTitle": "იყავით ინფორმირებული 🔔",
      "tourNotificationsDescription": "მიიღეთ შეტყობინებები როდესაც ვიღაც მოიწონებს თქვენს რეცეპტებს, გამოგიწერთ ან კომენტარს დაგიწერთ!",
      "tourMenuTitle": "სხვა ფუნქციები 📱",
      "tourMenuDescription": "წვდომა შენახულ რეცეპტებზე, შეტყობინებებზე, პარამეტრებზე და სხვა აპლიკაციის ფუნქციებზე მენიუდან.",
      "tourSortTitle": "დაალაგეთ თქვენი არხი 🔽",
      "tourSortDescription": "გადართეთ უახლესი (ახალი პირველი) და ტოპ (ყველაზე პოპულარული) პოსტებს შორის. აირჩიეთ რაც მნიშვნელოვანია თქვენთვის!",
      "tourViewToggleTitle": "გადართეთ ხედები 👁️",
      "tourViewToggleDescription": "გადართეთ სიის ხედსა და სრულეკრანიან ხედს შორის განსხვავებული გამოცდილებისთვის!",
      "tourTapToContinue": "გასაგრძელებლად შეეხეთ მონიშნულ არეს",
      "tourAllSet": "ყველაფერი მზადაა! ისიამოვნეთ Yummy-ს გამოყენებით! 🎉",
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
