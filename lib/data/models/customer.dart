import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_helpers.dart';

class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.notes = '',
    this.totalSpent = 0,
    this.visits = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String notes;
  final double totalSpent;
  final int visits;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Customer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Customer(
      id: doc.id,
      name: stringFromValue(data['name']),
      phone: stringFromValue(data['phone']),
      email: stringFromValue(data['email']),
      notes: stringFromValue(data['notes']),
      totalSpent: doubleFromValue(data['totalSpent']),
      visits: intFromValue(data['visits']),
      createdAt: dateFromValue(data['createdAt']),
      updatedAt: dateFromValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'notes': notes.trim(),
      'totalSpent': totalSpent,
      'visits': visits,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? notes,
    double? totalSpent,
    int? visits,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      totalSpent: totalSpent ?? this.totalSpent,
      visits: visits ?? this.visits,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
