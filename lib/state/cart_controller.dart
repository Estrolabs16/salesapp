import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/models/customer.dart';
import '../data/models/product.dart';
import '../data/models/sale.dart';

class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get lineTotal => product.sellingPrice * quantity;

  double get lineCost => product.costPrice * quantity;

  CartLine copyWith({int? quantity}) {
    return CartLine(product: product, quantity: quantity ?? this.quantity);
  }
}

class CartController extends ChangeNotifier {
  CartController({double taxRate = 0}) {
    _taxRate = taxRate;
  }

  final List<CartLine> _lines = [];
  double _taxRate = 0;
  double _discount = 0;
  String _paymentMethod = Sale.paymentMethods.first;
  Customer? _customer;
  double _cashReceived = 0;
  String _note = '';

  List<CartLine> get lines => List.unmodifiable(_lines);

  double get taxRate => _taxRate;

  double get discount => _discount;

  String get paymentMethod => _paymentMethod;

  Customer? get customer => _customer;

  double get cashReceived => _cashReceived;

  String get note => _note;

  bool get isEmpty => _lines.isEmpty;

  int get itemCount => _lines.fold(0, (sum, line) => sum + line.quantity);

  double get subtotal =>
      _lines.fold(0, (sum, line) => sum + line.lineTotal);

  double get totalCost => _lines.fold(0, (sum, line) => sum + line.lineCost);

  double get effectiveDiscount => _discount.clamp(0, subtotal);

  double get taxable => math.max(0, subtotal - effectiveDiscount);

  double get tax => taxable * (_taxRate / 100);

  double get total => taxable + tax;

  double get grossProfit => taxable - totalCost;

  double get changeDue => math.max(0, _cashReceived - total);

  bool get requiresCash => _paymentMethod == Sale.paymentMethods.first;

  bool get hasEnoughCash => !requiresCash || _cashReceived >= total;

  bool add(Product product) {
    if (product.stock <= 0 || !product.active) return false;
    final index = _lines.indexWhere((line) => line.product.id == product.id);
    if (index == -1) {
      _lines.add(CartLine(product: product, quantity: 1));
      notifyListeners();
      return true;
    }
    final line = _lines[index];
    if (line.quantity >= product.stock) return false;
    _lines[index] = line.copyWith(quantity: line.quantity + 1);
    notifyListeners();
    return true;
  }

  void increment(String productId) {
    final index = _lines.indexWhere((line) => line.product.id == productId);
    if (index == -1) return;
    final line = _lines[index];
    if (line.quantity >= line.product.stock) return;
    _lines[index] = line.copyWith(quantity: line.quantity + 1);
    notifyListeners();
  }

  void decrement(String productId) {
    final index = _lines.indexWhere((line) => line.product.id == productId);
    if (index == -1) return;
    final line = _lines[index];
    if (line.quantity <= 1) {
      _lines.removeAt(index);
    } else {
      _lines[index] = line.copyWith(quantity: line.quantity - 1);
    }
    notifyListeners();
  }

  void setQuantity(String productId, int quantity) {
    final index = _lines.indexWhere((line) => line.product.id == productId);
    if (index == -1) return;
    if (quantity <= 0) {
      _lines.removeAt(index);
      notifyListeners();
      return;
    }
    final line = _lines[index];
    _lines[index] = line.copyWith(
      quantity: quantity.clamp(0, line.product.stock),
    );
    notifyListeners();
  }

  void remove(String productId) {
    _lines.removeWhere((line) => line.product.id == productId);
    notifyListeners();
  }

  void setTaxRate(double value) {
    if (_taxRate == value) return;
    _taxRate = value;
    notifyListeners();
  }

  void setDiscount(double value) {
    final next = value.isFinite ? math.max(0.0, value) : 0.0;
    if (_discount == next) return;
    _discount = next;
    notifyListeners();
  }

  void setPaymentMethod(String value) {
    if (_paymentMethod == value) return;
    _paymentMethod = value;
    notifyListeners();
  }

  void setCustomer(Customer? value) {
    _customer = value;
    notifyListeners();
  }

  void setCashReceived(double value) {
    final next = value.isFinite ? math.max(0.0, value) : 0.0;
    if (_cashReceived == next) return;
    _cashReceived = next;
    notifyListeners();
  }

  void setNote(String value) {
    _note = value;
    notifyListeners();
  }

  List<SaleItem> toSaleItems() {
    return _lines
        .map(
          (line) => SaleItem(
            productId: line.product.id,
            name: line.product.name,
            quantity: line.quantity,
            unitPrice: line.product.sellingPrice,
            costPrice: line.product.costPrice,
          ),
        )
        .toList();
  }

  void clear() {
    _lines.clear();
    _discount = 0;
    _customer = null;
    _cashReceived = 0;
    _paymentMethod = Sale.paymentMethods.first;
    _note = '';
    notifyListeners();
  }
}
