import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

abstract final class AppAnalytics {
  static Future<void> _log(Future<void> Function(FirebaseAnalytics analytics) action) async {
    if (kIsWeb) return;
    try {
      await action(FirebaseAnalytics.instance);
    } catch (_) {
      return;
    }
  }

  static Future<void> logLogin() => _log(
    (analytics) => analytics.logLogin(loginMethod: 'password'),
  );

  static Future<void> logSignUp() => _log(
    (analytics) => analytics.logSignUp(signUpMethod: 'password'),
  );

  static Future<void> logSale({
    required double value,
    required String currency,
    required int itemCount,
    required String paymentMethod,
  }) {
    return _log(
      (analytics) => analytics.logPurchase(
        value: value,
        currency: currency,
        transactionId: DateTime.now().microsecondsSinceEpoch.toString(),
        items: [
          AnalyticsEventItem(
            itemId: 'sale',
            itemName: 'EstroShop sale',
            quantity: itemCount,
          ),
        ],
        parameters: {'payment_method': paymentMethod},
      ),
    );
  }

  static Future<void> logProductCreated({required String category}) => _log(
    (analytics) => analytics.logEvent(
      name: 'product_created',
      parameters: {'category': category},
    ),
  );

  static Future<void> logExpenseCreated({required String category, required double value}) {
    return _log(
      (analytics) => analytics.logEvent(
        name: 'expense_created',
        parameters: {'category': category, 'value': value},
      ),
    );
  }

  static Future<void> logExport({required String type}) => _log(
    (analytics) => analytics.logEvent(
      name: 'data_exported',
      parameters: {'type': type},
    ),
  );
}
