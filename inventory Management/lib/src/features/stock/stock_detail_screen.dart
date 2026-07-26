import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';
import 'data/stock_provider.dart';
import '../../core/auth/security_helper.dart';

class StockDetailScreen extends ConsumerStatefulWidget {
  final StockItem item;
  const StockDetailScreen({super.key, required this.item});

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  static const Color brandGreen = Color(0xFF1B5E20);
  String? _selectedVariantId;

  void _showEditStockItemDialog(BuildContext context, WidgetRef ref, StockItem item) {
    final nameController = TextEditingController(text: item.itemName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit Item Name',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: brandGreen,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Item Name',
              prefixIcon: const Icon(Icons.inventory_2_outlined),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: brandGreen),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              ref.read(stockProvider.notifier).updateStockItem(
                    item.id,
                    nameController.text.trim(),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddVariantDialog(BuildContext context) {
    final thicknessController = TextEditingController();
    final lengthController = TextEditingController();
    final widthController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: brandGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_box_outlined, color: brandGreen, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Add Variant',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: brandGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: thicknessController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    decoration: InputDecoration(
                      labelText: 'Thickness (mm) (Optional)',
                      hintText: 'e.g. 18',
                      prefixIcon: const Icon(Icons.line_weight),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: lengthController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                          decoration: InputDecoration(
                            labelText: 'Length (Opt)',
                            hintText: 'e.g. 10',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: widthController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                          decoration: InputDecoration(
                            labelText: 'Width (Opt)',
                            hintText: 'e.g. 10',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stockController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    decoration: InputDecoration(
                      labelText: 'Initial Stock Qty',
                      prefixIcon: const Icon(Icons.numbers),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter 0 if none';
                      final val = double.tryParse(v);
                      if (val == null || val < 0) return 'Enter valid stock count';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            ref.read(stockProvider.notifier).addStockVariant(
                                  widget.item.id,
                                  widget.item.itemName,
                                  thickness: double.tryParse(thicknessController.text),
                                  length: double.tryParse(lengthController.text),
                                  width: double.tryParse(widthController.text),
                                  initialStock: double.parse(stockController.text),
                                );
                            Navigator.pop(ctx);
                          },
                          child: const Text('Add Variant'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteVariantDialog(BuildContext context, StockVariant variant, String variantName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Variant',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Delete variant "$variantName" and its transaction logs?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (_selectedVariantId == variant.id) {
                          _selectedVariantId = null;
                        }
                        ref.read(stockProvider.notifier).deleteStockVariant(
                              widget.item.id,
                              variant.id,
                              widget.item.itemName,
                              variantName,
                              variant.currentStock,
                            );
                        Navigator.pop(ctx);
                      },
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuantityDialog(BuildContext context, StockVariant variant, String variantName, String type) {
    final quantityController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    final isAdd = type == 'ADD';
    final title = isAdd ? 'Add Stock' : 'Sell Stock';
    final color = isAdd ? brandGreen : Colors.red.shade400;
    final icon = isAdd ? Icons.add_circle_outline : Icons.remove_circle_outline;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.item.itemName} ($variantName)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      hintText: 'Enter quantity',
                      prefixIcon: Icon(Icons.inventory_2_outlined, color: color),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: color, width: 2),
                      ),
                    ),
                    validator: (v) {
                      final val = double.tryParse(v ?? '');
                      if (val == null || val <= 0) return 'Enter valid quantity';
                      if (!isAdd && val > variant.currentStock) {
                        return 'Cannot sell more than current stock (${variant.currentStock.toStringAsFixed(0)})';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: 'Note (Optional)',
                      hintText: 'e.g. New delivery, customer order',
                      prefixIcon: Icon(Icons.note_alt_outlined, color: color),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: color, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            ref.read(stockProvider.notifier).updateVariantStock(
                                  widget.item.id,
                                  variant.id,
                                  widget.item.itemName,
                                  variantName,
                                  type,
                                  double.parse(quantityController.text),
                                  noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                                );
                            Navigator.pop(ctx);
                          },
                          child: Text(isAdd ? 'Add Stock' : 'Sell Stock'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteTransactionDialog(BuildContext context, StockLog log, String variantName) async {
    final verified = await showPasswordVerificationDialog(context);
    if (verified) {
      ref.read(stockProvider.notifier).deleteStockLog(
            widget.item.id,
            log.variantId ?? '',
            log.id,
            widget.item.itemName,
            variantName,
            log.quantityChange,
            log.type,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted successfully'),
            backgroundColor: brandGreen,
          ),
        );
      }
    }
  }

  void _showEditTransactionDialog(BuildContext context, StockLog log, StockVariant variant, String variantName) {
    final quantityController = TextEditingController(text: log.quantityChange.toStringAsFixed(0));
    final noteController = TextEditingController(text: log.note ?? '');
    final formKey = GlobalKey<FormState>();
    String selectedType = log.type; // 'ADD' or 'SELL'
    DateTime selectedDate = log.date;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: brandGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_note_outlined, color: brandGreen, size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Edit Stock Transaction',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: brandGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.item.itemName} ($variantName)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        labelText: 'Transaction Type',
                        prefixIcon: const Icon(Icons.swap_horiz, color: brandGreen),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ADD', child: Text('Addition (ADD)')),
                        DropdownMenuItem(value: 'SELL', child: Text('Sale (SELL)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        hintText: 'Enter quantity',
                        prefixIcon: const Icon(Icons.inventory_2_outlined, color: brandGreen),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val <= 0) return 'Enter valid quantity';
                        
                        // Check if selling more than available stock (adjusted for the transaction being edited)
                        double adjustedStock = variant.currentStock;
                        if (log.type == 'ADD') {
                          adjustedStock -= log.quantityChange;
                        } else {
                          adjustedStock += log.quantityChange;
                        }
                        
                        if (selectedType == 'SELL' && val > adjustedStock) {
                          return 'Cannot sell more than available stock (${adjustedStock.toStringAsFixed(0)})';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Note (Optional)',
                        hintText: 'e.g. New delivery, customer order',
                        prefixIcon: const Icon(Icons.note_alt_outlined, color: brandGreen),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: Theme.of(context).colorScheme.copyWith(primary: brandGreen),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: brandGreen),
                            const SizedBox(width: 12),
                            Text(
                              'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final verified = await showPasswordVerificationDialog(context);
                              if (verified) {
                                ref.read(stockProvider.notifier).updateStockLog(
                                      itemId: widget.item.id,
                                      variantId: variant.id,
                                      logId: log.id,
                                      itemName: widget.item.itemName,
                                      variantName: variantName,
                                      oldQuantity: log.quantityChange,
                                      newQuantity: double.parse(quantityController.text),
                                      oldType: log.type,
                                      newType: selectedType,
                                      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                                      date: selectedDate,
                                    );
                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Transaction updated successfully'),
                                      backgroundColor: brandGreen,
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditVariantDetailsDialog(BuildContext context, StockVariant variant, String variantName) {
    final thicknessController = TextEditingController(text: variant.thickness?.toString() ?? '');
    final lengthController = TextEditingController(text: variant.length?.toString() ?? '');
    final widthController = TextEditingController(text: variant.width?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: brandGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_outlined, color: brandGreen, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Edit Variant Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: brandGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: thicknessController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    decoration: InputDecoration(
                      labelText: 'Thickness (mm) (Optional)',
                      hintText: 'e.g. 18',
                      prefixIcon: const Icon(Icons.line_weight),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: lengthController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                          decoration: InputDecoration(
                            labelText: 'Length (Opt)',
                            hintText: 'e.g. 10',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: widthController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                          decoration: InputDecoration(
                            labelText: 'Width (Opt)',
                            hintText: 'e.g. 10',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            ref.read(stockProvider.notifier).updateStockVariant(
                                  widget.item.id,
                                  variant.id,
                                  widget.item.itemName,
                                  variantName,
                                  thickness: double.tryParse(thicknessController.text),
                                  length: double.tryParse(lengthController.text),
                                  width: double.tryParse(widthController.text),
                                );
                            Navigator.pop(ctx);
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteAllHistoryDialog(BuildContext context, StockVariant variant, String variantName) async {
    final verified = await showPasswordVerificationDialog(context);
    if (verified) {
      await ref.read(stockProvider.notifier).clearVariantHistory(
            widget.item.id,
            variant.id,
            widget.item.itemName,
            variantName,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All transaction history deleted successfully'),
            backgroundColor: brandGreen,
          ),
        );
      }
    }
  }

  String _getVariantName(StockVariant variant) {
    final parts = <String>[];
    if (variant.length != null && variant.width != null) {
      parts.add('${variant.length!.toString().replaceAll(RegExp(r'\.0$'), '')} x ${variant.width!.toString().replaceAll(RegExp(r'\.0$'), '')}');
    }
    if (variant.thickness != null) {
      parts.add('${variant.thickness!.toString().replaceAll(RegExp(r'\.0$'), '')} mm');
    } else {
      parts.add('Default mm');
    }
    return parts.isNotEmpty ? parts.join(' - ') : 'Default Size';
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = ref.watch(stockItemsProvider).when(
      data: (items) => items.firstWhere((i) => i.id == widget.item.id, orElse: () => widget.item),
      loading: () => widget.item,
      error: (_, __) => widget.item,
    );

    final variantsAsync = ref.watch(stockVariantsProvider(widget.item.id));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        foregroundColor: brandGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: brandGreen,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          currentItem.itemName,
          style: const TextStyle(
            color: brandGreen,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: brandGreen),
            onPressed: () => _showEditStockItemDialog(context, ref, currentItem),
            tooltip: 'Edit Item Name',
          ),
          IconButton(
            onPressed: () => _showAddVariantDialog(context),
            icon: const Icon(Icons.add_circle_outline, color: brandGreen),
            tooltip: 'Add Variant',
          ),
        ],
      ),
      body: Column(
        children: [
          // Total Stock Header Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [brandGreen, brandGreen.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: brandGreen.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.layers, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Aggregated Stock',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${currentItem.currentQuantity.toStringAsFixed(0)} units',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Variants Section Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PRODUCT VARIANTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.2,
                  ),
                ),
                variantsAsync.when(
                  data: (list) => Text(
                    'Count: ${list.length}',
                    style: const TextStyle(fontSize: 12, color: brandGreen, fontWeight: FontWeight.bold),
                  ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),

          // Variants Horizontal/Vertical List
          Expanded(
            child: variantsAsync.when(
              data: (variants) {
                if (variants.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.style_outlined, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No Variants Added',
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'To manage stock, you must add at least one variant (e.g. Size/Length/Width)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: brandGreen),
                            onPressed: () => _showAddVariantDialog(context),
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Add Variant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // If no variant is selected, select the first one
                if (_selectedVariantId == null || !variants.any((v) => v.id == _selectedVariantId)) {
                  _selectedVariantId = variants.first.id;
                }

                final selectedVariant = variants.firstWhere((v) => v.id == _selectedVariantId, orElse: () => variants.first);
                final selectedVarName = _getVariantName(selectedVariant);

                return Column(
                  children: [
                    // Horizontal Variant Selector
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: variants.length,
                        itemBuilder: (context, index) {
                          final variant = variants[index];
                          final isSelected = variant.id == _selectedVariantId;
                          final varName = _getVariantName(variant);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedVariantId = variant.id;
                              });
                            },
                            onLongPress: () => _showDeleteVariantDialog(context, variant, varName),
                            child: Container(
                              width: 140,
                              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? brandGreen : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected ? brandGreen : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    variant.thickness != null 
                                        ? '${variant.thickness!.toString().replaceAll(RegExp(r'\.0$'), '')} mm' 
                                        : 'Default mm',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (variant.length != null && variant.width != null)
                                        ? '${variant.length!.toString().replaceAll(RegExp(r'\.0$'), '')} x ${variant.width!.toString().replaceAll(RegExp(r'\.0$'), '')}'
                                        : 'Default Size',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white70 : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${variant.currentStock.toStringAsFixed(0)} units',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : brandGreen,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Quick Action Buttons for the active variant
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () => _showQuantityDialog(context, selectedVariant, selectedVarName, 'ADD'),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Stock', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade400,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () => _showQuantityDialog(context, selectedVariant, selectedVarName, 'SELL'),
                              icon: const Icon(Icons.remove),
                              label: const Text('Sell Stock', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Transaction History for active variant
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'History: $selectedVarName',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: brandGreen,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.edit, color: brandGreen, size: 20),
                                    onPressed: () => _showEditVariantDetailsDialog(context, selectedVariant, selectedVarName),
                                    tooltip: 'Edit Variant Dimensions',
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(Icons.delete_sweep, color: Colors.red.shade400, size: 20),
                                    onPressed: () => _showDeleteAllHistoryDialog(context, selectedVariant, selectedVarName),
                                    tooltip: 'Delete All History',
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ref.watch(stockLogsProvider('${widget.item.id}_${selectedVariant.id}')).when(
                                    data: (logs) {
                                      if (logs.isEmpty) {
                                        return Center(
                                          child: Text(
                                            'No transactions for this variant',
                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                          ),
                                        );
                                      }
                                      return ListView.separated(
                                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                        itemCount: logs.length,
                                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                                        itemBuilder: (_, index) {
                                          final log = logs[index];
                                          final isAdd = log.type == 'ADD';
                                          final color = isAdd ? brandGreen : Colors.red.shade400;
                                          final icon = isAdd ? Icons.add_circle_outline : Icons.remove_circle_outline;

                                          return GestureDetector(
                                            onTap: () => _showEditTransactionDialog(context, log, selectedVariant, selectedVarName),
                                            onLongPress: () => _showDeleteTransactionDialog(context, log, selectedVarName),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.surface,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.grey.shade200),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(icon, color: color, size: 20),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          isAdd ? 'Stock Addition' : 'Stock Sale',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                            color: Theme.of(context).colorScheme.onSurface,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          '${log.date.day}/${log.date.month}/${log.date.year}',
                                                          style: TextStyle(
                                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        if (log.note != null && log.note!.isNotEmpty) ...[
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            log.note!,
                                                            style: TextStyle(
                                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                                              fontSize: 12,
                                                              fontStyle: FontStyle.italic,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    '${isAdd ? '+' : '-'}${log.quantityChange.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      color: color,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    loading: () => const Center(child: CircularProgressIndicator()),
                                    error: (e, _) => Center(child: Text('Error: $e')),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: brandGreen)),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}