import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/models/hospital_asset.dart';
import 'package:ma_1/services/asset_service.dart';

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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _EquipmentEntryForm(
          department: widget.department,
          assetType: _tabCtrl.index == 0 ? 'ventilator' : 'anaesthetic_machine',
          existingAsset: existing,
          onComplete: () {
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
class _EquipmentEntryForm extends StatefulWidget {
  final String department;
  final String assetType;
  final HospitalAsset? existingAsset;
  final VoidCallback onComplete;

  const _EquipmentEntryForm(
      {required this.department,
      required this.assetType,
      this.existingAsset,
      required this.onComplete});

  @override
  State<_EquipmentEntryForm> createState() => _EquipmentEntryFormState();
}

class _EquipmentEntryFormState extends State<_EquipmentEntryForm> {
  late TextEditingController _modelCtrl,
      _serialCtrl,
      _wardCtrl,
      _svcCtrl,
      _intCtrl;
  String _status = 'OPERATIONAL';
  Uint8List? _imageBytes;
  String _imageFileName = '';

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              widget.existingAsset == null ? "Add Equipment" : "Update Details",
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 128,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.muted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: _imageBytes == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: AppTheme.textSecondary),
                        SizedBox(height: 8),
                        Text('Add machine image'),
                      ],
                    )
                  : Image.memory(_imageBytes!, fit: BoxFit.cover),
            ),
          ),
          if (_imageBytes != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _imageBytes = null;
                  _imageFileName = '';
                }),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: Text(_imageFileName.isEmpty ? 'Remove image' : 'Remove'),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
              controller: _modelCtrl,
              decoration: const InputDecoration(labelText: "Model Name")),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: TextField(
                      controller: _serialCtrl,
                      decoration:
                          const InputDecoration(labelText: "Serial Number"))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: _wardCtrl,
                      decoration:
                          const InputDecoration(labelText: "Room/Ward"))),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: "Current Status"),
            items: ['OPERATIONAL', 'MAINTENANCE', 'OFFLINE', 'DECOMMISSIONED']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _status = v!),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: TextField(
                      controller: _svcCtrl,
                      decoration:
                          const InputDecoration(labelText: "Last Service"))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: _intCtrl,
                      decoration:
                          const InputDecoration(labelText: "Interval"))),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final asset = HospitalAsset(
                  id: widget.existingAsset?.id,
                  assetType: widget.assetType,
                  modelName: _modelCtrl.text,
                  serialNumber: _serialCtrl.text,
                  hospitalUnit: widget.department.toUpperCase(),
                  wardLocation: _wardCtrl.text,
                  status: _status,
                  dateAcquired:
                      widget.existingAsset?.dateAcquired ?? '2024-01-01',
                  lastServiceDate: _svcCtrl.text,
                  serviceInterval: _intCtrl.text,
                  notes: '',
                  imageFileName: _imageFileName,
                  imageBytes: _imageBytes,
                );
                if (widget.existingAsset == null) {
                  await AssetService.instance.registerAsset(asset);
                } else {
                  await AssetService.instance.updateAsset(asset);
                }
                widget.onComplete();
              },
              child: const Text("Save Changes"),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

