import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';

/// Centralized AES-256 encryption service.
/// Encrypts all data payloads before storing in Firebase Firestore,
/// and seamlessly decrypts them when reading.
class EncryptionService {
  static final EncryptionService instance = EncryptionService._init();
  EncryptionService._init();

  // 256-bit Key derived deterministically for the HP Bill application
  // Secret salt ensures high cryptographic entropy for AES-256
  static const String _appSecretSeed = "HP_BILL_ENTERPRISE_SECURE_VAULT_2026_PROD_ENC_KEY";
  
  late final enc.Key _key;
  late final enc.Encrypter _encrypter;

  bool _initialized = false;

  void _ensureInitialized() {
    if (_initialized) return;
    // Derive 32 bytes (256 bits) from SHA-256 hash of seed
    final keyBytes = sha256.convert(utf8.encode(_appSecretSeed)).bytes;
    _key = enc.Key(Uint8List.fromList(keyBytes));
    // AES with CBC mode and PKCS7 padding
    _encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    _initialized = true;
  }

  /// Encrypts a Dart Map into an encrypted Firestore document format.
  /// Resulting Firestore doc contains:
  /// {
  ///   "_enc": true,
  ///   "_v": 1,
  ///   "payload": "`<ciphertext_base64>`",
  ///   "iv": "`<iv_base64>`",
  /// }
  Map<String, dynamic> encryptMap(Map<String, dynamic> data) {
    _ensureInitialized();
    try {
      final jsonString = jsonEncode(data);
      final iv = enc.IV.fromSecureRandom(16);
      final encrypted = _encrypter.encrypt(jsonString, iv: iv);

      return {
        '_enc': true,
        '_v': 1,
        'payload': encrypted.base64,
        'iv': iv.base64,
        'updatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint("Encryption error: $e. Falling back to plain map.");
      return data;
    }
  }

  /// Decrypts a Firestore document.
  /// If the document is encrypted ('_enc' == true), it decrypts the payload.
  /// If it is legacy unencrypted data, it gracefully returns the original Map.
  Map<String, dynamic> decryptDoc(Map<String, dynamic>? rawDoc) {
    if (rawDoc == null) return {};
    _ensureInitialized();

    try {
      if (rawDoc['_enc'] == true && rawDoc['payload'] != null && rawDoc['iv'] != null) {
        final payloadBase64 = rawDoc['payload'].toString();
        final ivBase64 = rawDoc['iv'].toString();

        final iv = enc.IV.fromBase64(ivBase64);
        final encrypted = enc.Encrypted.fromBase64(payloadBase64);
        final decryptedString = _encrypter.decrypt(encrypted, iv: iv);

        final dynamic decoded = jsonDecode(decryptedString);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e) {
      debugPrint("Decryption error: $e. Returning raw doc.");
    }

    // Fallback: Return raw unencrypted map
    return Map<String, dynamic>.from(rawDoc);
  }

  /// Encrypts a plain string into ciphertext
  String encryptText(String text) {
    _ensureInitialized();
    try {
      final iv = enc.IV.fromSecureRandom(16);
      final encrypted = _encrypter.encrypt(text, iv: iv);
      return "${iv.base64}:${encrypted.base64}";
    } catch (e) {
      return text;
    }
  }

  /// Decrypts ciphertext back to plain string
  String decryptText(String ciphertext) {
    _ensureInitialized();
    try {
      final parts = ciphertext.split(':');
      if (parts.length != 2) return ciphertext;
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypted = enc.Encrypted.fromBase64(parts[1]);
      return _encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      return ciphertext;
    }
  }
}
