import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_helpers.dart';

class SaleItem {
  const SaleItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
  });

  final String productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double costPrice;

  double get lineTotal => unitPrice * quantity;

  double get lineCost => costPrice * quantity;

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: stringFromValue(map['productId']),
      name: stringFromValue(map['name']),
      quantity: intFromValue(map['quantity']),
      unitPrice: doubleFromValue(map['unitPrice']),
      costPrice: doubleFromValue(map['costPrice']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'costPrice': costPrice,
    };
  }
}

class Sale {
  const Sale({
    required this.id,
    required this.number,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.taxRate,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.grossProfit,
    required this.createdAt,
    this.customerId = '',
    this.customerName = '',
    this.note = '',
    this.status = 'completed',
    this.voidedAt,
  });

  final String id;
  final String number;
  final List<SaleItem> items;
  final double subtotal;
  final double discount;
  final double taxRate;
  final double tax;
  final double total;
  final String paymentMethod;
  final double grossProfit;
  final DateTime createdAt;
  final String customerId;
  final String customerName;
  final String note;
  final String status;
  final DateTime? voidedAt;

  static const paymentMethods = [
    'Cash',
    'Mobile Money',
    'Card',
    'Bank Transfer',
    'Other',
  ];

  bool get isVoided => status == 'voided';

  bool get isCompleted => status == 'completed';

  int get itemCount => items.fold(0, (acc, item) => acc + item.quantity);

  factory Sale.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawItems = data['items'];
    return Sale(
      id: doc.id,
      number: stringFromValue(data['number']),
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(SaleItem.fromMap)
                .toList()
          : const [],
      subtotal: doubleFromValue(data['subtotal']),
      discount: doubleFromValue(data['discount']),
      taxRate: doubleFromValue(data['taxRate']),
      tax: doubleFromValue(data['tax']),
      total: doubleFromValue(data['total']),
      paymentMethod: stringFromValue(data['paymentMethod']).isEmpty
          ? 'Cash'
          : stringFromValue(data['paymentMethod']),
      customerId: stringFromValue(data['customerId']),
      customerName: stringFromValue(data['customerName']),
      note: stringFromValue(data['note']),
      grossProfit: doubleFromValue(data['grossProfit']),
      status: stringFromValue(data['status']).isEmpty
          ? 'completed'
          : stringFromValue(data['status']),
      createdAt: dateOrNow(data['createdAt']),
      voidedAt: dateFromValue(data['voidedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'taxRate': taxRate,
      'tax': tax,
      'total': total,
      'paymentMethod': paymentMethod,
      'customerId': customerId,
      'customerName': customerName,
      'note': note.trim(),
      'grossProfit': grossProfit,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'voidedAt': voidedAt == null ? null : Timestamp.fromDate(voidedAt!),
    };
  }

  Sale copyWith({
    String? id,
    String? number,
    List<SaleItem>? items,
    double? subtotal,
    double? discount,
    double? taxRate,
    double? tax,
    double? total,
    String? paymentMethod,
    String? customerId,
    String? customerName,
    String? note,
    double? grossProfit,
    String? status,
    DateTime? createdAt,
    DateTime? voidedAt,
  }) {
    return Sale(
      id: id ?? this.id,
      number: number ?? this.number,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      taxRate: taxRate ?? this.taxRate,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      note: note ?? this.note,
      grossProfit: grossProfit ?? this.grossProfit,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      voidedAt: voidedAt ?? this.voidedAt,
    );
  }
}
