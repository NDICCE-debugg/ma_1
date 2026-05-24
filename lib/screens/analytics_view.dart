import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:ma_1/models/hospital_asset.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ma_1/screens/asset_detail_view.dart';
import 'package:ma_1/screens/ai_diagnostics_sheet.dart';
import 'package:ma_1/services/asset_service.dart';
import 'package:ma_1/services/predictive_maintenance_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_1/models/spare_part.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:ma_1/services/notification_service.dart';
import 'package:ma_1/theme/app_theme.dart';

// â”€â”€â”€ Supplier model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class Supplier {
  final int? id;
  final String name;
  final String physicalAddress;
  final String gpsLocation;
  final String phone;
  final String email;
  final int averageLeadTimeDays;
  final String notes;

  Supplier({
    this.id,
    required this.name,
    this.physicalAddress = '',
    this.gpsLocation = '',
    this.phone = '',
    this.email = '',
    this.averageLeadTimeDays = 0,
    this.notes = '',
  });

  factory Supplier.fromMap(Map<String, dynamic> m) => Supplier(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? 'Unknown Supplier',
        physicalAddress: (m['physical_address'] as String?) ?? '',
        gpsLocation: (m['gps_location'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        averageLeadTimeDays:
            (m['average_lead_time_days'] as num?)?.toInt() ?? 0,
        notes: (m['notes'] as String?) ?? '',
      );
}

// â”€â”€â”€ Main Widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView>
    with SingleTickerProviderStateMixin {
  TabController? _tabCtrl;

  late Future<List<HospitalAsset>> _equipmentFuture;

  // Active filters for Equipment Tab
  String? _filterType;
  String? _filterStatus;
  String? _filterLocation;

  // Spare Parts
  late Future<List<SparePart>> _inventoryFuture;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Suppliers
  late Future<List<Supplier>> _suppliersFuture;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _refreshEquipment();
    _refreshInventory();
    _refreshSuppliers();
    _searchCtrl.addListener(
      () =>
          setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim()),
    );
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refreshInventory() {
    setState(() {
      _inventoryFuture = DatabaseHelper.instance.getInventory();
    });
  }

  void _refreshEquipment() {
    setState(() {
      _equipmentFuture = AssetService.instance.getAllAssets();
    });
  }

  void _refreshSuppliers() {
    setState(() {
      _suppliersFuture = _fetchSuppliers();
    });
  }

  String _assetSectionLabel(int index) => switch (index) {
        1 => 'Spare Parts',
        2 => 'Suppliers',
        3 => 'AI Prognostics',
        _ => 'Equipment',
      };

  String _assetSectionDescription(int index) => switch (index) {
        1 => 'Stock levels, reorder thresholds, and storage bins',
        2 => 'Approved vendors, contacts, and lead times',
        3 => 'AI diagnostic audits, wear logs, and risk telemetry',
        _ => 'Machine records, service state, and QR intake',
      };

  IconData _assetSectionIcon(int index) => switch (index) {
        1 => Icons.inventory_2_outlined,
        2 => Icons.storefront_outlined,
        3 => Icons.auto_awesome_outlined,
        _ => Icons.monitor_heart_outlined,
      };

  void _selectAssetSection(int index) {
    final tabCtrl = _tabCtrl;
    if (tabCtrl == null || tabCtrl.index == index) return;
    tabCtrl.animateTo(index);
    setState(() {});
  }

  void _refreshActiveSection() {
    switch (_tabCtrl?.index ?? 0) {
      case 1:
        _refreshInventory();
        break;
      case 2:
        _refreshSuppliers();
        break;
      default:
        _refreshEquipment();
    }
  }

  Future<List<Supplier>> _fetchSuppliers() async {
    try {
      final res = await Supabase.instance.client
          .from('suppliers')
          .select()
          .order('name', ascending: true);
      return (res as List)
          .map((m) => Supplier.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Return built-in fallback so the UI never shows empty
      return _fallbackSuppliers();
    }
  }

  List<Supplier> _fallbackSuppliers() => [
        Supplier(
          name: 'Drager Medical Zimbabwe',
          physicalAddress: '124 Samora Machel Ave, Harare',
          phone: '+263 24 279 1234',
          email: 'support.zw@draeger.com',
          averageLeadTimeDays: 5,
          notes: 'Primary local supplier for Draeger ICU equipment.',
        ),
        Supplier(
          name: 'Aeonmed Co. Ltd',
          physicalAddress: 'Airport Industrial Zone, Beijing, China',
          phone: '+86 10 8498 1122',
          email: 'service@aeonmed.com',
          averageLeadTimeDays: 14,
          notes: 'Direct manufacturer - Aeonmed VG series parts.',
        ),
        Supplier(
          name: 'Mindray Clinical Solutions',
          physicalAddress: 'High-Tech Industrial Park, Shenzhen, China',
          phone: '+86 755 8188 8999',
          email: 'service@mindray.com',
          averageLeadTimeDays: 10,
          notes: 'Mindray A-series anaesthetic workstations.',
        ),
        Supplier(
          name: 'Harare Surgical & Diagnostics',
          physicalAddress: '88 Baines Avenue, Harare',
          phone: '+263 24 270 4545',
          email: 'orders@hararesurgical.co.zw',
          averageLeadTimeDays: 2,
          notes: 'Local distributor for consumables & sensors.',
        ),
        Supplier(
          name: 'Philips Healthcare Africa',
          physicalAddress: 'Sunninghill, Johannesburg, RSA',
          phone: '+27 11 471 4000',
          email: 'support.africa@philips.com',
          averageLeadTimeDays: 7,
          notes: 'Philips patient monitors, defibrillators, imaging.',
        ),
        Supplier(
          name: 'GE Healthcare East Africa',
          physicalAddress: 'Upperhill, Nairobi, Kenya',
          phone: '+254 20 374 5000',
          email: 'eastafrica@gehealthcare.com',
          averageLeadTimeDays: 12,
          notes: 'GE monitors, ultrasound, imaging accessories.',
        ),
        Supplier(
          name: 'Mediquip Zimbabwe (Pvt) Ltd',
          physicalAddress: '16 Fife Avenue, Harare',
          phone: '+263 24 276 6000',
          email: 'info@mediquip.co.zw',
          averageLeadTimeDays: 3,
          notes: 'General hospital consumables & sterilisation supplies.',
        ),
      ];

  // â”€â”€â”€ QR SCANNER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _openQrScanner() {
    if (kIsWeb) {
      _showStatusMessage(
        'QR scanning requires the mobile app. Use the search bar to find items.',
        AppTheme.primary,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _QrScannerSheet(),
    ).then((scannedData) {
      if (scannedData is String) _handleQrResult(scannedData);
    });
  }

  void _handleQrResult(String raw) async {
    Map<String, dynamic>? qrData;
    try {
      qrData = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}

    if (qrData != null) {
      _showEditPartDialog(context,
          prefill: SparePart(
            name: qrData['name'] as String? ?? '',
            compatibleModel: qrData['model'] as String? ?? '',
            quantity: (qrData['qty'] as num?)?.toInt() ?? 0,
            reorderThreshold: (qrData['min'] as num?)?.toInt() ?? 1,
            location: qrData['location'] as String? ?? 'General Store',
            unit: qrData['unit'] as String? ?? 'pcs',
            notes: qrData['notes'] as String? ?? 'Added via QR scan',
          ));
      return;
    }

    final all = await DatabaseHelper.instance.getInventory();
    if (!mounted) return;
    final query = raw.toLowerCase().trim();
    final matches = all
        .where((p) =>
            p.name.toLowerCase().contains(query) ||
            p.compatibleModel.toLowerCase().contains(query) ||
            p.notes.toLowerCase().contains(query))
        .toList();

    if (matches.isNotEmpty) {
      setState(() {
        _searchCtrl.text = raw;
        _searchQuery = raw.toLowerCase().trim();
      });
      _showStatusMessage(
          'Found ${matches.length} match(es) for "$raw"', AppTheme.success);
    } else {
      _showEditPartDialog(context,
          prefill: SparePart(
            name: raw,
            compatibleModel: '',
            quantity: 0,
            reorderThreshold: 1,
            location: 'General Store',
            unit: 'pcs',
            notes: 'Added via QR scan',
          ));
    }
  }

  // â”€â”€â”€ ADD/EDIT PART SHEET â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _showEditPartDialog(BuildContext context,
      {SparePart? existingPart, SparePart? prefill}) async {
    final part = await showDialog<SparePart>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PartEditorDialog(
        existingPart: existingPart,
        prefill: prefill,
      ),
    );

    if (part == null) return;
    if (existingPart == null) {
      await DatabaseHelper.instance.addSparePart(part);
    } else {
      await DatabaseHelper.instance.updateSparePart(part);
    }
    await NotificationService.checkInventoryAlerts();
    if (!mounted) return;
    _refreshInventory();
    _showStatusMessage('Record saved successfully', AppTheme.success);
  }

  // ignore: unused_element
  void _showEditPartSheet(BuildContext context,
      {SparePart? existingPart, SparePart? prefill}) {
    final src = existingPart ?? prefill;
    final nameCtrl = TextEditingController(text: src?.name ?? '');
    final modelCtrl = TextEditingController(text: src?.compatibleModel ?? '');
    final qtyCtrl = TextEditingController(text: src?.quantity.toString() ?? '');
    final minCtrl =
        TextEditingController(text: src?.reorderThreshold.toString() ?? '');
    final unitCtrl = TextEditingController(text: src?.unit ?? 'pcs');
    final locationCtrl =
        TextEditingController(text: src?.location ?? 'General Store');
    final lastRestockCtrl = TextEditingController(
        text: existingPart?.lastRestocked ??
            DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final notesCtrl = TextEditingController(text: src?.notes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      prefill != null && existingPart == null
                          ? Icons.qr_code_scanner
                          : Icons.inventory_2_outlined,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    existingPart != null
                        ? 'Edit Part Record'
                        : prefill != null
                            ? 'Add Item from QR Scan'
                            : 'Add New Part',
                    style: const TextStyle(
                        color: AppTheme.primaryDark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit'),
                  ),
                ],
              ),
              if (prefill != null && existingPart == null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: AppTheme.success, size: 14),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Fields pre-filled from QR scan. Review and confirm.',
                          style: TextStyle(
                              color: AppTheme.success,
                              fontSize: 12,
                              fontFamily: 'Outfit'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _buildClinicalInput('Part Name / Identifier', nameCtrl),
              _buildClinicalInput('Compatible Machine Model', modelCtrl),
              Row(
                children: [
                  Expanded(
                      child: _buildClinicalInput('Quantity', qtyCtrl,
                          isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildClinicalInput('Min. Threshold', minCtrl,
                          isNumber: true)),
                ],
              ),
              Row(
                children: [
                  Expanded(
                      child: _buildClinicalInput('Unit (e.g. pcs)', unitCtrl)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildClinicalInput(
                          'Storage Location', locationCtrl)),
                ],
              ),
              _buildClinicalInput('Last Restocked', lastRestockCtrl),
              _buildClinicalInput('Internal Notes', notesCtrl),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: () async {
                    final newPart = SparePart(
                      id: existingPart?.id,
                      name: nameCtrl.text.trim(),
                      compatibleModel: modelCtrl.text.trim(),
                      quantity: int.tryParse(qtyCtrl.text) ?? 0,
                      reorderThreshold: int.tryParse(minCtrl.text) ?? 1,
                      location: locationCtrl.text.trim().isEmpty
                          ? 'General Store'
                          : locationCtrl.text.trim(),
                      unit: unitCtrl.text.trim().isEmpty
                          ? 'pcs'
                          : unitCtrl.text.trim(),
                      lastRestocked: lastRestockCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                    );
                    if (existingPart == null) {
                      await DatabaseHelper.instance.addSparePart(newPart);
                    } else {
                      await DatabaseHelper.instance.updateSparePart(newPart);
                    }
                    await NotificationService.checkInventoryAlerts();
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _refreshInventory();
                    _showStatusMessage(
                        'Record saved successfully', AppTheme.success);
                  },
                  child: Text(
                      existingPart == null
                          ? 'Add to Inventory'
                          : 'Save Changes',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ RESTOCK SHEET â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showRestockSheet(BuildContext context, SparePart part) {
    final addQtyCtrl = TextEditingController();
    final dateCtrl = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update Stock: ${part.name}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit')),
            const SizedBox(height: 4),
            Text('Current: ${part.quantity} ${part.unit}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            _buildClinicalInput('Quantity to Add', addQtyCtrl, isNumber: true),
            _buildClinicalInput('Restock Date', dateCtrl),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: () async {
                  final addQty = int.tryParse(addQtyCtrl.text) ?? 0;
                  if (addQty > 0) {
                    await DatabaseHelper.instance.updateSparePart(SparePart(
                      id: part.id,
                      name: part.name,
                      compatibleModel: part.compatibleModel,
                      quantity: part.quantity + addQty,
                      reorderThreshold: part.reorderThreshold,
                      location: part.location,
                      unit: part.unit,
                      lastRestocked: dateCtrl.text,
                      notes: part.notes,
                      imageFileName: part.imageFileName,
                      imageBytes: part.imageBytes,
                    ));
                    await NotificationService.checkInventoryAlerts();
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _refreshInventory();
                    _showStatusMessage('Inventory updated', AppTheme.secondary);
                  }
                },
                child: const Text('Update Stock',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ——— HELPERS ————————————————————————————————————————————————————————————

  void _showStatusMessage(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color,
      content: Text(msg,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontFamily: 'Outfit')),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _buildClinicalInput(String label, TextEditingController ctrl,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.textSecondary),
          fillColor: const Color(0xFFF8FAFC),
          filled: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        ),
      ),
    );
  }

  // â”€â”€â”€ BUILD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    // Lazily initialize _tabCtrl so hot-reload (which reuses the State object
    // without calling initState again) never crashes on LateInitializationError.
    _tabCtrl ??= TabController(length: 3, vsync: this);
    final tabCtrl = _tabCtrl!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      // FAB only on Spare Parts tab
      floatingActionButton: ListenableBuilder(
        listenable: tabCtrl,
        builder: (_, __) => tabCtrl.index == 1
            ? FloatingActionButton(
                backgroundColor: AppTheme.primary,
                elevation: 4,
                tooltip: 'Add new spare part',
                onPressed: () => _showEditPartDialog(context),
                child: const Icon(Icons.add, color: Colors.white),
              )
            : const SizedBox.shrink(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactAssetToolbar(tabCtrl),

          const SizedBox(height: 4),

          // â”€â”€ Tab Views â”€â”€
          Expanded(
            child: TabBarView(
              controller: tabCtrl,
              children: [
                _buildEquipmentTab(),
                _buildSparePartsTab(),
                _buildSuppliersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-
  //  TAB 1 â€” SPARE PARTS
  // â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-

  Widget _buildCompactAssetToolbar(TabController tabCtrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ListenableBuilder(
        listenable: tabCtrl,
        builder: (context, _) {
          final index = tabCtrl.index;
          final isEquipment = index == 0;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.deepBlue.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PopupMenuButton<int>(
                      initialValue: index,
                      tooltip: 'Choose asset section',
                      position: PopupMenuPosition.under,
                      color: AppTheme.surface,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.divider),
                      ),
                      onSelected: _selectAssetSection,
                      itemBuilder: (context) => List.generate(
                        4,
                        (itemIndex) => PopupMenuItem<int>(
                          value: itemIndex,
                          child: Row(
                            children: [
                              Icon(
                                _assetSectionIcon(itemIndex),
                                size: 18,
                                color: itemIndex == index
                                    ? AppTheme.secondary
                                    : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _assetSectionLabel(itemIndex),
                                style: TextStyle(
                                  color: itemIndex == index
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppTheme.muted,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: AppTheme.deepBlue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _assetSectionIcon(index),
                                  color: Colors.white,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _assetSectionLabel(index),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontFamily: 'Outfit',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      _assetSectionDescription(index),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontFamily: 'Outfit',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppTheme.textSecondary,
                                size: 19,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (isEquipment)
                  Tooltip(
                    message: kIsWeb
                        ? 'QR scanning available on mobile'
                        : 'Scan asset QR code',
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        fixedSize: const Size(42, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _openQrScanner,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
                    ),
                  ),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  tooltip: 'Asset actions',
                  position: PopupMenuPosition.under,
                  color: AppTheme.surface,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.divider),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'refresh':
                        _refreshActiveSection();
                        break;
                      case 'scan':
                        _openQrScanner();
                        break;
                      case 'add-part':
                        _showEditPartDialog(context);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Refresh section'),
                        ],
                      ),
                    ),
                    if (isEquipment)
                      const PopupMenuItem<String>(
                        value: 'scan',
                        child: Row(
                          children: [
                            Icon(Icons.qr_code_scanner_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Scan QR code'),
                          ],
                        ),
                      ),
                    if (index == 1)
                      const PopupMenuItem<String>(
                        value: 'add-part',
                        child: Row(
                          children: [
                            Icon(Icons.add_box_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Add spare part'),
                          ],
                        ),
                      ),
                  ],
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: const Icon(
                      Icons.more_horiz_rounded,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField(String hintText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(
          fontSize: 14,
          fontFamily: 'Outfit',
          color: Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
            fontFamily: 'Outfit',
          ),
          prefixIcon:
              const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close,
                      color: Color(0xFF64748B), size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          fillColor: Colors.white,
          filled: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      backgroundColor: isActive ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
      elevation: 0,
      side: BorderSide(
        color: isActive ? AppTheme.primary : const Color(0xFFE2E8F0),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isActive ? AppTheme.primary : const Color(0xFF64748B),
          fontFamily: 'Outfit',
        ),
      ),
      onPressed: onTap,
    );
  }

  void _showFilterMenuType() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          const Text('Filter by Equipment Type',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit')),
          const Divider(),
          ListTile(
            title: const Text('All Equipment', style: TextStyle(fontFamily: 'Outfit')),
            trailing: _filterType == null ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () {
              setState(() => _filterType = null);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Ventilators', style: TextStyle(fontFamily: 'Outfit')),
            trailing: _filterType == 'ventilator' ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () {
              setState(() => _filterType = 'ventilator');
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Anaesthetic Machines', style: TextStyle(fontFamily: 'Outfit')),
            trailing: _filterType == 'anaesthetic_machine' ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () {
              setState(() => _filterType = 'anaesthetic_machine');
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showFilterMenuStatus() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          const Text('Filter by Machine Status',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit')),
          const Divider(),
          ListTile(
            title: const Text('All Status', style: TextStyle(fontFamily: 'Outfit')),
            trailing: _filterStatus == null ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () {
              setState(() => _filterStatus = null);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Active (Operational)', style: TextStyle(fontFamily: 'Outfit')),
            trailing: _filterStatus == 'OPERATIONAL' ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () {
              setState(() => _filterStatus = 'OPERATIONAL');
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Maintenance Due', style: TextStyle(fontFamily: 'Outfit')),
            trailing: _filterStatus == 'MAINTENANCE' ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () {
              setState(() => _filterStatus = 'MAINTENANCE');
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Offline / Faulty', style: TextStyle(fontFamily: 'Outfit')),
            trailing: _filterStatus == 'OFFLINE' ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () {
              setState(() => _filterStatus = 'OFFLINE');
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showFilterMenuLocation() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          const Text('Filter by Hospital Department',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit')),
          const Divider(),
          ListTile(
            title: const Text('All Locations', style: TextStyle(fontFamily: 'Outfit')),
            trailing: _filterLocation == null ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () {
              setState(() => _filterLocation = null);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Main Ward (MAIN)', style: TextStyle(fontFamily: 'Outfit')),
            trailing: _filterLocation == 'MAIN' ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () {
              setState(() => _filterLocation = 'MAIN');
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Pediatrics (PAEDIATRIC)', style: TextStyle(fontFamily: 'Outfit')),
            trailing: _filterLocation == 'PAEDIATRIC' ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () {
              setState(() => _filterLocation = 'PAEDIATRIC');
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Maternity (MATERNITY)', style: TextStyle(fontFamily: 'Outfit')),
            trailing: _filterLocation == 'MATERNITY' ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () {
              setState(() => _filterLocation = 'MATERNITY');
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color iconColor,
    required Color subColor,
  }) {
    return Container(
      width: 154,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              color: subColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterPill(
            label: _filterType == null
                ? 'All Equipment'
                : (_filterType == 'ventilator' ? 'Ventilators' : 'Anaesthetic Machines'),
            isActive: _filterType != null,
            onTap: () => _showFilterMenuType(),
          ),
          const SizedBox(width: 8),
          _buildFilterPill(
            label: _filterStatus == null
                ? 'All Status'
                : (_filterStatus == 'OPERATIONAL'
                    ? 'Active'
                    : (_filterStatus == 'MAINTENANCE' ? 'Maintenance Due' : 'Offline')),
            isActive: _filterStatus != null,
            onTap: () => _showFilterMenuStatus(),
          ),
          const SizedBox(width: 8),
          _buildFilterPill(
            label: _filterLocation == null ? 'All Locations' : _filterLocation!,
            isActive: _filterLocation != null,
            onTap: () => _showFilterMenuLocation(),
          ),
          const SizedBox(width: 8),
          if (_filterType != null || _filterStatus != null || _filterLocation != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _filterType = null;
                  _filterStatus = null;
                  _filterLocation = null;
                });
              },
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing 1-$count of $count machines',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                onPressed: () {},
              ),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '1',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  '2',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text('...', style: TextStyle(color: Color(0xFF64748B))),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionDots(String status) {
    int activeDots = 4;
    Color dotColor = const Color(0xFF10B981); // Emerald green
    String conditionLabel = 'Excellent';

    switch (status) {
      case 'OPERATIONAL':
        activeDots = 3;
        dotColor = const Color(0xFF10B981);
        conditionLabel = 'Good';
        break;
      case 'MAINTENANCE':
        activeDots = 2;
        dotColor = const Color(0xFFF59E0B); // Amber yellow
        conditionLabel = 'Fair';
        break;
      case 'OFFLINE':
        activeDots = 1;
        dotColor = const Color(0xFFEF4444); // Red
        conditionLabel = 'Critical';
        break;
      case 'DECOMMISSIONED':
        activeDots = 0;
        dotColor = const Color(0xFF64748B); // Slate grey
        conditionLabel = 'Retired';
        break;
      default:
        activeDots = 4;
        dotColor = const Color(0xFF10B981);
        conditionLabel = 'Excellent';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Condition',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (idx) {
            final isActive = idx < activeDots;
            return Container(
              margin: const EdgeInsets.only(right: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? dotColor : const Color(0xFFE2E8F0),
              ),
            );
          }),
        ),
        const SizedBox(height: 3),
        Text(
          conditionLabel,
          style: TextStyle(
            color: activeDots == 0 ? const Color(0xFF64748B) : dotColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    String label = 'Active';
    Color color = const Color(0xFF10B981);

    switch (status) {
      case 'OPERATIONAL':
        label = 'Active';
        color = const Color(0xFF10B981);
        break;
      case 'MAINTENANCE':
        label = 'Maintenance Due';
        color = const Color(0xFFF59E0B);
        break;
      case 'OFFLINE':
        label = 'Offline';
        color = const Color(0xFFEF4444);
        break;
      case 'DECOMMISSIONED':
        label = 'Retired';
        color = const Color(0xFF64748B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentTab() {
    return FutureBuilder<List<HospitalAsset>>(
      future: _equipmentFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final all = snapshot.data!;
        
        // Dynamically compute Summary metrics
        final totalCount = all.length;
        final activeCount = all.where((a) => a.status == 'OPERATIONAL').length;
        final inServiceCount = all.where((a) => a.status != 'OFFLINE' && a.status != 'DECOMMISSIONED').length;
        final maintenanceCount = all.where((a) => a.status == 'MAINTENANCE').length;

        final activePct = totalCount > 0 ? (activeCount / totalCount * 100).toStringAsFixed(1) : '0';
        final inServicePct = totalCount > 0 ? (inServiceCount / totalCount * 100).toStringAsFixed(1) : '0';
        final maintenancePct = totalCount > 0 ? (maintenanceCount / totalCount * 100).toStringAsFixed(1) : '0';

        final assets = all.where((asset) {
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery;
            final matchesQuery = asset.modelName.toLowerCase().contains(query) ||
                asset.serialNumber.toLowerCase().contains(query) ||
                asset.hospitalUnit.toLowerCase().contains(query) ||
                asset.wardLocation.toLowerCase().contains(query) ||
                asset.status.toLowerCase().contains(query);
            if (!matchesQuery) return false;
          }

          if (_filterType != null && asset.assetType != _filterType) return false;
          if (_filterStatus != null && asset.status != _filterStatus) return false;
          if (_filterLocation != null && asset.hospitalUnit != _filterLocation) return false;

          return true;
        }).toList();

        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => _refreshEquipment(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              // Beautiful Header Stats Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _buildSummaryCard(
                      title: 'Total Machines',
                      value: '$totalCount',
                      sub: 'All equipment',
                      icon: Icons.monitor_heart_outlined,
                      iconColor: AppTheme.primary,
                      subColor: const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 12),
                    _buildSummaryCard(
                      title: 'Active',
                      value: '$activeCount',
                      sub: '$activePct% of total',
                      icon: Icons.check_circle_outline,
                      iconColor: const Color(0xFF10B981),
                      subColor: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 12),
                    _buildSummaryCard(
                      title: 'In Service',
                      value: '$inServiceCount',
                      sub: '$inServicePct% of total',
                      icon: Icons.build_circle_outlined,
                      iconColor: AppTheme.secondary,
                      subColor: AppTheme.secondary,
                    ),
                    const SizedBox(width: 12),
                    _buildSummaryCard(
                      title: 'Maintenance Due',
                      value: '$maintenanceCount',
                      sub: '$maintenancePct% of total',
                      icon: Icons.warning_amber_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      subColor: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSearchField('Search by machine name, ID, or location...'),
              const SizedBox(height: 8),

              _buildFilterBar(),
              const SizedBox(height: 12),

              if (assets.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.monitor_heart_outlined,
                          size: 56,
                          color: AppTheme.textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No equipment matches this filter selection',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                ...assets.asMap().entries.map(
                      (entry) => _buildEquipmentCard(entry.value)
                          .animate()
                          .fadeIn(delay: (entry.key * 30).ms)
                          .slideY(begin: 0.04, end: 0),
                    ),
                _buildPaginationBar(assets.length),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEquipmentCard(HospitalAsset asset) {
    final locationText = [
      asset.hospitalUnit,
      asset.wardLocation,
    ].where((value) => value.trim().isNotEmpty).join(' - ');

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AssetDetailView(assetData: asset.toMap()),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Dynamic Image loading (Bytes or Network curated stock fallbacks)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                clipBehavior: Clip.antiAlias,
                child: asset.imageBytes != null
                    ? Image.memory(asset.imageBytes!, fit: BoxFit.cover)
                    : (asset.imageFileName.isNotEmpty && asset.imageFileName.startsWith('http'))
                        ? Image.network(
                            asset.imageFileName,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.monitor_heart_outlined,
                              color: AppTheme.primary,
                              size: 28,
                            ),
                          )
                        : const Icon(
                            Icons.monitor_heart_outlined,
                            color: AppTheme.primary,
                            size: 28,
                          ),
              ),
              const SizedBox(width: 16),

              // Machine Title & identity details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.modelName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      locationText.isEmpty ? 'Location pending' : locationText,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ID: ${asset.serialNumber.isEmpty ? "Pending" : asset.serialNumber}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Status chip pill & Last Maintenance
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusChip(asset.status),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        asset.lastServiceDate.isEmpty ? 'Pending' : asset.lastServiceDate,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 20),

              // Dynamic Condition dots indicators column
              _buildConditionDots(asset.status),
              const SizedBox(width: 12),

              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSparePartsTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(
                fontSize: 14, fontFamily: 'Outfit', color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Search parts by name, model or location...',
              hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Outfit'),
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          color: Color(0xFF64748B), size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              fillColor: Colors.white,
              filled: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
            ),
          ),
        ),

        Expanded(
          child: FutureBuilder<List<SparePart>>(
            future: _inventoryFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary));
              }

              final all = snapshot.data!;
              final parts = _searchQuery.isEmpty
                  ? all
                  : all
                      .where((p) =>
                          p.name.toLowerCase().contains(_searchQuery) ||
                          p.compatibleModel
                              .toLowerCase()
                              .contains(_searchQuery) ||
                          p.notes.toLowerCase().contains(_searchQuery) ||
                          p.location.toLowerCase().contains(_searchQuery))
                      .toList();

              final hasCritical =
                  all.any((p) => p.quantity <= p.reorderThreshold);

              if (parts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 56,
                          color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No parts match "$_searchQuery"'
                            : 'No spare parts in inventory',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15,
                            fontFamily: 'Outfit'),
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => _showEditPartDialog(context,
                              prefill: SparePart(
                                name: _searchQuery,
                                compatibleModel: '',
                                quantity: 0,
                                reorderThreshold: 1,
                                location: 'General Store',
                                unit: 'pcs',
                              )),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: Text('Add "$_searchQuery" to inventory',
                              style: const TextStyle(fontFamily: 'Outfit')),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                children: [
                  if (hasCritical && _searchQuery.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16, top: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: AppTheme.error, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Low Stock Alert: Some items require immediate restock.',
                              style: TextStyle(
                                  color: AppTheme.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'Outfit'),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                  if (_searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${parts.length} result${parts.length == 1 ? '' : 's'} for "$_searchQuery"',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontFamily: 'Outfit'),
                      ),
                    ),
                  ...parts.asMap().entries.map((e) =>
                      _buildInventoryCard(e.value)
                          .animate()
                          .fadeIn(delay: (e.key * 40).ms)
                          .slideY(begin: 0.05, end: 0)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryCard(SparePart part) {
    final isCritical = part.quantity <= part.reorderThreshold;
    final isWarning =
        part.quantity <= part.reorderThreshold * 1.5 && !isCritical;
    final statusColor = isCritical
        ? AppTheme.error
        : (isWarning ? AppTheme.warning : AppTheme.success);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCritical
              ? AppTheme.error.withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: isCritical
              ? const Border(left: BorderSide(color: AppTheme.error, width: 4))
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.muted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: part.imageBytes == null
                        ? const Icon(Icons.inventory_2_outlined,
                            color: AppTheme.textSecondary, size: 22)
                        : Image.memory(part.imageBytes!, fit: BoxFit.cover),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(part.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                fontFamily: 'Outfit',
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        Text(part.compatibleModel,
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontFamily: 'Outfit')),
                        if (part.location.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 11, color: AppTheme.neutral),
                              const SizedBox(width: 3),
                              Text(part.location,
                                  style: const TextStyle(
                                      color: AppTheme.neutral,
                                      fontSize: 11,
                                      fontFamily: 'Outfit')),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        part.quantity.toString(),
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 26,
                            fontFamily: 'Outfit'),
                      ),
                      Text(part.unit.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (part.quantity /
                          (part.reorderThreshold * 3).clamp(1, 9999))
                      .clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: AppTheme.background,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Restocked: ${part.lastRestocked}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontFamily: 'Outfit')),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () =>
                            _showEditPartDialog(context, existingPart: part),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4)),
                        child: const Text('Edit',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit')),
                      ),
                      TextButton(
                        onPressed: () => _showRestockSheet(context, part),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.secondary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4)),
                        child: const Text('Restock',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit')),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-
  //  TAB 2 â€” SUPPLIERS
  // â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-â-

  Widget _buildSuppliersTab() {
    return FutureBuilder<List<Supplier>>(
      future: _suppliersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_outlined,
                    size: 48, color: AppTheme.textSecondary),
                const SizedBox(height: 12),
                const Text('Could not load suppliers',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontFamily: 'Outfit')),
                const SizedBox(height: 8),
                TextButton(
                    onPressed: _refreshSuppliers, child: const Text('Retry')),
              ],
            ),
          );
        }

        final suppliers = snapshot.data!;

        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => _refreshSuppliers(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              // Summary chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.08),
                      AppTheme.secondary.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.store_outlined,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${suppliers.length} Approved Vendors',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                color: AppTheme.textPrimary)),
                        const Text(
                          'Pull to refresh for latest data',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontFamily: 'Outfit'),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              ...suppliers.asMap().entries.map((e) =>
                  _buildSupplierCard(e.value)
                      .animate()
                      .fadeIn(delay: (e.key * 50).ms)
                      .slideY(begin: 0.06, end: 0)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupplierCard(Supplier s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + lead-time badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.store_outlined,
                      color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              fontFamily: 'Outfit',
                              color: AppTheme.textPrimary)),
                      if (s.physicalAddress.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 12, color: AppTheme.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(s.physicalAddress,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                        fontFamily: 'Outfit'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Lead time badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: s.averageLeadTimeDays <= 3
                        ? AppTheme.success.withValues(alpha: 0.1)
                        : s.averageLeadTimeDays <= 7
                            ? AppTheme.warning.withValues(alpha: 0.1)
                            : AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: s.averageLeadTimeDays <= 3
                          ? AppTheme.success.withValues(alpha: 0.3)
                          : s.averageLeadTimeDays <= 7
                              ? AppTheme.warning.withValues(alpha: 0.3)
                              : AppTheme.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${s.averageLeadTimeDays}d',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'Outfit',
                            color: s.averageLeadTimeDays <= 3
                                ? AppTheme.success
                                : s.averageLeadTimeDays <= 7
                                    ? AppTheme.warning
                                    : AppTheme.error),
                      ),
                      Text('lead',
                          style: TextStyle(
                              fontSize: 9,
                              fontFamily: 'Outfit',
                              color: s.averageLeadTimeDays <= 3
                                  ? AppTheme.success
                                  : s.averageLeadTimeDays <= 7
                                      ? AppTheme.warning
                                      : AppTheme.error)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Contact row
            Row(
              children: [
                if (s.phone.isNotEmpty)
                  Expanded(
                    child: _contactChip(Icons.phone_outlined, s.phone),
                  ),
                if (s.email.isNotEmpty)
                  Expanded(
                    child: _contactChip(Icons.email_outlined, s.email),
                  ),
              ],
            ),

            // Notes
            if (s.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_outlined,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.notes,
                          style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Outfit',
                              color: AppTheme.textSecondary)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _contactChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Outfit',
                  color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildPrognosticsTab() {
    return FutureBuilder<List<HospitalAsset>>(
      future: _equipmentFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final all = snapshot.data!;

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: Future.wait(all.map((a) => PredictiveMaintenanceService.instance.getPrognostics(a))),
          builder: (context, progSnapshot) {
            if (!progSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }

            final progList = progSnapshot.data!;

            // Sort by health score ascending (highest risk first)
            progList.sort((a, b) => (a['healthScore'] as double).compareTo(b['healthScore'] as double));

            final highCount = progList.where((p) => p['riskLevel'] == 'HIGH').length;
            final medCount = progList.where((p) => p['riskLevel'] == 'MEDIUM').length;
            final lowCount = progList.where((p) => p['riskLevel'] == 'LOW').length;

            return RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () async => _refreshEquipment(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                children: [
                  // Beautiful Risk Indicators fleet dashboard
                  _buildPrognosticOverviewRow(highCount, medCount, lowCount),
                  const SizedBox(height: 20),

                  if (progList.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome_outlined,
                              size: 56,
                              color: AppTheme.textSecondary.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No dynamic prognostics computed.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 15,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    ...progList.asMap().entries.map(
                          (entry) => _buildPrognosticCard(entry.value)
                              .animate()
                              .fadeIn(delay: (entry.key * 30).ms)
                              .slideY(begin: 0.04, end: 0),
                        ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPrognosticOverviewRow(int high, int med, int low) {
    return Row(
      children: [
        Expanded(
          child: _buildPrognosticSummaryCard(
            title: 'High Risk',
            value: '$high',
            color: AppTheme.error,
            icon: Icons.report_problem_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildPrognosticSummaryCard(
            title: 'Medium Risk',
            value: '$med',
            color: AppTheme.warning,
            icon: Icons.warning_amber_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildPrognosticSummaryCard(
            title: 'Stable Fleet',
            value: '$low',
            color: AppTheme.success,
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildPrognosticSummaryCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrognosticCard(Map<String, dynamic> prog) {
    final HospitalAsset asset = prog['asset'] as HospitalAsset;
    final double healthScore = prog['healthScore'] as double;
    final String riskLevel = prog['riskLevel'] as String;
    final String warning = prog['warningMessage'] as String;
    final int remainingDays = prog['remainingLifeDays'] as int;

    final Color statusColor = riskLevel == 'HIGH'
        ? AppTheme.error
        : riskLevel == 'MEDIUM'
            ? AppTheme.warning
            : AppTheme.success;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Circular health percentage indicator
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withValues(alpha: 0.08),
                border: Border.all(color: statusColor.withValues(alpha: 0.18)),
              ),
              child: Text(
                '${healthScore.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Device details & Prognosis alert
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.modelName,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'SN: ${asset.serialNumber}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          warning,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Remaining life projection & AI button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  asset.status == 'OFFLINE' ? 'Failed' : '$remainingDays Days',
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                const Text(
                  'Est. Lifetime',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      // Get compatible parts for this model
                      final parts = await PredictiveMaintenanceService.instance.getMatchingParts(asset.modelName);
                      if (!mounted) return;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => AiDiagnosticsSheet(
                          prog: prog,
                          compatibleParts: parts,
                          onStateChanged: () {
                            _refreshEquipment();
                          },
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 11),
                        SizedBox(width: 4),
                        Text(
                          'Audit',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€ QR SCANNER SHEET â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PartEditorDialog extends StatefulWidget {
  final SparePart? existingPart;
  final SparePart? prefill;

  const _PartEditorDialog({this.existingPart, this.prefill});

  @override
  State<_PartEditorDialog> createState() => _PartEditorDialogState();
}

class _PartEditorDialogState extends State<_PartEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _lastRestockCtrl;
  late final TextEditingController _notesCtrl;
  Uint8List? _imageBytes;
  String _imageFileName = '';

  @override
  void initState() {
    super.initState();
    final src = widget.existingPart ?? widget.prefill;
    _nameCtrl = TextEditingController(text: src?.name ?? '');
    _modelCtrl = TextEditingController(text: src?.compatibleModel ?? '');
    _qtyCtrl = TextEditingController(text: src?.quantity.toString() ?? '');
    _minCtrl =
        TextEditingController(text: src?.reorderThreshold.toString() ?? '');
    _unitCtrl = TextEditingController(text: src?.unit ?? 'pcs');
    _locationCtrl =
        TextEditingController(text: src?.location ?? 'General Store');
    _lastRestockCtrl = TextEditingController(
      text: widget.existingPart?.lastRestocked ??
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _notesCtrl = TextEditingController(text: src?.notes ?? '');
    _imageBytes = src?.imageBytes;
    _imageFileName = src?.imageFileName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _modelCtrl.dispose();
    _qtyCtrl.dispose();
    _minCtrl.dispose();
    _unitCtrl.dispose();
    _locationCtrl.dispose();
    _lastRestockCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    setState(() {
      _imageBytes = file.bytes;
      _imageFileName = file.name;
    });
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Part name is required')),
      );
      return;
    }

    Navigator.pop(
      context,
      SparePart(
        id: widget.existingPart?.id,
        name: _nameCtrl.text.trim(),
        compatibleModel: _modelCtrl.text.trim(),
        quantity: int.tryParse(_qtyCtrl.text) ?? 0,
        reorderThreshold: int.tryParse(_minCtrl.text) ?? 1,
        location: _locationCtrl.text.trim().isEmpty
            ? 'General Store'
            : _locationCtrl.text.trim(),
        unit: _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim(),
        lastRestocked: _lastRestockCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        imageFileName: _imageFileName,
        imageBytes: _imageBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPart != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isEditing
                          ? Icons.inventory_2_outlined
                          : Icons.add_box_outlined,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit inventory item' : 'Add inventory item',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.muted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: _imageBytes == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: AppTheme.textSecondary, size: 30),
                            SizedBox(height: 8),
                            Text(
                              'Add item image',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                        ),
                ),
              ),
              if (_imageBytes != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _imageFileName.isEmpty
                            ? 'Image attached'
                            : _imageFileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _imageBytes = null;
                        _imageFileName = '';
                      }),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Remove'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              _input('Part Name / Identifier', _nameCtrl),
              _input('Compatible Machine Model', _modelCtrl),
              Row(
                children: [
                  Expanded(child: _input('Quantity', _qtyCtrl, isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(
                      child:
                          _input('Min. Threshold', _minCtrl, isNumber: true)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _input('Unit', _unitCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _input('Storage Location', _locationCtrl)),
                ],
              ),
              _input('Last Restocked', _lastRestockCtrl),
              _input('Internal Notes', _notesCtrl),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(isEditing ? 'Save changes' : 'Add to inventory'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(String label, TextEditingController controller,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _QrScannerSheet extends StatefulWidget {
  const _QrScannerSheet();

  @override
  State<_QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<_QrScannerSheet> {
  MobileScannerController? _ctrl;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    _scanned = true;
    Navigator.pop(context, barcode!.rawValue);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.70,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scan Part / Machine QR',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'Outfit')),
                      Text('Point at a QR code or barcode',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontFamily: 'Outfit')),
                    ],
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white70, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(controller: _ctrl!, onDetect: _onDetect),
                Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.iceBlue, width: 2.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _ctrl?.toggleTorch(),
                  icon: const Icon(Icons.flashlight_on_outlined,
                      color: Colors.white70, size: 26),
                  tooltip: 'Toggle flashlight',
                ),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: () => _ctrl?.switchCamera(),
                  icon: const Icon(Icons.flip_camera_ios_outlined,
                      color: Colors.white70, size: 26),
                  tooltip: 'Switch camera',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
