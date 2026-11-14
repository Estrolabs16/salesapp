import 'package:flutter_test/flutter_test.dart';

import 'package:estroshop/data/models/customer.dart';
import 'package:estroshop/data/models/product.dart';
import 'package:estroshop/state/cart_controller.dart';

Product product({
  String id = 'p1',
  String name = 'Water',
  double cost = 600,
  double price = 1000,
  int stock = 10,
}) {
  return Product(
    id: id,
    name: name,
    costPrice: cost,
    sellingPrice: price,
    stock: stock,
  );
}

void main() {
  group('CartController', () {
    test('adds products and computes totals with tax', () {
      final cart = CartController(taxRate: 10);
      final water = product();

      expect(cart.add(water), isTrue);
      expect(cart.add(water), isTrue);

      expect(cart.itemCount, 2);
      expect(cart.subtotal, 2000);
      expect(cart.taxable, 2000);
      expect(cart.tax, 200);
      expect(cart.total, 2200);
      expect(cart.totalCost, 1200);
      expect(cart.grossProfit, 800);
    });

    test('never exceeds available stock', () {
      final cart = CartController();
      final water = product(stock: 2);

      expect(cart.add(water), isTrue);
      expect(cart.add(water), isTrue);
      expect(cart.add(water), isFalse);
      expect(cart.itemCount, 2);
    });

    test('rejects out of stock and inactive products', () {
      final cart = CartController();
      expect(cart.add(product(stock: 0)), isFalse);
      expect(cart.add(product(stock: 5).copyWith(active: false)), isFalse);
      expect(cart.isEmpty, isTrue);
    });

    test('clamps discount to subtotal and recalculates tax', () {
      final cart = CartController(taxRate: 10);
      final water = product();
      cart.add(water);
      cart.add(water);
      cart.add(water);

      cart.setDiscount(999999);

      expect(cart.subtotal, 3000);
      expect(cart.effectiveDiscount, 3000);
      expect(cart.taxable, 0);
      expect(cart.tax, 0);
      expect(cart.total, 0);
      expect(cart.grossProfit, -1800);
    });

    test('tracks cash received and change due', () {
      final cart = CartController();
      cart.add(product(price: 1500, stock: 3));
      cart.setCashReceived(2000);

      expect(cart.requiresCash, isTrue);
      expect(cart.hasEnoughCash, isTrue);
      expect(cart.changeDue, 500);

      cart.setPaymentMethod('Card');
      expect(cart.requiresCash, isFalse);
      expect(cart.hasEnoughCash, isTrue);
    });

    test('quantity controls remove lines at zero', () {
      final cart = CartController();
      final water = product(stock: 3);
      cart.add(water);
      cart.add(water);

      cart.decrement(water.id);
      expect(cart.itemCount, 1);

      cart.decrement(water.id);
      expect(cart.isEmpty, isTrue);

      cart.add(water);
      cart.setQuantity(water.id, 99);
      expect(cart.lines.single.quantity, 3);
    });

    test('attaches a customer and clears the cart', () {
      final cart = CartController();
      cart.add(product());
      cart.setCustomer(
        const Customer(id: 'c1', name: 'Amina', totalSpent: 500),
      );
      cart.setNote('Deliver at noon');
      cart.setDiscount(100);

      expect(cart.customer?.name, 'Amina');
      expect(cart.note, 'Deliver at noon');

      cart.clear();

      expect(cart.isEmpty, isTrue);
      expect(cart.customer, isNull);
      expect(cart.discount, 0);
      expect(cart.note, isEmpty);
    });

    test('builds sale items from cart lines', () {
      final cart = CartController();
      cart.add(product(id: 'p1', price: 1200, stock: 5));
      cart.add(product(id: 'p1', price: 1200, stock: 5));

      final items = cart.toSaleItems();
      expect(items, hasLength(1));
      expect(items.single.productId, 'p1');
      expect(items.single.quantity, 2);
      expect(items.single.unitPrice, 1200);
      expect(items.single.lineTotal, 2400);
    });
  });
}
