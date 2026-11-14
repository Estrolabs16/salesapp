import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_helpers.dart';

class Expense {
  const Expense({
    required this.id,
    required this.title,
    this.category = 'Other',
    this.amount = 0,
    this.note = '',
    required this.date,
    this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final String note;
  final DateTime date;
  final DateTime? createdAt;

  static const categories = [
    'Rent',
    'Utilities',
    'Salaries',
    'Transport',
    'Supplies',
    'Marketing',
    'Other',
  ];

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Expense(
      id: doc.id,
      title: stringFromValue(data['title']),
      category: stringFromValue(data['category']).isEmpty
          ? 'Other'
          : stringFromValue(data['category']),
      amount: doubleFromValue(data['amount']),
      note: stringFromValue(data['note']),
      date: dateOrNow(data['date']),
      createdAt: dateFromValue(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title.trim(),
      'category': category,
      'amount': amount,
      'note': note.trim(),
      'date': Timestamp.fromDate(date),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  Expense copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    String? note,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
