import 'package:flutter/material.dart';
import 'package:hp_bill/theme/app_theme.dart';

class MasterPasswordService {
  static const String primaryMasterPassword = '0394';

  /// Verifies if input matches master password
  static bool verifyPassword(String input) {
    final clean = input.trim();
    return clean == primaryMasterPassword;
  }

  /// Prompts the user to enter the master password before allowing any edit/delete action.
  /// Returns `true` if password is valid, `false` otherwise.
  static Future<bool> confirmMasterPassword(
    BuildContext context, {
    String title = "Master Password Required",
    String message = "Enter master password to proceed.",
  }) async {
    final controller = TextEditingController();
    bool obscure = true;
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded, color: AppTheme.primaryPurple, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Enter master password",
                      prefixIcon: const Icon(Icons.key_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                      errorText: errorText,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (val) {
                      if (verifyPassword(val)) {
                        Navigator.of(dialogCtx).pop(true);
                      } else {
                        setState(() => errorText = "Incorrect password! Access denied.");
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (verifyPassword(controller.text)) {
                      Navigator.of(dialogCtx).pop(true);
                    } else {
                      setState(() => errorText = "Incorrect password! Access denied.");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Confirm", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? false;
  }
}
