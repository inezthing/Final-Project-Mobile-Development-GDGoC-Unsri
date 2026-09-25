import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whimsify/data/app_state.dart';
import 'package:whimsify/models/models.dart';
import 'package:whimsify/widgets/product_card.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://unit-test.supabase.co',
      publishableKey: 'sb_publishable_unit_test_key',
    );
  });

  testWidgets('shows product name and formatted price and invokes tap', (
    tester,
  ) async {
    var wasTapped = false;
    final product = Product(
      id: 'p1',
      name: 'Vintage bag',
      brand: 'Whimsy',
      description: 'A test product',
      category: 'Bag',
      price: 25000,
      condition: 'Good',
      size: 'M',
      sellerId: 'seller-1',
      sellerName: 'Luna',
      sellerVerified: true,
      listedAt: DateTime.utc(2026),
      paymentMethods: const ['Transfer'],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 170,
              height: 250,
              child: ProductCard(
                product: product,
                onTap: () => wasTapped = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Vintage bag'), findsOneWidget);
    expect(find.text('Rp 25.000'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);

    await tester.tap(find.text('Vintage bag'));
    expect(wasTapped, isTrue);
  });
}
