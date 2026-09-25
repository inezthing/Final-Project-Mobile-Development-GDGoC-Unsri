import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whimsify/data/app_state.dart';
import 'package:whimsify/pages/main_navigation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://integration-test.supabase.co',
      publishableKey: 'sb_publishable_integration_test_key',
    );
  });

  testWidgets('main navigation opens profile and exposes both order flows', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(home: MainNavigation()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();

    expect(find.text('Pesanan Saya'), findsOneWidget);
    expect(find.text('Pesanan Masuk'), findsOneWidget);
    expect(find.text('Produk Saya'), findsOneWidget);
  });
}
