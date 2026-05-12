import 'package:flutter/material.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/utils/animation_helper.dart';
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
      backgroundColor: AppTheme.bgDark,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existingPart == null ? "REGISTER NEW PART" : "EDIT PART RECORD", style: const TextStyle(color: AppTheme.primary, fontSize: 18, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildTerminalInput("PART IDENTIFIER / NAME", nameCtrl),
              _buildTerminalInput("COMPATIBLE SYSTEMS", modelCtrl),
              Row(children: [ Expanded(child: _buildTerminalInput("QUANTITY", qtyCtrl, isNumber: true)), const SizedBox(width: 10), Expanded(child: _buildTerminalInput("MIN THRESHOLD", minCtrl, isNumber: true)) ]),
              Row(children: [ Expanded(child: _buildTerminalInput("UNIT (e.g. pcs)", unitCtrl)), const SizedBox(width: 10), Expanded(child: _buildTerminalInput("LAST RESTOCKED", lastRestockCtrl)) ]),
              _buildTerminalInput("NOTES", notesCtrl),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
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

                  Navigator.pop(ctx);
                  setState(() {});
                  _showFlashMessage("RECORD UPDATED", AppTheme.success);
                },
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), border: Border.all(color: AppTheme.primary)),
                  child: Text(existingPart == null ? "REGISTER PART" : "UPDATE PART RECORD", textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
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
      backgroundColor: AppTheme.bgDark,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(part.name.toUpperCase(), style: const TextStyle(color: AppTheme.primary, fontSize: 18, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, shadows: [Shadow(color: AppTheme.primary, blurRadius: 10)])),
            const SizedBox(height: 10),
            Text("CURRENT STOCK: ${part.quantity} ${part.unit}", style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 20),
            _buildTerminalInput("ADD QUANTITY", addQtyCtrl, isNumber: true),
            _buildTerminalInput("RESTOCK DATE", dateCtrl),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                int addQty = int.tryParse(addQtyCtrl.text) ?? 0;
                if (addQty > 0) {
                  final updatedPart = SparePart(
                    id: part.id, name: part.name, compatibleModel: part.compatibleModel,
                    quantity: part.quantity + addQty, reorderThreshold: part.reorderThreshold,
                    location: part.location, unit: part.unit, lastRestocked: dateCtrl.text, notes: part.notes,
                  );
                  await DatabaseHelper.instance.updateSparePart(updatedPart);
                  
                  await NotificationService.checkInventoryAlerts();
                  await NotificationService.showRestockConfirmation(updatedPart.name, updatedPart.quantity);

                  Navigator.pop(ctx);
                  setState(() {});
                  _showFlashMessage("RESTOCK LOGGED — INVENTORY UPDATED", AppTheme.success);
                }
              },
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.2), border: Border.all(color: AppTheme.accent)),
                child: const Text("CONFIRM RESTOCK", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showFlashMessage(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color.withOpacity(0.9),
        content: Text(msg, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  Widget _buildTerminalInput(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("> $label", style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
            child: TextField(
              controller: ctrl,
              keyboardType: isNumber ? TextInputType.number : TextInputType.text,
              style: const TextStyle(color: Colors.white, fontFamily: 'Share Tech Mono'), 
              decoration: const InputDecoration(border: InputBorder.none, isDense: true)
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () => _showEditPartSheet(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("PARTS INVENTORY CONTROL", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Orbitron')),
            const SizedBox(height: 15),
            
            FutureBuilder<List<SparePart>>(
              future: DatabaseHelper.instance.getInventory(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final parts = snapshot.data!;
                bool hasCritical = parts.any((p) => p.quantity <= p.reorderThreshold);

                return Column(
                  children: [
                    if (hasCritical)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 20),
                        color: AppTheme.error.withOpacity(0.2),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: AppTheme.error),
                            SizedBox(width: 10),
                            Expanded(child: GlitchText("CRITICAL: STOCK LEVELS DEPLETED", style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold))),
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
    Color statusColor = AppTheme.success;
    if (part.quantity <= part.reorderThreshold) {
      statusColor = AppTheme.error;
    } else if (part.quantity <= part.reorderThreshold * 1.2) {
      statusColor = AppTheme.warning;
    }

    double fillPercent = part.quantity == 0 ? 0.0 : (part.quantity / (part.reorderThreshold * 3)).clamp(0.0, 1.0);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: HudBrackets(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(part.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white), overflow: TextOverflow.ellipsis)),
                Text("QTY: ${part.quantity}", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            Text(part.compatibleModel, style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
            const SizedBox(height: 15),
            
            Container(
              height: 6, width: double.infinity, color: Colors.white10,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft, widthFactor: fillPercent,
                child: Container(
                  decoration: BoxDecoration(
                    color: statusColor, 
                    boxShadow: [BoxShadow(color: statusColor, blurRadius: 5)]
                  )
                ),
              ),
            ),
            const SizedBox(height: 15),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("LAST RESTOCK: ${part.lastRestocked}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showEditPartSheet(context, part),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                        decoration: BoxDecoration(border: Border.all(color: Colors.white24)), 
                        child: const Text("EDIT", style: TextStyle(fontSize: 10, color: Colors.white))
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _showRestockSheet(context, part),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                        color: AppTheme.primary.withOpacity(0.2), 
                        child: const Text("RESTOCK", style: TextStyle(fontSize: 10, color: AppTheme.primary))
                      ),
                    ),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}