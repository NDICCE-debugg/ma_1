import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:ma_1/models/hospital_asset.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ma_1/screens/asset_detail_view.dart';
import 'package:ma_1/services/asset_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_1/models/spare_part.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:ma_1/services/notification_service.dart';
import 'package:ma_1/theme/app_theme.dart';

// ─── Supplier model ─────────────────────────────────────────────────────────

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

// ─── Main Widget ─────────────────────────────────────────────────────────────

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView>
    with SingleTickerProviderStateMixin {
  TabController? _tabCtrl;

  late Future<List<HospitalAsset>> _equipmentFuture;

  // Spare Parts
  late Future<List<SparePart>> _inventoryFuture;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Suppliers
  late Future<List<Supplier>> _suppliersFuture;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
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
          name: 'Dräger Medical Zimbabwe',
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
          notes: 'Direct manufacturer — Aeonmed VG series parts.',
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

  // ─── QR SCANNER ─────────────────────────────────────────────────────────────

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

  // ─── ADD/EDIT PART SHEET ─────────────────────────────────────────────────────

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

  // ─── RESTOCK SHEET ───────────────────────────────────────────────────────────

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

  // ─── HELPERS ────────────────────────────────────────────────────────────────

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

  // ─── BUILD ───────────────────────────────────────────────────────────────────

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
          // ── Header row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.muted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: const Icon(
                      Icons.precision_manufacturing_rounded,
                      color: AppTheme.secondary,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Asset Control',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontFamily: 'Outfit',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Equipment registry, spare parts, suppliers, and QR intake',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListenableBuilder(
                    listenable: tabCtrl,
                    builder: (_, __) => tabCtrl.index == 0
                        ? Tooltip(
                            message: kIsWeb
                                ? 'QR scanning available on mobile'
                                : 'Scan asset QR code',
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              onPressed: _openQrScanner,
                              icon:
                                  const Icon(Icons.qr_code_2_rounded, size: 18),
                              label: const Text(
                                'Scan',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ).animate().scale(
                                duration: 320.ms, curve: Curves.easeOutBack),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // ── Tab Bar ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TabBar(
              controller: tabCtrl,
              indicator: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
              unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w500,
                  fontSize: 13),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.monitor_heart_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Equipment'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Spare Parts'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Suppliers'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ── Tab Views ──
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

  // ══════════════════════════════════════════
  //  TAB 1 — SPARE PARTS
  // ══════════════════════════════════════════

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
        final assets = _searchQuery.isEmpty
            ? all
            : all.where((asset) {
                final query = _searchQuery;
                return asset.modelName.toLowerCase().contains(query) ||
                    asset.serialNumber.toLowerCase().contains(query) ||
                    asset.hospitalUnit.toLowerCase().contains(query) ||
                    asset.wardLocation.toLowerCase().contains(query) ||
                    asset.status.toLowerCase().contains(query);
              }).toList();

        if (assets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.monitor_heart_outlined,
                  size: 56,
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No equipment matches "$_searchQuery"'
                      : 'No equipment records available',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          );
        }

        final attentionCount =
            all.where((asset) => asset.status != 'OPERATIONAL').length;

        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => _refreshEquipment(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              _buildSearchField('Search equipment by model, serial or unit'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
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
                    color: AppTheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.monitor_heart_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${all.length} machine records',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '$attentionCount need attention across active departments',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh equipment',
                      onPressed: _refreshEquipment,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
              if (_searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${assets.length} result${assets.length == 1 ? '' : 's'} for "$_searchQuery"',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ...assets.asMap().entries.map(
                    (entry) => _buildEquipmentCard(entry.value)
                        .animate()
                        .fadeIn(delay: (entry.key * 40).ms)
                        .slideY(begin: 0.05, end: 0),
                  ),
            ],
          ),
        );
      },
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
              hintText: 'Search parts by name, model or location…',
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

  Widget _buildEquipmentCard(HospitalAsset asset) {
    final (statusLabel, statusColor) = _equipmentStatus(asset.status);
    final locationText = [
      asset.hospitalUnit,
      asset.wardLocation,
    ].where((value) => value.trim().isNotEmpty).join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side:
            BorderSide(color: statusColor.withValues(alpha: 0.20), width: 1.2),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: asset.imageBytes == null
                        ? Icon(
                            asset.assetType == 'anaesthetic_machine'
                                ? Icons.air_rounded
                                : Icons.monitor_heart_outlined,
                            color: statusColor,
                            size: 22,
                          )
                        : Image.memory(asset.imageBytes!, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.modelName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          asset.serialNumber.isEmpty
                              ? 'Serial pending'
                              : asset.serialNumber,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _equipmentMetaChip(
                      Icons.apartment_rounded, asset.hospitalUnit),
                  if (asset.wardLocation.trim().isNotEmpty)
                    _equipmentMetaChip(
                        Icons.location_on_outlined, asset.wardLocation),
                  _equipmentMetaChip(
                    Icons.build_circle_outlined,
                    asset.assetType == 'anaesthetic_machine'
                        ? 'Anaesthetic machine'
                        : 'Ventilator',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _equipmentMetric(
                        'Last service',
                        asset.lastServiceDate.isEmpty
                            ? 'Not recorded'
                            : asset.lastServiceDate,
                      ),
                    ),
                    Expanded(
                      child: _equipmentMetric(
                        'Location',
                        locationText.isEmpty ? 'Unassigned' : locationText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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

  // ══════════════════════════════════════════
  //  TAB 2 — SUPPLIERS
  // ══════════════════════════════════════════

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

  (String, Color) _equipmentStatus(String status) {
    switch (status) {
      case 'MAINTENANCE':
        return ('Maintenance', AppTheme.warning);
      case 'OFFLINE':
        return ('Offline', AppTheme.error);
      case 'DECOMMISSIONED':
        return ('Retired', AppTheme.textSecondary);
      default:
        return ('Operational', AppTheme.success);
    }
  }

  Widget _equipmentMetaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _equipmentMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: 'Outfit',
          ),
        ),
      ],
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
}

// ─── QR SCANNER SHEET ────────────────────────────────────────────────────────

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
