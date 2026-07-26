import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RC4 Stream Cipher for End-to-End Encryption
class Rc4Cipher {
  static String encrypt(String text, String key) {
    if (text.isEmpty || key.isEmpty) return text;
    final keyBytes = utf8.encode(key);
    final textBytes = utf8.encode(text);
    final encryptedBytes = _crypt(textBytes, keyBytes);
    return base64.encode(encryptedBytes);
  }

  static String decrypt(String base64Text, String key) {
    if (base64Text.isEmpty || key.isEmpty) return base64Text;
    try {
      final keyBytes = utf8.encode(key);
      final encryptedBytes = base64.decode(base64Text);
      final decryptedBytes = _crypt(encryptedBytes, keyBytes);
      return utf8.decode(decryptedBytes);
    } catch (_) {
      return "[Decryption Error: Mismatched Passphrase]";
    }
  }

  static List<int> _crypt(List<int> data, List<int> key) {
    final s = List<int>.generate(256, (i) => i);
    int j = 0;
    for (int i = 0; i < 256; i++) {
      j = (j + s[i] + key[i % key.length]) % 256;
      final temp = s[i];
      s[i] = s[j];
      s[j] = temp;
    }

    int x = 0;
    int y = 0;
    final result = List<int>.filled(data.length, 0);
    for (int i = 0; i < data.length; i++) {
      x = (x + 1) % 256;
      y = (y + s[x]) % 256;
      final temp = s[x];
      s[x] = s[y];
      s[y] = temp;
      final k = s[(s[x] + s[y]) % 256];
      result[i] = data[i] ^ k;
    }
    return result;
  }
}

// Data Model for Encrypted Message
class ChatMessage {
  final String id;
  final String senderId;
  final String senderEmail;
  final String encryptedText;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderEmail,
    required this.encryptedText,
    required this.timestamp,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderEmail: data['senderEmail'] ?? '',
      encryptedText: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// Passphrase state notifier
class ChatPassphraseNotifier extends Notifier<String?> {
  static const _prefKey = 'chat_e2ee_passphrase';

  @override
  String? build() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _loadPassphrase(uid);
    }
    return null;
  }

  Future<void> _loadPassphrase(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('${_prefKey}_$uid');
  }

  Future<void> setPassphrase(String passphrase) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_prefKey}_$uid', passphrase);
    state = passphrase;
  }

  Future<void> clearPassphrase() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_prefKey}_$uid');
    state = null;
  }
}

final chatPassphraseProvider = NotifierProvider<ChatPassphraseNotifier, String?>(ChatPassphraseNotifier.new);

// Stream of encrypted messages
final encryptedMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  return FirebaseFirestore.instance
      .collection('chats')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
});

// Chat action provider
final chatControllerProvider = Provider((ref) {
  return ChatController(ref);
});

class ChatController {
  final Ref _ref;
  ChatController(this._ref);

  Future<void> sendMessage(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final passphrase = _ref.read(chatPassphraseProvider);
    if (passphrase == null || passphrase.isEmpty) return;

    final plaintext = "HPCHAT:$text";
    final encryptedText = Rc4Cipher.encrypt(plaintext, passphrase);

    await FirebaseFirestore.instance.collection('chats').add({
      'senderId': user.uid,
      'senderEmail': user.email ?? 'Unknown',
      'text': encryptedText,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance.collection('chats').doc(messageId).delete();
    } catch (e) {
      // Fail silently or handle
    }
  }
}
