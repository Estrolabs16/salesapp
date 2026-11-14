import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadProductImage({
    required String userId,
    required String productId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ref = _storage.ref('productImages/$userId/$productId.jpg');
    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType, cacheControl: 'no-cache'),
    );
    return ref.getDownloadURL();
  }

  Future<void> deleteProductImage({
    required String userId,
    required String productId,
  }) async {
    try {
      await _storage.ref('productImages/$userId/$productId.jpg').delete();
    } on FirebaseException {
      return;
    }
  }
}
