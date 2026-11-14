import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/error_messages.dart';
import '../data/models/shop.dart';
import '../data/services/firestore_service.dart';

class ShopController extends ChangeNotifier {
  ShopController(this._db) {
    _listen();
  }

  final FirestoreService _db;
  StreamSubscription<Shop?>? _subscription;

  Shop? _shop;
  bool _loading = true;
  String? _error;

  Shop? get shop => _shop;

  bool get loading => _loading;

  String? get error => _error;

  void _listen() {
    _subscription?.cancel();
    _loading = true;
    _error = null;
    _subscription = _db.watchShop().listen(
      (shop) {
        _shop = shop;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object error) {
        _error = friendlyError(error);
        _loading = false;
        notifyListeners();
      },
    );
  }

  void retry() => _listen();

  Future<void> save(Shop shop) async {
    final completeShop = shop.copyWith(setupComplete: true);
    await _db.saveShop(completeShop);
    _shop = completeShop;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
