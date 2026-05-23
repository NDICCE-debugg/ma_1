import 'package:flutter/material.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/models/spare_part.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:ma_1/services/notification_service.dart';
import 'package:intl/intl.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  late Future<List<SparePart>> _inventoryFuture;

  @override
  void initState() {
    super.initState();
    _refreshInventory();
  }

  void _refreshInventory() {
    setState(() {
      _inventoryFuture = DatabaseHelper.instance.getInventory();
    });
  }

  void _showEditPartSheet(BuildContext context, [SparePart? existingPart]) {
    final nameCtrl = TextEditingController(text: existingPart?.name ?? '');
    final modelCtrl = TextEditingController(text: existingPart?.compatibleModel ?? '');
    final qtyCtrl = TextEditingController(text: existingPart?.quantity.toString() ?? '');
    final minCtrl = TextEditingController(text: existingPart?.reorderThreshold.toString() ?? '');
    final unitCtrl = TextEditingController(text: existingPart?.unit ?? 'units');
    final lastRestockCtrl = TextEditingController(text: existingPart?.lastRestocked ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final notesCtrl = TextEditingController(text: existingPart?.notes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existingPart == null ? "Add Part" : "Edit Part Record", 
                style: const TextStyle(color: AppTheme.primaryDark, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildClinicalInput("Part Name / Identifier", nameCtrl),
              _buildClinicalInput("Compatible Systems", modelCtrl),
              Row(
                children: [
                  Expanded(child: _buildClinicalInput("Current Quantity", qtyCtrl, isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildClinicalInput("Low Stock Threshold", minCtrl, isNumber: true)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildClinicalInput("Unit (e.g. pcs)", unitCtrl)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildClinicalInput("Last Restocked", lastRestockCtrl)),
                ],
              ),
              _buildClinicalInput("Internal Notes", notesCtrl),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final newPart = SparePart(
                      id: existingPart?.id,
                      name: nameCtrl.text,
                      compatibleModel: modelCtrl.text,
                      quantity: int.tryParse(qtyCtrl.text) ?? 0,
                      reorderThreshold: int.tryParse(minCtrl.text) ?? 0,
                      location: existingPart?.location ?? 'General Store',
                      unit: unitCtrl.text,
                      lastRestocked: lastRestockCtrl.text,
                      notes: notesCtrl.text,
                    );
                    
                    if (existingPart == null) {
                      await DatabaseHelper.instance.addSparePart(newPart);
                    } else {
                      await DatabaseHelper.instance.updateSparePart(newPart);
                    }
                    
                    await NotificationService.checkInventoryAlerts();
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    _refreshInventory();
                    _showStatusMessage("Record saved successfully", AppTheme.success);
                  },
                  child: Text(existingPart == null ? "Add Part" : "Save Changes"),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showRestockSheet(BuildContext context, SparePart part) {
    final addQtyCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Update Stock: ${part.name}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Current Inventory: ${part.quantity} ${part.unit}", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            _buildClinicalInput("Quantity to Add", addQtyCtrl, isNumber: true),
            _buildClinicalInput("Restock Date", dateCtrl),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
                onPressed: () async {
                  int addQty = int.tryParse(addQtyCtrl.text) ?? 0;
                  if (addQty > 0) {
                    final updatedPart = SparePart(
                      id: part.id, name: part.name, compatibleModel: part.compatibleModel,
                      quantity: part.quantity + addQty, reorderThreshold: part.reorderThreshold,
                      location: part.location, unit: part.unit, lastRestocked: dateCtrl.text, notes: part.notes,
                    );
                    await DatabaseHelper.instance.updateSparePart(updatedPart);
                    await NotificationService.checkInventoryAlerts();
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    _refreshInventory();
                    _showStatusMessage("Inventory updated", AppTheme.secondary);
                  }
                },
                child: const Text("Update Stock"),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showStatusMessage(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  Widget _buildClinicalInput(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showEditPartSheet(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Spare Parts", style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 16),
            
            FutureBuilder<List<SparePart>>(
              future: _inventoryFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final parts = snapshot.data!;
                bool hasCritical = parts.any((p) => p.quantity <= p.reorderThreshold);

                return Column(
                  children: [
                    if (hasCritical)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.error.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.error),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text("Low Stock Alert: Some items require immediate restock.", 
                                style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ...parts.map((p) => _buildInventoryCard(p))
                  ],
                );
              }
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryCard(SparePart part) {
    bool isCritical = part.quantity <= part.reorderThreshold;
    bool isWarning = part.quantity <= part.reorderThreshold * 1.5 && !isCritical;
    
    Color statusColor = isCritical ? AppTheme.error : (isWarning ? AppTheme.warning : AppTheme.success);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          border: isCritical ? const Border(left: BorderSide(color: AppTheme.error, width: 4)) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(part.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                        Text(part.compatibleModel, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(part.quantity.toString(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 22)),
                      Text(part.unit.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Clinical Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (part.quantity / (part.reorderThreshold * 3)).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppTheme.background,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Last Restocked: ${part.lastRestocked}", 
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _showEditPartSheet(context, part),
                        child: const Text("Edit", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _showRestockSheet(context, part),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.secondary),
                        child: const Text("Restock", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}