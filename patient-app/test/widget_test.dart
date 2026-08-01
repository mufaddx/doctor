import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:touch_of_cure/core/storage/preferences_storage.dart';
import 'package:touch_of_cure/main.dart';

void main() {
  testWidgets('App boots to the splash screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesStorageProvider.overrideWithValue(PreferencesStorage(prefs)),
        ],
        child: const TouchOfCureApp(),
      ),
    );

    expect(find.byType(TouchOfCureApp), findsOneWidget);
  });
}
