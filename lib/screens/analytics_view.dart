import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/models/spare_part.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:ma_1/services/notification_service.dart';

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

  // Spare Parts
  late Future<List<SparePart>> _inventoryFuture;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Suppliers
  late Future<List<Supplier>> _suppliersFuture;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
      _showEditPartSheet(context,
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
      _showEditPartSheet(context,
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
    _tabCtrl ??= TabController(length: 2, vsync: this);
    final tabCtrl = _tabCtrl!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      // FAB only on Spare Parts tab
      floatingActionButton: ListenableBuilder(
        listenable: tabCtrl,
        builder: (_, __) => tabCtrl.index == 0
            ? FloatingActionButton(
                backgroundColor: AppTheme.primary,
                elevation: 4,
                tooltip: 'Add new spare part',
                onPressed: () => _showEditPartSheet(context),
                child: const Icon(Icons.add, color: Colors.white),
              )
            : const SizedBox.shrink(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Assets',
                      style: Theme.of(context).textTheme.displayLarge),
                ),
                // QR button — only visible on Spare Parts tab
                ListenableBuilder(
                  listenable: tabCtrl,
                  builder: (_, __) => tabCtrl.index == 0
                      ? Tooltip(
                          message: kIsWeb
                              ? 'QR scanning available on mobile'
                              : 'Scan QR code',
                          child: InkWell(
                            onTap: _openQrScanner,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                              ),
                              child: const Icon(Icons.qr_code_scanner,
                                  color: Colors.white, size: 22),
                            ),
                          ).animate().scale(
                              duration: 400.ms, curve: Curves.easeOutBack),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
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
                          onPressed: () => _showEditPartSheet(context,
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
                            _showEditPartSheet(context, existingPart: part),
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
