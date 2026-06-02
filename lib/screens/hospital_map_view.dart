import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/models/hospital_asset.dart';
import 'package:ma_1/services/asset_service.dart';
import 'package:ma_1/utils/app_snackbar.dart';

class HospitalMapView extends StatefulWidget {
  const HospitalMapView({super.key});

  @override
  State<HospitalMapView> createState() => _HospitalMapViewState();
}

class _HospitalMapViewState extends State<HospitalMapView> {
  String? _selectedDepartment;

  void _openEquipmentList(String department) {
    setState(() => _selectedDepartment = department);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EquipmentListPanel(department: department),
    ).whenComplete(() => setState(() => _selectedDepartment = null));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Professional Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.map_outlined, color: AppTheme.primary),
              const SizedBox(width: 12),
              Text("Department Map",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 18)),
              const Spacer(),
              const Text("Live View",
                  style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        Expanded(
          child: Container(
            color: AppTheme.background,
            child: Stack(
              children: [
                // Clean Blue-print Painter
                CustomPaint(
                  painter: ClinicalMapPainter(),
                  size: Size.infinite,
                ),

                // Interactive Department Zones
                _buildDepartmentZone("Pediatrics", 0.1, 0.12, 0.35, 0.25),
                _buildDepartmentZone("Maternity", 0.55, 0.12, 0.35, 0.3),
                _buildDepartmentZone("Main Ward", 0.25, 0.52, 0.5, 0.38),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentZone(String dept, double leftPct, double topPct,
      double widthPct, double heightPct) {
    bool isSelected = _selectedDepartment == dept;

    return Positioned(
      left: MediaQuery.of(context).size.width * leftPct,
      top: MediaQuery.of(context).size.height * 0.7 * topPct,
      width: MediaQuery.of(context).size.width * widthPct,
      height: MediaQuery.of(context).size.height * 0.7 * heightPct,
      child: GestureDetector(
        onTap: () => _openEquipmentList(dept),
        child: FutureBuilder<List<HospitalAsset>>(
            future: AssetService.instance.getAssetsByUnit(dept.toUpperCase()),
            builder: (context, snapshot) {
              int vents = 0;
              Color statusColor = AppTheme.primary; // Neutral Blue

              if (snapshot.hasData) {
                for (var a in snapshot.data!) {
                  if (a.assetType == 'ventilator') {
                    vents++;
                  }

                  if (a.status == 'OFFLINE') {
                    statusColor = AppTheme.error;
                  } else if (a.status == 'MAINTENANCE' &&
                      statusColor != AppTheme.error) {
                    statusColor = AppTheme.warning;
                  }
                }
              }

              return AnimatedContainer(
                duration: 300.ms,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.05)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(dept,
                          style: TextStyle(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.5)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4)
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 8, color: statusColor),
                            const SizedBox(width: 6),
                            Text("$vents Ventilators",
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
      ),
    );
  }
}

// --- CLINICAL MAP PAINTER ---
class ClinicalMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final roomFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    void drawRoom(Rect rect) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)), roomFill);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)), linePaint);

      // Simple clinical blueprint lines
      canvas.drawLine(Offset(rect.left, rect.top + 20),
          Offset(rect.right, rect.top + 20), linePaint);
    }

    // Departments
    drawRoom(Rect.fromLTWH(size.width * 0.1, size.height * 0.1,
        size.width * 0.35, size.height * 0.25));
    drawRoom(Rect.fromLTWH(size.width * 0.55, size.height * 0.1,
        size.width * 0.35, size.height * 0.3));
    drawRoom(Rect.fromLTWH(size.width * 0.25, size.height * 0.5,
        size.width * 0.5, size.height * 0.38));

    // Hallway Indicators
    canvas.drawLine(Offset(size.width * 0.45, size.height * 0.2),
        Offset(size.width * 0.55, size.height * 0.2), linePaint);
    canvas.drawLine(Offset(size.width * 0.5, size.height * 0.35),
        Offset(size.width * 0.5, size.height * 0.5), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- EQUIPMENT LIST PANEL ---
class _EquipmentListPanel extends StatefulWidget {
  final String department;
  const _EquipmentListPanel({required this.department});

  @override
  State<_EquipmentListPanel> createState() => _EquipmentListPanelState();
}

class _EquipmentListPanelState extends State<_EquipmentListPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  void _showEquipmentForm(BuildContext context, [HospitalAsset? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => EquipmentEntryForm(
          department: widget.department,
          assetType: _tabCtrl.index == 0 ? 'ventilator' : 'anaesthetic_machine',
          existingAsset: existing,
          onComplete: (asset, isDeleted) {
            Navigator.pop(ctx);
            setState(() {});
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.department,
                        style: Theme.of(context).textTheme.titleLarge),
                    const Text("Equipment List",
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          TabBar(
            controller: _tabCtrl,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            tabs: const [Tab(text: "Ventilators"), Tab(text: "Anaesthetic")],
          ),
          Expanded(
            child: FutureBuilder<List<HospitalAsset>>(
              future: AssetService.instance
                  .getAssetsByUnit(widget.department.toUpperCase()),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final assets = snapshot.data!
                    .where((a) =>
                        a.assetType ==
                        (_tabCtrl.index == 0
                            ? 'ventilator'
                            : 'anaesthetic_machine'))
                    .toList();

                if (assets.isEmpty) {
                  return const Center(
                      child: Text("No equipment found in this department."));
                }

                return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: assets.length,
                    itemBuilder: (context, index) {
                      final asset = assets[index];
                      Color statusColor = asset.status == 'OPERATIONAL'
                          ? AppTheme.success
                          : (asset.status == 'MAINTENANCE'
                              ? AppTheme.warning
                              : AppTheme.error);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () => _showEquipmentForm(context, asset),
                          title: Text(asset.modelName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              "ID: ${asset.serialNumber} - ${asset.wardLocation}"),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(asset.status,
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showEquipmentForm(context),
                child: const Text("Add New Equipment"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- PROFESSIONAL ENTRY FORM ---
class EquipmentEntryForm extends StatefulWidget {
  final String department;
  final String assetType;
  final HospitalAsset? existingAsset;
  final Function(HospitalAsset asset, bool isDeleted)? onComplete;

  const EquipmentEntryForm({
    super.key,
    this.department = 'MAIN',
    this.assetType = 'ventilator',
    this.existingAsset,
    this.onComplete,
  });

  @override
  State<EquipmentEntryForm> createState() => EquipmentEntryFormState();
}

class EquipmentEntryFormState extends State<EquipmentEntryForm> {
  late TextEditingController _modelCtrl,
      _serialCtrl,
      _wardCtrl,
      _svcCtrl,
      _intCtrl;
  String _status = 'OPERATIONAL';
  Uint8List? _imageBytes;
  String _imageFileName = '';
  String _imageUrl = '';
  late String _department;
  late String _assetType;

  @override
  void initState() {
    super.initState();
    _modelCtrl =
        TextEditingController(text: widget.existingAsset?.modelName ?? '');
    _serialCtrl =
        TextEditingController(text: widget.existingAsset?.serialNumber ?? '');
    _wardCtrl =
        TextEditingController(text: widget.existingAsset?.wardLocation ?? '');
    _svcCtrl = TextEditingController(
        text: widget.existingAsset?.lastServiceDate ?? '2024-01-01');
    _intCtrl = TextEditingController(
        text: widget.existingAsset?.serviceInterval ?? '6 Months');
    if (widget.existingAsset != null) _status = widget.existingAsset!.status;
    _imageBytes = widget.existingAsset?.imageBytes;
    _imageFileName = widget.existingAsset?.imageFileName ?? '';
    _imageUrl = widget.existingAsset?.imageUrl ?? '';
    if (_imageUrl.isEmpty && _imageFileName.startsWith('http')) {
      _imageUrl = _imageFileName;
    }

    // Normalize raw department names (e.g. 'MAIN - ICU 1') to the exact dropdown values.
    final rawDept = (widget.existingAsset?.hospitalUnit ?? widget.department).trim().toUpperCase();
    if (rawDept.startsWith('MAIN')) {
      _department = 'MAIN';
    } else if (rawDept.startsWith('PAED') || rawDept.startsWith('PEDI')) {
      _department = 'PAEDIATRIC';
    } else if (rawDept.startsWith('MAT')) {
      _department = 'MATERNITY';
    } else {
      _department = 'MAIN';
    }

    // Normalize raw asset types to the exact dropdown values.
    final rawType = (widget.existingAsset?.assetType ?? widget.assetType).trim().toLowerCase();
    if (rawType.contains('vent')) {
      _assetType = 'ventilator';
    } else if (rawType.contains('anes') || rawType.contains('anae') || rawType.contains('machine')) {
      _assetType = 'anaesthetic_machine';
    } else {
      _assetType = 'ventilator';
    }
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
      _imageUrl = '';
    });
  }

  Future<void> _selectServiceDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_svcCtrl.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppTheme.ring,
                    onPrimary: Colors.white,
                    surface: Color(0xFF0A1518),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: AppTheme.primary,
                    onPrimary: Colors.white,
                    onSurface: AppTheme.textPrimary,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _svcCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final asset = widget.existingAsset;
    if (asset == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0A1518) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF24353A) : AppTheme.divider,
            width: 1,
          ),
        ),
        title: const Text(
          "Confirm Deletion", 
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)
        ),
        content: Text(
          "Are you sure you want to permanently delete this ${asset.modelName} (SN: ${asset.serialNumber})? This action cannot be undone.",
          style: const TextStyle(fontFamily: 'Outfit'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "Cancel",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Delete",
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AssetService.instance.deleteAsset(asset);
        if (!context.mounted) return;
        AppSnackBar.info(context, '${asset.modelName} permanently deleted.');
        widget.onComplete?.call(asset, true);
      } catch (e) {
        if (!context.mounted) return;
        AppSnackBar.error(context, 'Delete failed. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existingAsset != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A1518) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottom Sheet Swipe Indicator handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF24353A) : AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Custom Dialog/Sheet Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isDark ? AppTheme.ring : AppTheme.primary).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      !isEditing ? Icons.add_box_outlined : Icons.edit_note_rounded,
                      color: isDark ? AppTheme.ring : AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          !isEditing ? "Add New Equipment" : "Update Equipment Details",
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Outfit',
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Configure biomedical assets and status logging",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Outfit',
                            color: isDark ? Colors.white60 : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 16),

              _buildSectionCard(
                context,
                title: "Machine specs & Image",
                icon: Icons.settings_suggest_outlined,
                children: [
                  // Immersive Photo Selection Banner
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF111F23) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF24353A) : AppTheme.divider,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.015),
                            blurRadius: 10,
                          )
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _imageBytes == null && _imageUrl.isEmpty
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppTheme.ring : AppTheme.primary).withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: isDark ? AppTheme.ring : AppTheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Add Machine Photo',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Outfit',
                                    color: isDark ? Colors.white : AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Supports PNG or JPG up to 10MB',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : AppTheme.textSecondary,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                _imageBytes != null
                                    ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                                    : Image.network(
                                        _imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.broken_image_outlined,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                // Floating Actions Panel (Trash Icon Overlays)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                      onPressed: () => setState(() {
                                        _imageBytes = null;
                                        _imageFileName = '';
                                        _imageUrl = '';
                                      }),
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                                      tooltip: 'Remove photo',
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 12,
                                  left: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.refresh_rounded, color: Colors.white, size: 12),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            _imageFileName.isNotEmpty
                                                ? _imageFileName
                                                : 'Change Image',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _input(
                    'Model Name',
                    _modelCtrl,
                    prefixIcon: Icons.dns_outlined,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _dropdown<String>(
                          label: 'Department',
                          value: _department,
                          prefixIcon: Icons.corporate_fare_outlined,
                          items: ['MAIN', 'PAEDIATRIC', 'MATERNITY']
                              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (v) => setState(() => _department = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dropdown<String>(
                          label: 'Asset Type',
                          value: _assetType,
                          prefixIcon: Icons.medical_services_outlined,
                          items: const [
                            DropdownMenuItem(value: 'ventilator', child: Text('Ventilator')),
                            DropdownMenuItem(value: 'anaesthetic_machine', child: Text('Anaesthetic')),
                          ],
                          onChanged: (v) => setState(() => _assetType = v!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              _buildSectionCard(
                context,
                title: "Identification & Location",
                icon: Icons.location_on_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _input(
                          'Serial Number',
                          _serialCtrl,
                          prefixIcon: Icons.fingerprint_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _input(
                          'Room/Ward',
                          _wardCtrl,
                          prefixIcon: Icons.meeting_room_outlined,
                        ),
                      ),
                    ],
                  ),
                  _dropdown<String>(
                    label: 'Current Status',
                    value: _status,
                    prefixIcon: Icons.health_and_safety_outlined,
                    items: ['OPERATIONAL', 'MAINTENANCE', 'OFFLINE', 'DECOMMISSIONED']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ],
              ),

              _buildSectionCard(
                context,
                title: "Maintenance timeline",
                icon: Icons.calendar_today_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _input(
                          'Last Service Date',
                          _svcCtrl,
                          prefixIcon: Icons.calendar_month_outlined,
                          readOnly: true,
                          onTap: _selectServiceDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _input(
                          'Service Interval',
                          _intCtrl,
                          prefixIcon: Icons.update_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // Action Buttons Section
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF24353A) : AppTheme.divider,
                        ),
                        foregroundColor: isDark ? Colors.white70 : AppTheme.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? AppTheme.ring : AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        String finalImageFileName = _imageFileName;
                        if (finalImageFileName.isEmpty && _imageBytes == null) {
                          final model = _modelCtrl.text.toLowerCase();
                          final isAnaesthetic = _assetType == 'anaesthetic_machine' ||
                              model.contains('anaesthetic') ||
                              model.contains('wato') ||
                              model.contains('a5') ||
                              model.contains('theatre');
                          if (isAnaesthetic) {
                            finalImageFileName = 'https://images.unsplash.com/photo-1516613975432-f22787d55f07?w=500&auto=format&fit=crop&q=60';
                          } else {
                            finalImageFileName = 'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?w=500&auto=format&fit=crop&q=60';
                          }
                        }

                        final asset = HospitalAsset(
                          id: widget.existingAsset?.id,
                          assetType: _assetType,
                          modelName: _modelCtrl.text,
                          serialNumber: _serialCtrl.text,
                          hospitalUnit: _department,
                          wardLocation: _wardCtrl.text,
                          status: _status,
                          dateAcquired:
                              widget.existingAsset?.dateAcquired ?? '2024-01-01',
                          lastServiceDate: _svcCtrl.text,
                          serviceInterval: _intCtrl.text,
                          notes: widget.existingAsset?.notes ?? '',
                          imageFileName: finalImageFileName,
                          imageUrl: _imageUrl,
                          imageBytes: _imageBytes,
                        );

                        late HospitalAsset savedAsset;
                        try {
                          if (widget.existingAsset == null) {
                            savedAsset = await AssetService.instance.registerAsset(asset);
                            if (!context.mounted) return;
                            AppSnackBar.success(context, '${asset.modelName} registered successfully.');
                          } else {
                            savedAsset = await AssetService.instance.updateAsset(asset);
                            if (!context.mounted) return;
                            AppSnackBar.success(context, '${asset.modelName} updated successfully.');
                          }
                          widget.onComplete?.call(savedAsset, false);
                        } catch (e) {
                          if (!context.mounted) return;
                          AppSnackBar.error(context, 'Could not save equipment. Check your connection.');
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: Text(
                        isEditing ? "Save Changes" : "Register Device",
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (widget.existingAsset != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: const Text(
                      "Delete Equipment", 
                      style: TextStyle(
                        fontFamily: 'Outfit', 
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      )
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111F23).withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF24353A) : AppTheme.divider,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isDark ? AppTheme.ring : AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    IconData? prefixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        style: TextStyle(
          fontFamily: 'Outfit', 
          fontSize: 14,
          color: isDark ? Colors.white : AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontFamily: 'Outfit',
            color: isDark ? Colors.white60 : AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          floatingLabelStyle: TextStyle(
            fontFamily: 'Outfit',
            color: isDark ? AppTheme.ring : AppTheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF0F1A1C) : Colors.white,
          prefixIcon: prefixIcon != null
              ? Icon(
                  prefixIcon,
                  color: isDark ? AppTheme.ring.withValues(alpha: 0.8) : AppTheme.primary.withValues(alpha: 0.7),
                  size: 18,
                )
              : null,
          suffixIcon: onTap != null
              ? Icon(
                  Icons.calendar_month_outlined,
                  color: isDark ? AppTheme.ring : AppTheme.primary,
                  size: 18,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF24353A) : AppTheme.divider,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF1B2E33) : AppTheme.divider,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppTheme.ring : AppTheme.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    IconData? prefixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        style: TextStyle(
          fontFamily: 'Outfit', 
          fontSize: 14,
          color: isDark ? Colors.white : AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontFamily: 'Outfit',
            color: isDark ? Colors.white60 : AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          floatingLabelStyle: TextStyle(
            fontFamily: 'Outfit',
            color: isDark ? AppTheme.ring : AppTheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF0F1A1C) : Colors.white,
          prefixIcon: prefixIcon != null
              ? Icon(
                  prefixIcon,
                  color: isDark ? AppTheme.ring.withValues(alpha: 0.8) : AppTheme.primary.withValues(alpha: 0.7),
                  size: 18,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF24353A) : AppTheme.divider,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF1B2E33) : AppTheme.divider,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppTheme.ring : AppTheme.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
