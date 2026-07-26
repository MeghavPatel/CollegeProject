import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hp_bill/models/invoice.dart';
import 'package:hp_bill/services/database_helper.dart';
import 'package:hp_bill/services/print_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareService {
  static final ShareService instance = ShareService._init();
  ShareService._init();

  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');

  /// Saves the PDF to a secure temporary directory and triggers the OS native share sheet
  Future<void> shareInvoicePdf(Invoice invoice) async {
    try {
      final pdfBytes = await PrintService.instance.generateA4InvoicePdf(invoice);
      final tempDir = await getTemporaryDirectory();
      final fileName = 'Invoice_${invoice.invoiceNumber}.pdf';
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(pdfBytes, flush: true);

      final xFile = XFile(file.path, mimeType: 'application/pdf');
      await Share.shareXFiles(
        [xFile],
        text: 'Invoice ${invoice.invoiceNumber} from ${invoice.customerName}.',
        subject: 'Invoice ${invoice.invoiceNumber} - ${invoice.customerName}',
      );
    } catch (e) {
      // Gracefully handle error
    }
  }

  /// Generates a direct WhatsApp link with a pre-filled summary text that opens instantly
  Future<String> generateWhatsAppUrl(Invoice invoice) async {
    final cleanPhone = invoice.customerPhone.replaceAll(RegExp(r'\D'), '');
    String phoneWithCountry = cleanPhone;
    if (cleanPhone.length == 10) {
      phoneWithCountry = '91$cleanPhone';
    }

    final String textMessage = await compileBillSummaryText(invoice);
    final encodedText = Uri.encodeComponent(textMessage);
    return "https://wa.me/$phoneWithCountry?text=$encodedText";
  }

  /// Compiles a clean text bill summary — NO TAX, NO GST, NO DISCOUNT
  Future<String> compileBillSummaryText(Invoice invoice) async {
    final profile = await DatabaseHelper.instance.getStoreProfile();
    final storeName = profile['storeName'] ?? 'HP Bill';
    final dateStr = DateFormat('dd-MMM-yyyy').format(invoice.date);
    
    String itemsText = '';
    for (var i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      itemsText += "${i + 1}. ${item.name} x ${item.quantity.toStringAsFixed(0)} = ${currencyFormatter.format(item.total)}\n";
    }

    return 
        "-------------------------------\n"
        "           INVOICE             \n"
        "-------------------------------\n"
        "🏪 Store: ${storeName.toUpperCase()}\n"
        "📄 Invoice #: ${invoice.invoiceNumber}\n"
        "📅 Date: $dateStr\n"
        "👤 Customer: ${invoice.customerName}\n"
        "📱 Phone: +91 ${invoice.customerPhone}\n"
        "-------------------------------\n"
        "ITEMS:\n"
        "$itemsText"
        "-------------------------------\n"
        "💰 Total Amount: *${currencyFormatter.format(invoice.grandTotal)}*\n"
        "📝 Status: ${invoice.isPaid ? 'PAID ✅' : 'PENDING ⚠️'}\n"
        "-------------------------------\n"
        "Thank you for shopping with us! 🙏";
  }

  /// Launches the WhatsApp URL directly using the Native URL Scheme protocol (for unsaved numbers)
  Future<bool> launchWhatsAppDirect(Invoice invoice) async {
    final urlString = await generateWhatsAppUrl(invoice);
    final uri = Uri.parse(urlString);
    try {
      // Direct launch without canLaunchUrl which is flaky on modern Android 11+
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    } catch (e) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// One-click copy utility to copy the bill summary to system clipboard
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Share a backup JSON file via OS share sheet
  Future<void> shareBackupFile(String jsonContent) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'HP_Bill_Backup_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonContent, flush: true);

      final xFile = XFile(file.path, mimeType: 'application/json');
      await Share.shareXFiles(
        [xFile],
        text: 'HP Bill complete data backup',
        subject: 'HP Bill Backup - ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
      );
    } catch (e) {
      // Gracefully handle error
    }
  }
}
