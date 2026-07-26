import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'data/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const Color brandGreen = Color(0xFF1B5E20);
  final _messageController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _messageController.dispose();
    _passphraseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    ref.read(chatControllerProvider).sendMessage(text);
    _messageController.clear();
    
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showChangePassphraseDialog() {
    _passphraseController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Chat Password', style: TextStyle(color: brandGreen, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a new security password. All future messages will be encrypted with this password.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passphraseController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.lock, color: brandGreen),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: brandGreen),
            onPressed: () {
              final newPass = _passphraseController.text.trim();
              if (newPass.isNotEmpty) {
                ref.read(chatPassphraseProvider.notifier).setPassphrase(newPass);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat password updated successfully!'), backgroundColor: brandGreen),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Message?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              ref.read(chatControllerProvider).deleteMessage(messageId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message deleted'), backgroundColor: Colors.red),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passphrase = ref.watch(chatPassphraseProvider);
    final messagesAsync = ref.watch(encryptedMessagesProvider);
    final currentUser = FirebaseAuth.instance.currentUser;

    // Filter messages and check group size if loaded
    final decryptedMessages = <MapEntry<ChatMessage, String>>[];
    bool isGroupFull = false;
    int participantCount = 0;

    if (passphrase != null) {
      messagesAsync.whenData((messages) {
        for (final msg in messages) {
          final decrypted = Rc4Cipher.decrypt(msg.encryptedText, passphrase);
          if (decrypted.startsWith("HPCHAT:")) {
            final cleanText = decrypted.substring("HPCHAT:".length);
            decryptedMessages.add(MapEntry(msg, cleanText));
          }
        }
        final uniqueSenders = decryptedMessages.map((e) => e.key.senderId).toSet();
        participantCount = uniqueSenders.length;
        isGroupFull = participantCount >= 10 && !uniqueSenders.contains(currentUser?.uid);
      });
    }

    if (passphrase == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Secure Chat'),
          foregroundColor: brandGreen,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: brandGreen.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.security, size: 80, color: brandGreen),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'End-to-End Encrypted Chat',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: brandGreen),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'To start communicating securely, set a Chat Password. All messages will be encrypted locally on your phone. Make sure your partner uses the exact same password to read your messages.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _passphraseController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Enter Chat Password',
                      hintText: 'e.g. secret123',
                      prefixIcon: const Icon(Icons.lock, color: brandGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: brandGreen, width: 2),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter password' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        ref.read(chatPassphraseProvider.notifier).setPassphrase(_passphraseController.text.trim());
                      },
                      child: const Text('UNLOCK CHAT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Secure Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Row(
              children: [
                Icon(Icons.lock, size: 12, color: brandGreen),
                SizedBox(width: 4),
                Text('E2EE Active', style: TextStyle(fontSize: 11, color: brandGreen, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: 'Change Password',
            onPressed: _showChangePassphraseDialog,
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline_rounded),
            tooltip: 'Lock Chat',
            onPressed: () {
              ref.read(chatPassphraseProvider.notifier).clearPassphrase();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: brandGreen.withValues(alpha: 0.08),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.enhanced_encryption, size: 14, color: brandGreen),
                SizedBox(width: 8),
                Text(
                  'Messages are encrypted with your security password.',
                  style: TextStyle(fontSize: 11, color: brandGreen, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Expanded(
            child: messagesAsync.when(
              data: (_) {
                if (decryptedMessages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hello!', style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: decryptedMessages.length,
                  itemBuilder: (context, index) {
                    final entry = decryptedMessages[index];
                    final msg = entry.key;
                    final decryptedText = entry.value;
                    final isMe = msg.senderId == currentUser?.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () => _showDeleteConfirmationDialog(context, msg.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isMe ? brandGreen : Colors.grey.shade200,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isMe) ...[
                                Text(
                                  msg.senderEmail,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Text(
                                decryptedText,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  DateFormat('hh:mm a').format(msg.timestamp),
                                  style: TextStyle(
                                    color: isMe ? Colors.white60 : Colors.black38,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: brandGreen)),
              error: (e, _) => Center(child: Text('Error loading messages: $e')),
            ),
          ),
          if (isGroupFull)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.red.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Group is full ($participantCount/10). You cannot send messages.',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !isGroupFull,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: isGroupFull ? 'Group limit of 10 reached' : 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isGroupFull ? Colors.grey.shade200 : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: isGroupFull ? null : _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isGroupFull ? Colors.grey : brandGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
