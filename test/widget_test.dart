// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recipe_app_fe/main.dart';
import 'package:recipe_app_fe/api/api_client.dart';
import 'package:recipe_app_fe/auth/auth_api.dart';
import 'package:recipe_app_fe/auth/auth_controller.dart';
import 'package:recipe_app_fe/auth/token_storage.dart';
import 'package:recipe_app_fe/theme/theme_controller.dart';
import 'package:recipe_app_fe/localization/language_controller.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Create mock dependencies for testing
    final tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);
    final authApi = AuthApi(apiClient);
    final authController = AuthController(authApi: authApi, tokenStorage: tokenStorage);
    final themeController = ThemeController();
    final languageController = LanguageController();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(
      authController: authController,
      apiClient: apiClient,
      themeController: themeController,
      languageController: languageController,
    ));

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
