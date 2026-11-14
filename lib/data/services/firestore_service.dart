import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer.dart';
import '../models/expense.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/shop.dart';

class SaleException implements Exception {
  SaleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirestoreService {
  FirestoreService({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get shopRef =>
      _db.collection('shops').doc(uid);

  CollectionReference<Map<String, dynamic>> get productsRef =>
      shopRef.collection('products');

  CollectionReference<Map<String, dynamic>> get customersRef =>
      shopRef.collection('customers');

  CollectionReference<Map<String, dynamic>> get salesRef =>
      shopRef.collection('sales');

  CollectionReference<Map<String, dynamic>> get expensesRef =>
      shopRef.collection('expenses');

  Stream<Shop?> watchShop() {
    return shopRef.snapshots().map((doc) {
      if (!doc.exists) return null;
      return Shop.fromDoc(doc);
    });
  }

  Future<void> saveShop(Shop shop) {
    return shopRef.set(shop.toMap(), SetOptions(merge: true));
  }

  Future<void> saveDeviceMetadata({
    required String deviceId,
    required bool isGuest,
  }) {
    return shopRef.set({
      'deviceId': deviceId,
      'isGuest': isGuest,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Product>> watchProducts() {
    return productsRef.orderBy('name').snapshots().map(
      (snapshot) => snapshot.docs.map(Product.fromDoc).toList(),
    );
  }

  String newProductId() => productsRef.doc().id;

  Future<void> saveProduct(Product product) {
    return productsRef.doc(product.id).set(
      product.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> deleteProduct(String productId) {
    return productsRef.doc(productId).delete();
  }

  Future<void> adjustStock(Product product, int delta) {
    return productsRef.doc(product.id).update({
      'stock': (product.stock + delta).clamp(0, 1000000000),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Customer>> watchCustomers() {
    return customersRef.orderBy('name').snapshots().map(
      (snapshot) => snapshot.docs.map(Customer.fromDoc).toList(),
    );
  }

  String newCustomerId() => customersRef.doc().id;

  Future<void> saveCustomer(Customer customer) {
    return customersRef.doc(customer.id).set(
      customer.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> deleteCustomer(String customerId) {
    return customersRef.doc(customerId).delete();
  }

  Stream<List<Expense>> watchExpenses() {
    return expensesRef.orderBy('date', descending: true).snapshots().map(
      (snapshot) => snapshot.docs.map(Expense.fromDoc).toList(),
    );
  }

  Stream<List<Expense>> watchExpensesInRange(DateTime start, DateTime end) {
    return expensesRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Expense.fromDoc).toList());
  }

  String newExpenseId() => expensesRef.doc().id;

  Future<void> saveExpense(Expense expense) {
    return expensesRef.doc(expense.id).set(
      expense.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> deleteExpense(String expenseId) {
    return expensesRef.doc(expenseId).delete();
  }

  Stream<List<Sale>> watchSales({
    DateTime? start,
    DateTime? end,
    int limit = 200,
  }) {
    Query<Map<String, dynamic>> query = salesRef;
    if (start != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      );
    }
    if (end != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(end),
      );
    }
    query = query.orderBy('createdAt', descending: true).limit(limit);
    return query.snapshots().map(
      (snapshot) => snapshot.docs.map(Sale.fromDoc).toList(),
    );
  }

  Stream<List<Sale>> watchCustomerSales(String customerId, {int limit = 50}) {
    return salesRef
        .where('customerId', isEqualTo: customerId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final sales = snapshot.docs.map(Sale.fromDoc).toList();
          sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return sales;
        });
  }

  Future<Sale> createSale(Sale sale) async {
    final saleRef = salesRef.doc();
    final savedSale = sale.copyWith(id: saleRef.id);

    await _db.runTransaction((transaction) async {
      for (final item in sale.items) {
        final productRef = productsRef.doc(item.productId);
        final snapshot = await transaction.get(productRef);
        if (!snapshot.exists) {
          throw SaleException('${item.name} is no longer available.');
        }
        final available =
            ((snapshot.data()?['stock'] as num?) ?? 0).toInt();
        if (available < item.quantity) {
          throw SaleException(
            'Not enough stock for ${item.name}. Only $available left.',
          );
        }
        transaction.update(productRef, {
          'stock': available - item.quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (sale.customerId.isNotEmpty) {
        final customerRef = customersRef.doc(sale.customerId);
        final customerSnapshot = await transaction.get(customerRef);
        if (customerSnapshot.exists) {
          final data = customerSnapshot.data()!;
          transaction.update(customerRef, {
            'totalSpent':
                (((data['totalSpent'] as num?)?.toDouble()) ?? 0) + sale.total,
            'visits': (((data['visits'] as num?)?.toInt()) ?? 0) + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      transaction.set(saleRef, savedSale.toMap());
    });

    return savedSale;
  }

  Future<void> voidSale(Sale sale) async {
    if (sale.isVoided) return;
    final saleRef = salesRef.doc(sale.id);

    await _db.runTransaction((transaction) async {
      final saleSnapshot = await transaction.get(saleRef);
      if (!saleSnapshot.exists) {
        throw SaleException('This sale no longer exists.');
      }
      final data = saleSnapshot.data()!;
      if (data['status'] == 'voided') return;

      final rawItems = data['items'];
      final items = rawItems is List
          ? rawItems.whereType<Map<String, dynamic>>().map(SaleItem.fromMap)
          : <SaleItem>[];
      for (final item in items) {
        final productRef = productsRef.doc(item.productId);
        final productSnapshot = await transaction.get(productRef);
        if (productSnapshot.exists) {
          final current =
              ((productSnapshot.data()?['stock'] as num?) ?? 0).toInt();
          transaction.update(productRef, {
            'stock': current + item.quantity,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      final customerId = (data['customerId'] as String?) ?? '';
      if (customerId.isNotEmpty) {
        final customerRef = customersRef.doc(customerId);
        final customerSnapshot = await transaction.get(customerRef);
        if (customerSnapshot.exists) {
          final customerData = customerSnapshot.data()!;
          final totalSpent =
              ((customerData['totalSpent'] as num?)?.toDouble()) ?? 0;
          final visits = ((customerData['visits'] as num?)?.toInt()) ?? 0;
          final saleTotal = ((data['total'] as num?)?.toDouble()) ?? 0;
          transaction.update(customerRef, {
            'totalSpent': (totalSpent - saleTotal).clamp(0, double.infinity),
            'visits': (visits - 1).clamp(0, 1000000000),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      transaction.update(saleRef, {
        'status': 'voided',
        'voidedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
