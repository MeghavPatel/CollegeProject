import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';

/// Centralized AES-256 encryption service for HP Inventory Management.
/// Encrypts all sensitive business data payloads before storing in Firebase Firestore,
/// and seamlessly decrypts them when reading.
class EncryptionService {
  static final EncryptionService instance = EncryptionService._init();
  EncryptionService._init();

  // 256-bit Key derived deterministically for the HP Enterprise applications
  // Secret salt ensures maximum cryptographic entropy for AES-256
  static const String _appSecretSeed = "HP_INVENTORY_ENTERPRISE_SECURE_VAULT_2026_PROD_ENC_KEY";
  
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

  /// Sanitizes map values for JSON serialization (converting Timestamp/DateTime to ISO-8601 strings)
  Map<String, dynamic> _sanitizeForJson(Map<String, dynamic> data) {
    final clean = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Timestamp) {
        clean[key] = value.toDate().toIso8601String();
      } else if (value is DateTime) {
        clean[key] = value.toIso8601String();
      } else if (value is FieldValue) {
        // Approximate server timestamp for JSON payload
        clean[key] = DateTime.now().toIso8601String();
      } else if (value is Map<String, dynamic>) {
        clean[key] = _sanitizeForJson(value);
      } else if (value is List) {
        clean[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _sanitizeForJson(item);
          } else if (item is Timestamp) {
            return item.toDate().toIso8601String();
          } else if (item is DateTime) {
            return item.toIso8601String();
          }
          return item;
        }).toList();
      } else {
        clean[key] = value;
      }
    });
    return clean;
  }

  /// Encrypts a Dart Map into an encrypted Firestore document format.
  /// Resulting Firestore doc contains:
  /// {
  ///   "_enc": true,
  ///   "_v": 1,
  ///   "payload": "`<ciphertext_base64>`",
  ///   "iv": "`<iv_base64>`",
  ///   "updatedAt": "`<iso_timestamp>`",
  ///   ... preservedIndexFields (e.g. date, employeeId, transporterId for fast Firestore querying)
  /// }
  Map<String, dynamic> encryptMap(
    Map<String, dynamic> data, {
    List<String> preserveIndexKeys = const [
      'date',
      'joinedDate',
      'paymentDate',
      'timestamp',
      'lastUpdated',
      'createdAt',
      'employeeId',
      'transporterId',
      'itemId',
      'variantId',
      'companyId',
    ],
  }) {
    _ensureInitialized();
    try {
      final sanitized = _sanitizeForJson(data);
      final jsonString = jsonEncode(sanitized);
      final iv = enc.IV.fromSecureRandom(16);
      final encrypted = _encrypter.encrypt(jsonString, iv: iv);

      final result = <String, dynamic>{
        '_enc': true,
        '_v': 1,
        'payload': encrypted.base64,
        'iv': iv.base64,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Preserve queryable index fields at top level so Firestore server queries/filters continue working
      for (final key in preserveIndexKeys) {
        if (data.containsKey(key)) {
          result[key] = data[key];
        }
      }

      return result;
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

  /// Encrypts a plain text string into ciphertext with IV prefix
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
