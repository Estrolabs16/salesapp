import 'package:cloud_firestore/cloud_firestore.dart';

import 'currency.dart';
import 'model_helpers.dart';

class Shop {
  const Shop({
    required this.id,
    required this.name,
    this.ownerName = '',
    this.phone = '',
    this.address = '',
    this.currencyCode = 'TZS',
    this.taxRate = 0,
    this.lowStockThreshold = 5,
    this.setupComplete = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String ownerName;
  final String phone;
  final String address;
  final String currencyCode;
  final double taxRate;
  final int lowStockThreshold;
  final bool setupComplete;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CurrencyOption get currency => CurrencyOption.byCode(currencyCode);

  String get symbol => currency.symbol;

  int get decimals => currency.decimals;

  factory Shop.empty(String id) => Shop(id: id, name: '');

  factory Shop.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Shop(
      id: doc.id,
      name: stringFromValue(data['name']),
      ownerName: stringFromValue(data['ownerName']),
      phone: stringFromValue(data['phone']),
      address: stringFromValue(data['address']),
      currencyCode: stringFromValue(data['currencyCode']).isEmpty
          ? 'TZS'
          : stringFromValue(data['currencyCode']),
      taxRate: doubleFromValue(data['taxRate']),
      lowStockThreshold: intFromValue(data['lowStockThreshold']) == 0
          ? 5
          : intFromValue(data['lowStockThreshold']),
      setupComplete: data['setupComplete'] == true,
      createdAt: dateFromValue(data['createdAt']),
      updatedAt: dateFromValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'ownerName': ownerName.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'currencyCode': currencyCode,
      'taxRate': taxRate,
      'lowStockThreshold': lowStockThreshold,
      'setupComplete': setupComplete,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Shop copyWith({
    String? name,
    String? ownerName,
    String? phone,
    String? address,
    String? currencyCode,
    double? taxRate,
    int? lowStockThreshold,
    bool? setupComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Shop(
      id: id,
      name: name ?? this.name,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      currencyCode: currencyCode ?? this.currencyCode,
      taxRate: taxRate ?? this.taxRate,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      setupComplete: setupComplete ?? this.setupComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
