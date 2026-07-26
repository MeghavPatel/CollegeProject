import 'dart:typed_data';
import 'package:hp_bill/models/invoice.dart';
import 'package:hp_bill/models/ledger_entry.dart';
import 'package:hp_bill/providers/transaction_provider.dart';
import 'package:hp_bill/services/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrintService {
  static final PrintService instance = PrintService._init();
  PrintService._init();

  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
  final dateFormatter = DateFormat('dd-MMM-yyyy');

  // ═══════════════════════════════════════════════════════════════
  //  A4 INVOICE PDF — NO TAX, NO DISCOUNT, NO GSTIN
  // ═══════════════════════════════════════════════════════════════

  Future<Uint8List> generateA4InvoicePdf(Invoice invoice) async {
    final pdf = pw.Document();

    final profile = await DatabaseHelper.instance.getStoreProfile();
    final storeName = profile['storeName'] ?? 'HP Bill';

    final ledgerEntries = await DatabaseHelper.instance.getLedger(invoice.customerName);
    double previousDue = 0.0;
    double totalDue = invoice.grandTotal;

    ledgerEntries.sort((a, b) => a.date.compareTo(b.date));

    final currentIndex = ledgerEntries.indexWhere((e) => e.invoiceId == invoice.id);
    if (currentIndex != -1) {
      if (currentIndex > 0) {
        previousDue = ledgerEntries[currentIndex - 1].runningBalance;
      } else {
        previousDue = 0.0;
      }
      totalDue = ledgerEntries[currentIndex].runningBalance;
    } else {
      if (ledgerEntries.isNotEmpty) {
        previousDue = ledgerEntries.last.runningBalance;
      } else {
        previousDue = 0.0;
      }
      totalDue = previousDue + invoice.grandTotal;
    }

    String formatDue(double amt) {
      final formattedVal = amt.abs().toStringAsFixed(2);
      return "$formattedVal ${amt >= 0 ? 'DB' : 'CR'}";
    }

    final int minRows = 10;
    final List<InvoiceItem?> paddedItems = List<InvoiceItem?>.from(invoice.items);
    while (paddedItems.length < minRows) {
      paddedItems.add(null);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                // --- COMPANY HEADER ROW ---
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
                    ),
                  ),
                  child: pw.Text(
                    storeName.toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                // --- CUSTOMER & METADATA SECTION ---
                pw.Container(
                  height: 55,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Left column: Customer Details
                      pw.Expanded(
                        flex: 5,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text(
                                "M/s. : ${invoice.customerName.toUpperCase()}",
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                              ),
                              if (invoice.customerPhone.isNotEmpty) pw.SizedBox(height: 4),
                              if (invoice.customerPhone.isNotEmpty)
                                pw.Text(
                                  "Mob: ${invoice.customerPhone}",
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Divider line
                      pw.Container(width: 1.5, color: PdfColors.black),
                      // Right column: Invoice Metadata
                      pw.Expanded(
                        flex: 4,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Container(width: 60, child: pw.Text("No.", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                                  pw.Text(": ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                                  pw.Text(invoice.invoiceNumber, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                                ],
                              ),
                              pw.SizedBox(height: 4),
                              pw.Row(
                                children: [
                                  pw.Container(width: 60, child: pw.Text("Date", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                                  pw.Text(": ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                                  pw.Text(dateFormatter.format(invoice.date), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Table separator
                pw.Container(height: 1.5, color: PdfColors.black),

                // --- ITEMS TABLE ---
                pw.Table(
                  border: const pw.TableBorder(
                    verticalInside: pw.BorderSide(color: PdfColors.black, width: 1.0),
                    horizontalInside: pw.BorderSide(color: PdfColors.black, width: 0.0),
                    bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(0.8),  // SrNo
                    1: pw.FlexColumnWidth(4.5),  // Product Name
                    2: pw.FlexColumnWidth(1.0),  // Qty
                    3: pw.FlexColumnWidth(1.2),  // Rate
                    4: pw.FlexColumnWidth(1.5),  // Amount
                  },
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
                        ),
                      ),
                      children: [
                        _invoiceTableHeaderCell('SrNo', pw.TextAlign.center),
                        _invoiceTableHeaderCell('Product Name', pw.TextAlign.left),
                        _invoiceTableHeaderCell('Qty', pw.TextAlign.center),
                        _invoiceTableHeaderCell('Rate', pw.TextAlign.center),
                        _invoiceTableHeaderCell('Amount', pw.TextAlign.center),
                      ],
                    ),
                    // Item / Empty Rows
                    ...List.generate(paddedItems.length, (index) {
                      final item = paddedItems[index];
                      return pw.TableRow(
                        children: [
                          _invoiceTableBodyCell(item != null ? '${index + 1}' : '', pw.TextAlign.center),
                          _invoiceTableBodyCell(item != null ? item.name.toUpperCase() : '', pw.TextAlign.left),
                          _invoiceTableBodyCell(item != null ? item.quantity.toStringAsFixed(3) : '', pw.TextAlign.right),
                          _invoiceTableBodyCell(item != null ? item.rate.toStringAsFixed(2) : '', pw.TextAlign.right),
                          _invoiceTableBodyCell(item != null ? item.total.toStringAsFixed(2) : '', pw.TextAlign.right),
                        ],
                      );
                    }),
                    // Table Subtotals / Totals
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(color: PdfColors.black, width: 1.5),
                        ),
                      ),
                      children: [
                        _invoiceTableBodyCell('', pw.TextAlign.center),
                        _invoiceTableBodyCell('Total', pw.TextAlign.right, isBold: true),
                        _invoiceTableBodyCell(
                          invoice.items.fold(0.0, (sum, i) => sum + i.quantity).toStringAsFixed(3),
                          pw.TextAlign.right,
                          isBold: true,
                        ),
                        _invoiceTableBodyCell('Sub Total', pw.TextAlign.right, isBold: true),
                        _invoiceTableBodyCell(invoice.subtotal.toStringAsFixed(2), pw.TextAlign.right, isBold: true),
                      ],
                    ),
                  ],
                ),

                // --- OUTSTANDING & GRAND TOTAL SECTION ---
                pw.Container(
                  height: 50,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Due Details
                      pw.Expanded(
                        flex: 4,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Container(width: 80, child: pw.Text("Bill Amount", style: const pw.TextStyle(fontSize: 8))),
                                  pw.Text(": ", style: const pw.TextStyle(fontSize: 8)),
                                  pw.Text(
                                    "${invoice.grandTotal.toStringAsFixed(2)} ${invoice.isPaid ? 'CASH' : 'CR'}",
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 2),
                              pw.Row(
                                children: [
                                  pw.Container(width: 80, child: pw.Text("Previous Due", style: const pw.TextStyle(fontSize: 8))),
                                  pw.Text(": ", style: const pw.TextStyle(fontSize: 8)),
                                  pw.Text(
                                    formatDue(previousDue),
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 2),
                              pw.Row(
                                children: [
                                  pw.Container(width: 80, child: pw.Text("Total Due", style: const pw.TextStyle(fontSize: 8))),
                                  pw.Text(": ", style: const pw.TextStyle(fontSize: 8)),
                                  pw.Text(
                                    formatDue(totalDue),
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Divider
                      pw.Container(width: 1.5, color: PdfColors.black),
                      // Signature block
                      pw.Expanded(
                        flex: 3,
                        child: pw.Container(
                          alignment: pw.Alignment.bottomCenter,
                          padding: const pw.EdgeInsets.only(bottom: 6),
                          child: pw.Text(
                            "Receiver Signature",
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                        ),
                      ),
                      // Divider
                      pw.Container(width: 1.5, color: PdfColors.black),
                      // Grand total block (shaded)
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Expanded(
                              child: pw.Container(
                                color: PdfColors.grey300,
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  mainAxisAlignment: pw.MainAxisAlignment.center,
                                  children: [
                                    pw.Text(
                                      "Grand Total",
                                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                                    ),
                                    pw.SizedBox(height: 2),
                                    pw.Align(
                                      alignment: pw.Alignment.centerRight,
                                      child: pw.Text(
                                        invoice.grandTotal.toStringAsFixed(2),
                                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Lower section separator
                pw.Container(height: 1.5, color: PdfColors.black),

                // --- AMOUNT IN WORDS ROW ---
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    "Bill Amount : ${_numberToWords(invoice.grandTotal)}",
                    style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _invoiceTableHeaderCell(String text, pw.TextAlign align) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _invoiceTableBodyCell(String text, pw.TextAlign align, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  String _numberToWords(double amount) {
    if (amount < 0) {
      return "Minus " + _numberToWords(-amount);
    }

    int integerPart = amount.floor();
    int decimalPart = ((amount - integerPart) * 100).round();

    String integerWords = _convertIntegerToWords(integerPart);
    if (integerWords.isEmpty) {
      integerWords = "Zero";
    }

    String result = integerWords;

    if (decimalPart > 0) {
      String decimalWords = _convertIntegerToWords(decimalPart);
      result += " and Paise $decimalWords";
    }

    return "$result Only";
  }

  String _convertIntegerToWords(int number) {
    if (number == 0) return "";

    final units = [
      "", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten",
      "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen", "Nineteen"
    ];

    final tens = [
      "", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"
    ];

    if (number < 20) {
      return units[number];
    }

    if (number < 100) {
      return tens[number ~/ 10] + (number % 10 != 0 ? " " + units[number % 10] : "");
    }

    if (number < 1000) {
      return units[number ~/ 100] + " Hundred" + (number % 100 != 0 ? " " + _convertIntegerToWords(number % 100) : "");
    }

    if (number < 100000) {
      return _convertIntegerToWords(number ~/ 1000) + " Thousand" + (number % 1000 != 0 ? " " + _convertIntegerToWords(number % 1000) : "");
    }

    if (number < 10000000) {
      return _convertIntegerToWords(number ~/ 100000) + " Lakh" + (number % 100000 != 0 ? " " + _convertIntegerToWords(number % 100000) : "");
    }

    return _convertIntegerToWords(number ~/ 10000000) + " Crore" + (number % 10000000 != 0 ? " " + _convertIntegerToWords(number % 10000000) : "");
  }

  // ═══════════════════════════════════════════════════════════════
  //  OUTSTANDING DAILY PDF REPORT
  // ═══════════════════════════════════════════════════════════════

  Future<Uint8List> generateOutstandingPdf(List<OutstandingSummary> summaries) async {
    final pdf = pw.Document();
    final profile = await DatabaseHelper.instance.getStoreProfile();
    final storeName = profile['storeName'] ?? 'HP Bill';
    final storeAddress = profile['storeAddress'] ?? '';
    final today = dateFormatter.format(DateTime.now());

    const primaryColor = PdfColor.fromInt(0xFF7C3AED);
    const lightBgColor = PdfColor.fromInt(0xFFF9FAFB);
    const borderMuted = PdfColor.fromInt(0xFFE5E7EB);

    final totalDue = summaries.fold(0.0, (sum, s) => sum + s.balance);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        storeName.toUpperCase(),
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: const pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'OUTSTANDING REPORT',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Date: $today', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: borderMuted),
              pw.SizedBox(height: 8),

              // Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Accounts: ${summaries.length}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Total Outstanding: ${currencyFormatter.format(totalDue)}',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                ],
              ),
              pw.SizedBox(height: 16),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Table
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: borderMuted, width: 0.5),
                bottom: pw.BorderSide(color: borderMuted, width: 1),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.6),
                1: pw.FlexColumnWidth(3.0),
                2: pw.FlexColumnWidth(2.0),
                3: pw.FlexColumnWidth(2.0),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: lightBgColor),
                  children: [
                    _tableHeaderCell('#', true),
                    _tableHeaderCell('Customer Name', false),
                    _tableHeaderCell('Last Activity', true),
                    _tableHeaderCell('Balance Due', true),
                  ],
                ),
                ...List.generate(summaries.length, (index) {
                  final s = summaries[index];
                  return pw.TableRow(
                    children: [
                      _tableBodyCell('${index + 1}', true),
                      _tableBodyCell(s.customerName, false),
                      _tableBodyCell(dateFormatter.format(s.lastTransactionDate), true),
                      _tableBodyCell(
                        "${s.balance > 0 ? '-' : '+'} ${currencyFormatter.format(s.balance.abs())}",
                        true,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: borderMuted),
              pw.SizedBox(height: 4),
              pw.Text('Generated by HP POS System on $today', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  //  LEDGER PDF EXPORT (Daily / Monthly / Yearly)
  // ═══════════════════════════════════════════════════════════════

  Future<Uint8List> generateLedgerPdf(String customerName, List<LedgerEntry> entries, String filterLabel) async {
    final pdf = pw.Document();
    final profile = await DatabaseHelper.instance.getStoreProfile();
    final storeName = profile['storeName'] ?? 'HP Bill';
    final storeAddress = profile['storeAddress'] ?? '';
    final today = dateFormatter.format(DateTime.now());

    const primaryColor = PdfColor.fromInt(0xFF7C3AED);
    const lightBgColor = PdfColor.fromInt(0xFFF9FAFB);
    const borderMuted = PdfColor.fromInt(0xFFE5E7EB);

    final closingBal = entries.isNotEmpty ? entries.last.runningBalance : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(storeName.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: const pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.all(pw.Radius.circular(3))),
                        child: pw.Text('LEDGER STATEMENT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text('Filter: $filterLabel', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Date: $today', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Account: $customerName', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Closing Balance: ${currencyFormatter.format(closingBal)}',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: borderMuted),
              pw.SizedBox(height: 4),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: borderMuted, width: 0.5),
                bottom: pw.BorderSide(color: borderMuted, width: 1),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.5),
                1: pw.FlexColumnWidth(3.0),
                2: pw.FlexColumnWidth(1.2),
                3: pw.FlexColumnWidth(1.2),
                4: pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: lightBgColor),
                  children: [
                    _tableHeaderCell('Date', false),
                    _tableHeaderCell('Description', false),
                    _tableHeaderCell('Debit', true),
                    _tableHeaderCell('Credit', true),
                    _tableHeaderCell('Balance', true),
                  ],
                ),
                ...entries.map((entry) {
                  final isDebit = entry.type == LedgerEntryType.debit;
                  return pw.TableRow(
                    children: [
                      _tableBodyCell(dateFormatter.format(entry.date), false),
                      _tableBodyCell(entry.description, false),
                      _tableBodyCell(isDebit ? currencyFormatter.format(entry.amount) : '-', true),
                      _tableBodyCell(!isDebit ? currencyFormatter.format(entry.amount) : '-', true),
                      _tableBodyCell(currencyFormatter.format(entry.runningBalance), true),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: borderMuted),
              pw.Text('Generated by HP POS System on $today', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  //  NATIVE PRINT TRIGGERS
  // ═══════════════════════════════════════════════════════════════

  Future<void> printInvoice(Invoice invoice) async {
    final pdfBytes = await generateA4InvoicePdf(invoice);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }

  Future<void> printOutstandingReport(List<OutstandingSummary> summaries) async {
    final pdfBytes = await generateOutstandingPdf(summaries);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Outstanding_Report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
  }

  Future<void> printLedgerReport(String customer, List<LedgerEntry> entries, String filterLabel) async {
    final pdfBytes = await generateLedgerPdf(customer, entries, filterLabel);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Ledger_${customer.replaceAll(' ', '_')}_$filterLabel.pdf',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════════

  static pw.Widget _tableHeaderCell(String text, bool alignRight) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _tableBodyCell(String text, bool alignRight) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _summaryRow(String title, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }
}
