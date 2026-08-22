import 'dart:convert';
import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hp_bill/models/inventory_item.dart';
import 'package:hp_bill/providers/invoice_provider.dart';
import 'package:hp_bill/providers/transaction_provider.dart';
import 'package:hp_bill/services/share_service.dart';
import 'package:hp_bill/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // Store Profile Controllers
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();

  // Inventory Management Controllers
  final _itemNameController = TextEditingController();
  final _itemRateController = TextEditingController();

  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<InvoiceProvider>();
      prov.fetchStoreDetails();
      _storeNameController.text = prov.storeName;
      _storeAddressController.text = prov.storeAddress;
    });
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _itemNameController.dispose();
    _itemRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProv = context.watch<InvoiceProvider>();
    final transProv = context.watch<TransactionProvider>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          title: const Text("Admin & Configuration"),
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryEmerald,
            labelColor: AppTheme.primaryEmerald,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.storefront_rounded), text: "Profile"),
              Tab(icon: Icon(Icons.inventory_2_rounded), text: "Inventory"),
              Tab(icon: Icon(Icons.cloud_upload_rounded), text: "Data Control"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildProfileTab(invoiceProv, transProv),
            _buildInventoryTab(invoiceProv),
            _buildDataControlTab(invoiceProv),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 1: STORE PROFILE + PERMANENT FINANCIAL METRICS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildProfileTab(InvoiceProvider prov, TransactionProvider transProv) {
    // Calculate today's sales
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todaySales = prov.invoices
        .where((inv) => DateFormat('yyyy-MM-dd').format(inv.date) == todayStr)
        .fold(0.0, (sum, inv) => sum + inv.grandTotal);

    // Calculate monthly sales
    final now = DateTime.now();
    final monthlySales = prov.invoices
        .where((inv) => inv.date.year == now.year && inv.date.month == now.month)
        .fold(0.0, (sum, inv) => sum + inv.grandTotal);

    // Calculate last 6 months sales trend
    final List<Map<String, dynamic>> monthlyTrends = [];
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthName = DateFormat('MMM').format(date);
      final monthSales = prov.invoices
          .where((inv) => inv.date.year == date.year && inv.date.month == date.month)
          .fold(0.0, (sum, inv) => sum + inv.grandTotal);
      monthlyTrends.add({
        'month': monthName,
        'sales': monthSales,
      });
    }

    double maxSales = 0.0;
    for (var item in monthlyTrends) {
      if (item['sales'] > maxSales) {
        maxSales = item['sales'];
      }
    }
    if (maxSales == 0.0) maxSales = 1.0; // avoid division by zero

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- FINANCIAL METRICS ---
          const Text(
            "BUSINESS METRICS",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        "Today's Sales",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currencyFormatter.format(todaySales),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryEmerald),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: AppTheme.accentBorder),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        "Monthly Sales",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currencyFormatter.format(monthlySales),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.secondarySlate),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            "MONTHLY SALES TREND",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Performance (Last 6 Months)",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    Text(
                      "Peak: ${currencyFormatter.format(maxSales == 1.0 && monthlyTrends.every((e) => e['sales'] == 0.0) ? 0.0 : maxSales)}",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 140,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: monthlyTrends.map((data) {
                      final sales = data['sales'] as double;
                      final ratio = sales / maxSales;
                      final barHeight = ratio * 85.0;

                      String compactSalesText = "";
                      if (sales >= 100000) {
                        compactSalesText = "₹${(sales / 100000).toStringAsFixed(1)}L";
                      } else if (sales >= 1000) {
                        compactSalesText = "₹${(sales / 1000).toStringAsFixed(1)}k";
                      } else if (sales > 0) {
                        compactSalesText = "₹${sales.toStringAsFixed(0)}";
                      } else {
                        compactSalesText = "₹0";
                      }

                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              compactSalesText,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              height: barHeight == 0 ? 4.0 : barHeight,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: sales == 0
                                      ? [AppTheme.accentBorder, AppTheme.accentBorder]
                                      : [AppTheme.primaryEmerald, AppTheme.tertiaryMint],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data['month'],
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: AppTheme.accentBorder),
          const SizedBox(height: 16),

          const Text(
            "STORE DETAILS",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _storeNameController,
            decoration: const InputDecoration(
              labelText: "Store / Business Name",
              prefixIcon: Icon(Icons.store_rounded, color: AppTheme.primaryEmerald),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _storeAddressController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "Physical Store Address",
              prefixIcon: Icon(Icons.location_on_rounded, color: AppTheme.primaryEmerald),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await prov.saveStoreProfile(
                  _storeNameController.text,
                  _storeAddressController.text,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Store Profile saved successfully!"),
                    backgroundColor: AppTheme.primaryEmerald,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryEmerald,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text("Save Store Profile"),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 2: INVENTORY MANAGEMENT (STITCH UI SPEC)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildInventoryTab(InvoiceProvider prov) {
    return Column(
      children: [
        // Add item form matching admin_inventory/code.html
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "REGISTER NEW PRODUCT",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _itemNameController,
                  decoration: const InputDecoration(
                    labelText: "Product Name",
                    isDense: true,
                    prefixIcon: Icon(Icons.inventory_2_rounded, color: AppTheme.secondarySlate),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _itemRateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Default Price (₹)",
                    isDense: true,
                    prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppTheme.secondarySlate),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final name = _itemNameController.text.trim();
                      final rateText = _itemRateController.text.trim();
                      final rate = rateText.isEmpty ? null : double.tryParse(rateText);
                      if (name.isNotEmpty) {
                        prov.addInventoryItem(name, rate);
                        _itemNameController.clear();
                        _itemRateController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Product registered successfully!"),
                            backgroundColor: AppTheme.primaryEmerald,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter a valid product name.")),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_task_rounded, size: 18),
                    label: const Text("Save to Inventory"),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryEmerald),
                  ),
                ),
              ],
            ),
          ),
        ),

        const Divider(height: 1, color: AppTheme.outlineVariant),

        // List of saved products
        Expanded(
          child: prov.inventory.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.outlineVariant),
                      SizedBox(height: 12),
                      Text("No items in system inventory.", style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: prov.inventory.length,
                  itemBuilder: (ctx, index) {
                    final item = prov.inventory[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.inventory_2_rounded, color: AppTheme.primaryEmerald, size: 20),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                        ),
                        subtitle: Text(
                          item.defaultRate != null
                              ? "Base Price: ${currencyFormatter.format(item.defaultRate!)}"
                              : "Base Price: Not Set",
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryEmerald, size: 20),
                              onPressed: () => _showEditItemDialog(prov, item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 20),
                              onPressed: () {
                                prov.deleteInventoryItem(item.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Product removed from inventory.")),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showEditItemDialog(InvoiceProvider prov, InventoryItem item) {
    final nameController = TextEditingController(text: item.name);
    final rateController = TextEditingController(
      text: item.defaultRate != null ? item.defaultRate!.toStringAsFixed(0) : "",
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text("Edit Product", style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Product Name",
                  prefixIcon: Icon(Icons.inventory_2_rounded, color: AppTheme.secondarySlate),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: rateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Default Price (₹)",
                  prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppTheme.secondarySlate),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final rateText = rateController.text.trim();
                final rate = rateText.isEmpty ? null : double.tryParse(rateText);

                if (name.isNotEmpty) {
                  final updatedItem = InventoryItem(
                    id: item.id,
                    name: name,
                    defaultRate: rate,
                  );
                  await prov.updateInventoryItem(updatedItem);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Product updated successfully!"),
                      backgroundColor: AppTheme.primaryEmerald,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter a valid product name.")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryEmerald),
              child: const Text("Save Changes"),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 3: MASTER DATA CONTROL CENTER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDataControlTab(InvoiceProvider prov) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant),
              boxShadow: AppTheme.softShadow,
            ),
            child: const Row(
              children: [
                Icon(Icons.security_rounded, color: AppTheme.primaryEmerald),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Master Data Control Center. Backup, restore, or wipe your entire database. Backup files are saved locally and can be restored using the file picker.",
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 1. ALL-IN-ONE BACKUP
          _buildDataActionCard(
            icon: Icons.cloud_upload_rounded,
            iconColor: AppTheme.primaryEmerald,
            title: "All-In-One Backup",
            subtitle: "Exports all inventory, invoices, transactions, ledger entries, and profile into a structured JSON file on your device.",
            buttonLabel: "Export Backup File",
            buttonColor: AppTheme.primaryEmerald,
            onTap: () async {
              try {
                final jsonContent = prov.exportBackupJson();
                await ShareService.instance.shareBackupFile(jsonContent);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Backup file generated and shared successfully!"),
                    backgroundColor: AppTheme.primaryEmerald,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Backup failed: $e")),
                );
              }
            },
          ),

          const SizedBox(height: 14),

          // 2. DATA RESTORE (WITH FILE PICKER)
          _buildDataActionCard(
            icon: Icons.cloud_download_rounded,
            iconColor: AppTheme.secondarySlate,
            title: "Data Restore (Put Back)",
            subtitle: "Select a previously exported backup JSON file from your device storage to restore the app back to its exact saved state.",
            buttonLabel: "Select Backup File",
            buttonColor: AppTheme.secondarySlate,
            onTap: () => _performFileRestore(prov),
          ),

          const SizedBox(height: 14),

          // 3. FULL DATABASE WIPE
          _buildDataActionCard(
            icon: Icons.delete_forever_rounded,
            iconColor: AppTheme.errorRed,
            title: "Full Database Wipe",
            subtitle: "DANGER: Permanently deletes ALL transaction history, inventory items, ledger entries, and profile data.",
            buttonLabel: "Delete All Data",
            buttonColor: AppTheme.errorRed,
            onTap: () => _confirmFullWipe(prov),
          ),
        ],
      ),
    );
  }

  Widget _buildDataActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performFileRestore(InvoiceProvider prov) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final jsonString = utf8.decode(bytes);
        
        await prov.restoreFromJson(jsonString);
        if (context.mounted) {
          await context.read<TransactionProvider>().fetchTransactions();
        }

        if (!mounted) return;
        _storeNameController.text = prov.storeName;
        _storeAddressController.text = prov.storeAddress;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data restored successfully from backup file!"),
            backgroundColor: AppTheme.primaryEmerald,
          ),
        );
      } else if (result != null && result.files.single.path != null) {
        final file = io.File(result.files.single.path!);
        final jsonString = await file.readAsString();

        await prov.restoreFromJson(jsonString);
        if (context.mounted) {
          await context.read<TransactionProvider>().fetchTransactions();
        }

        if (!mounted) return;
        _storeNameController.text = prov.storeName;
        _storeAddressController.text = prov.storeAddress;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data restored successfully from backup file!"),
            backgroundColor: AppTheme.primaryEmerald,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Restore failed: $e"),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  void _confirmFullWipe(InvoiceProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
              SizedBox(width: 8),
              Text("Full Database Wipe", style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: const Text(
            "This will permanently delete ALL transaction history, inventory items, ledger entries, and store profile data.\n\nThis action CANNOT be undone. Are you absolutely sure?",
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await prov.wipeAllData();
                if (context.mounted) {
                  await context.read<TransactionProvider>().fetchTransactions();
                }
                if (!mounted) return;
                Navigator.pop(ctx);
                _storeNameController.clear();
                _storeAddressController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("All data has been permanently deleted."),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
              child: const Text("Delete Everything"),
            ),
          ],
        );
      },
    );
  }
}
