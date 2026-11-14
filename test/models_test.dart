import 'package:flutter_test/flutter_test.dart';

import 'package:estroshop/core/utils/formatters.dart';
import 'package:estroshop/data/models/currency.dart';
import 'package:estroshop/data/models/customer.dart';
import 'package:estroshop/data/models/expense.dart';
import 'package:estroshop/data/models/product.dart';
import 'package:estroshop/data/models/sale.dart';
import 'package:estroshop/data/models/shop.dart';

void main() {
  group('Product', () {
    test('computes stock state and margins', () {
      const low = Product(
        id: 'p1',
        name: 'Water',
        costPrice: 600,
        sellingPrice: 1000,
        stock: 3,
        lowStockThreshold: 5,
      );
      expect(low.isLowStock, isTrue);
      expect(low.isOutOfStock, isFalse);
      expect(low.stockValue, 1800);
      expect(low.marginPercent, 40);

      const empty = Product(id: 'p2', name: 'Juice', stock: 0);
      expect(empty.isOutOfStock, isTrue);
      expect(empty.marginPercent, 0);
    });

    test('copyWith keeps existing values', () {
      const product = Product(id: 'p1', name: 'Water', stock: 10);
      final updated = product.copyWith(stock: 2, active: false);
      expect(updated.id, 'p1');
      expect(updated.name, 'Water');
      expect(updated.stock, 2);
      expect(updated.active, isFalse);
    });
  });

  group('Sale', () {
    test('totals items and detects voided sales', () {
      final sale = Sale(
        id: 's1',
        number: 'ES-1',
        items: const [
          SaleItem(
            productId: 'p1',
            name: 'Water',
            quantity: 3,
            unitPrice: 1000,
            costPrice: 600,
          ),
        ],
        subtotal: 3000,
        discount: 0,
        taxRate: 0,
        tax: 0,
        total: 3000,
        paymentMethod: 'Cash',
        grossProfit: 1200,
        createdAt: DateTime(2026, 1, 2, 10, 30),
      );

      expect(sale.itemCount, 3);
      expect(sale.isVoided, isFalse);
      expect(sale.isCompleted, isTrue);
      expect(sale.items.single.lineTotal, 3000);
      expect(sale.items.single.lineCost, 1800);

      final voided = sale.copyWith(status: 'voided');
      expect(voided.isVoided, isTrue);
      expect(voided.isCompleted, isFalse);
    });
  });

  group('Shop and currency', () {
    test('resolves currency and defaults', () {
      final shop = Shop.empty('u1');
      expect(shop.name, isEmpty);
      expect(shop.currencyCode, 'TZS');
      expect(shop.currency.symbol, 'TSh');
      expect(shop.decimals, 0);

      final updated = shop.copyWith(
        name: 'Estro Market',
        currencyCode: 'USD',
        taxRate: 18,
        setupComplete: true,
      );
      expect(updated.name, 'Estro Market');
      expect(updated.currency.symbol, r'$');
      expect(updated.taxRate, 18);
      expect(updated.setupComplete, isTrue);
    });

    test('falls back to the first supported currency', () {
      expect(CurrencyOption.byCode('NOPE').code, 'TZS');
    });
  });

  group('Customer and Expense', () {
    test('copyWith preserves accounting fields', () {
      const customer = Customer(
        id: 'c1',
        name: 'Amina',
        totalSpent: 12000,
        visits: 3,
      );
      final updated = customer.copyWith(phone: '0700');
      expect(updated.name, 'Amina');
      expect(updated.phone, '0700');
      expect(updated.totalSpent, 12000);
      expect(updated.visits, 3);
    });

    test('expense categories and copyWith', () {
      expect(Expense.categories, contains('Rent'));
      final expense = Expense(
        id: 'e1',
        title: 'Rent',
        category: 'Rent',
        amount: 150000,
        date: DateTime(2026, 1, 1),
      );
      final updated = expense.copyWith(amount: 175000);
      expect(updated.amount, 175000);
      expect(updated.title, 'Rent');
    });
  });

  group('Formatters', () {
    test('formats money with the shop symbol and decimals', () {
      expect(formatMoney(1500, symbol: 'TSh', decimals: 0), 'TSh1,500');
      expect(formatMoney(12.5, symbol: r'$'), r'$12.50');
      expect(formatMoneyCompact(1500000, symbol: 'TSh'), 'TSh1.5M');
    });

    test('builds receipt numbers and date helpers', () {
      final date = DateTime(2026, 11, 13, 9, 5);
      expect(saleNumberFor(date), startsWith('ES-261113-'));
      expect(formatDate(date), '13 Nov 2026');
      expect(startOfDay(date), DateTime(2026, 11, 13));
      expect(endOfDay(date).hour, 23);
      expect(initialsFor('Amina Hassan'), 'AH');
      expect(initialsFor('Amina'), 'A');
      expect(initialsFor(''), 'ES');
    });
  });
}
