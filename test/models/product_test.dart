import 'package:flutter_test/flutter_test.dart';
import 'package:whimsify/models/models.dart';

void main() {
  group('Product.fromJson', () {
    test('parses product, seller, stock and purchase counters', () {
      final product = Product.fromJson({
        'id': 'product-1',
        'name': 'Vintage bag',
        'price': '125000.50',
        'seller_id': 'seller-1',
        'stock': '3',
        'purchase_count': '7',
        'payment_methods': ['Transfer'],
        'profiles': {'username': 'luna', 'is_verified': true},
        'favorites': [
          {'user_id': 'buyer-1'},
          {'user_id': 'buyer-2'},
        ],
        'listed_at': '2026-01-10T00:00:00.000Z',
      }, currentUserId: 'buyer-1');

      expect(product.id, 'product-1');
      expect(product.name, 'Vintage bag');
      expect(product.price, 125000.5);
      expect(product.sellerName, 'luna');
      expect(product.sellerVerified, isTrue);
      expect(product.stock, 3);
      expect(product.purchaseCount, 7);
      expect(product.favoritesCount, 2);
      expect(product.isFavorite, isTrue);
      expect(product.paymentMethods, ['Transfer']);
    });

    test('uses safe defaults for missing optional columns', () {
      final product = Product.fromJson({'id': 'old-product'});

      expect(product.name, 'Produk tanpa nama');
      expect(product.price, 0);
      expect(product.stock, 1);
      expect(product.purchaseCount, 0);
      expect(product.paymentMethods, isEmpty);
    });
  });

  test('CartItem checkout price uses accepted negotiated price', () {
    final product = Product(
      id: 'p1',
      name: 'Figure',
      brand: 'Toy',
      description: '',
      category: 'Collectible',
      price: 100000,
      condition: 'Good',
      size: 'One Size',
      sellerId: 'seller-1',
      sellerName: 'Mika',
      sellerVerified: false,
      listedAt: DateTime.utc(2026),
      paymentMethods: const [],
    );
    final item = CartItem(
      id: 'cart-1',
      product: product,
      quantity: 2,
      negotiatedPrice: 85000,
    );

    expect(item.effectivePrice, 85000);
    expect(item.isNegotiated, isTrue);
    expect(item.effectivePrice * item.quantity, 170000);
  });
}
