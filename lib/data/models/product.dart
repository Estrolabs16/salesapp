import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_helpers.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    this.sku = '',
    this.category = '',
    this.costPrice = 0,
    this.sellingPrice = 0,
    this.stock = 0,
    this.lowStockThreshold = 5,
    this.imageUrl = '',
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String sku;
  final String category;
  final double costPrice;
  final double sellingPrice;
  final int stock;
  final int lowStockThreshold;
  final String imageUrl;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLowStock => stock <= lowStockThreshold;

  bool get isOutOfStock => stock <= 0;

  bool get hasImage => imageUrl.isNotEmpty;

  double get stockValue => costPrice * stock;

  double get marginPercent {
    if (sellingPrice <= 0) return 0;
    return ((sellingPrice - costPrice) / sellingPrice) * 100;
  }

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Product(
      id: doc.id,
      name: stringFromValue(data['name']),
      sku: stringFromValue(data['sku']),
      category: stringFromValue(data['category']),
      costPrice: doubleFromValue(data['costPrice']),
      sellingPrice: doubleFromValue(data['sellingPrice']),
      stock: intFromValue(data['stock']),
      lowStockThreshold: intFromValue(data['lowStockThreshold']),
      imageUrl: stringFromValue(data['imageUrl']),
      active: data['active'] != false,
      createdAt: dateFromValue(data['createdAt']),
      updatedAt: dateFromValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'sku': sku.trim(),
      'category': category.trim(),
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'stock': stock,
      'lowStockThreshold': lowStockThreshold,
      'imageUrl': imageUrl,
      'active': active,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? category,
    double? costPrice,
    double? sellingPrice,
    int? stock,
    int? lowStockThreshold,
    String? imageUrl,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stock: stock ?? this.stock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      imageUrl: imageUrl ?? this.imageUrl,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
