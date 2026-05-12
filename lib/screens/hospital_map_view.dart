import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/utils/animation_helper.dart';
import 'package:ma_1/models/hospital_asset.dart';
import 'package:ma_1/services/asset_service.dart';

class HospitalMapView extends StatefulWidget {
  const HospitalMapView({super.key});

  @override
  State<HospitalMapView> createState() => _HospitalMapViewState();
}

class _HospitalMapViewState extends State<HospitalMapView> with SingleTickerProviderStateMixin {
  late AnimationController _radarCtrl;
  String? _lockedTarget;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    super.dispose();
  }

  void _openAssetRegistry(String unit) {
    setState(() => _lockedTarget = unit);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssetRegistryPanel(hospitalUnit: unit),
    ).whenComplete(() => setState(() => _lockedTarget = null));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          color: AppTheme.bgLight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("AERIAL ASSET TRACKER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Orbitron', letterSpacing: 2)),
              Icon(Icons.satellite_alt, color: AppTheme.primary.withOpacity(0.5)),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              // Custom Aerial Painter
              AnimatedBuilder(
                animation: _radarCtrl,
                builder: (context, child) => CustomPaint(
                  painter: AerialMapPainter(animationValue: _radarCtrl.value),
                  size: Size.infinite,
                ),
              ),

              // Interactive Zones & Badges
              _buildBuildingZone("PAEDIATRIC", 0.1, 0.1, 0.35, 0.25),
              _buildBuildingZone("MATERNITY", 0.55, 0.1, 0.35, 0.3),
              _buildBuildingZone("MAIN", 0.25, 0.5, 0.5, 0.4),

              // HUD Target Lock Overlay
              if (_lockedTarget != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(color: AppTheme.primary.withOpacity(0.05))
                        .animate().fadeIn().custom(builder: (ctx, val, child) => const HudBrackets(child: SizedBox.expand())),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBuildingZone(String unit, double leftPct, double topPct, double widthPct, double heightPct) {
    return Positioned(
      left: MediaQuery.of(context).size.width * leftPct,
      top: MediaQuery.of(context).size.height * 0.7 * topPct, // Approx height constraint
      width: MediaQuery.of(context).size.width * widthPct,
      height: MediaQuery.of(context).size.height * 0.7 * heightPct,
      child: GestureDetector(
        onTap: () => _openAssetRegistry(unit),
        child: FutureBuilder<List<HospitalAsset>>(
          future: AssetService.instance.getAssetsByUnit(unit),
          builder: (context, snapshot) {
            int vents = 0, anaes = 0;
            Color statusColor = AppTheme.accent; // Default Green

            if (snapshot.hasData) {
              for (var a in snapshot.data!) {
                if (a.assetType == 'ventilator') {
                  vents++;
                } else {
                  anaes++;
                }
                
                if (a.status == 'OFFLINE') {
                  statusColor = AppTheme.error;
                } else if (a.status == 'MAINTENANCE' && statusColor != AppTheme.error) statusColor = AppTheme.warning;
              }
            }

            return Container(
              color: Colors.transparent, // Keeps tap area active
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(unit, style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, fontSize: 12, shadows: [Shadow(color: AppTheme.primary, blurRadius: 10)])),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.bgDark.withOpacity(0.8), border: Border.all(color: statusColor), boxShadow: [BoxShadow(color: statusColor.withOpacity(0.3), blurRadius: 5)]),
                      child: Text("VENTS: $vents | ANAES: $anaes", style: TextStyle(color: statusColor, fontSize: 9, fontFamily: 'Share Tech Mono', fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}

// --- CUSTOM PAINTER: AERIAL BLUEPRINT ---
class AerialMapPainter extends CustomPainter {
  final double animationValue;
  AerialMapPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppTheme.bgDark;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw grid background
    final gridPaint = Paint()..color = Colors.white.withOpacity(0.02)..style = PaintingStyle.stroke..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Glowing Pathways
    final pathPaint = Paint()
      ..color = AppTheme.primary.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
    
    Path roads = Path()
      ..moveTo(size.width * 0.25, size.height * 0.35)
      ..lineTo(size.width * 0.5, size.height * 0.35)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(size.width * 0.7, size.height * 0.4);
    canvas.drawPath(roads, pathPaint);

    // Moving Dots on Pathways
    final dotPaint = Paint()..color = AppTheme.primary..style = PaintingStyle.fill..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    double dotProg = animationValue * size.width;
    canvas.drawCircle(Offset(math.max(size.width * 0.25, dotProg % (size.width * 0.5)), size.height * 0.35), 3, dotPaint);

    // Building Specs
    final buildingFill = Paint()..color = const Color(0xFF0A1628)..style = PaintingStyle.fill;
    final buildingStroke = Paint()..color = AppTheme.primary.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 2;

    void drawBuilding(Rect rect) {
      canvas.drawRect(rect, buildingFill);
      canvas.drawRect(rect, buildingStroke);
      // Blueprint inner lines
      canvas.drawLine(Offset(rect.left + 10, rect.top + 10), Offset(rect.right - 10, rect.bottom - 10), Paint()..color=AppTheme.primary.withOpacity(0.1));
    }

    drawBuilding(Rect.fromLTWH(size.width * 0.1, size.height * 0.1, size.width * 0.35, size.height * 0.25)); // Paeds
    drawBuilding(Rect.fromLTWH(size.width * 0.55, size.height * 0.1, size.width * 0.35, size.height * 0.3)); // Maternity
    drawBuilding(Rect.fromLTWH(size.width * 0.25, size.height * 0.5, size.width * 0.5, size.height * 0.4)); // Main

    // Radar Pulse at Center
    final pulsePaint = Paint()..color = AppTheme.primary.withOpacity((1.0 - animationValue) * 0.2)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.45), animationValue * 150, pulsePaint);

    // Compass
    _drawCompass(canvas, size);
  }

  void _drawCompass(Canvas canvas, Size size) {
    Paint cPaint = Paint()..color = AppTheme.accent.withOpacity(0.5)..style = PaintingStyle.stroke;
    Offset cCenter = Offset(size.width - 40, size.height - 40);
    canvas.drawCircle(cCenter, 20, cPaint);
    canvas.drawLine(Offset(cCenter.dx, cCenter.dy - 25), Offset(cCenter.dx, cCenter.dy + 25), cPaint);
    canvas.drawLine(Offset(cCenter.dx - 25, cCenter.dy), Offset(cCenter.dx + 25, cCenter.dy), cPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- ASSET REGISTRY PANEL ---
class _AssetRegistryPanel extends StatefulWidget {
  final String hospitalUnit;
  const _AssetRegistryPanel({required this.hospitalUnit});

  @override
  State<_AssetRegistryPanel> createState() => _AssetRegistryPanelState();
}

class _AssetRegistryPanelState extends State<_AssetRegistryPanel> {
  int _tabIndex = 0;

  void _showAddAssetForm(BuildContext context, [HospitalAsset? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgDark,
      builder: (ctx) => _AssetEntryForm(
        hospitalUnit: widget.hospitalUnit, 
        assetType: _tabIndex == 0 ? 'ventilator' : 'anaesthetic_machine',
        existingAsset: existing,
        onComplete: () { Navigator.pop(ctx); setState((){}); } // Refresh list
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: AppTheme.bgDark, border: Border(top: BorderSide(color: AppTheme.primary, width: 2))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20), color: AppTheme.bgLight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text("${widget.hospitalUnit} — ASSET MANIFEST", style: const TextStyle(color: AppTheme.primary, fontSize: 18, fontFamily: 'Orbitron', fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(child: _buildHudTab("VENTILATORS", 0)),
              Expanded(child: _buildHudTab("ANAESTHETIC MACHINES", 1)),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<HospitalAsset>>(
              future: AssetService.instance.getAssetsByUnit(widget.hospitalUnit),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                final assets = snapshot.data!.where((a) => a.assetType == (_tabIndex == 0 ? 'ventilator' : 'anaesthetic_machine')).toList();

                if (assets.isEmpty) return const Center(child: Text("NO ASSETS FOUND IN REGISTRY.", style: TextStyle(color: AppTheme.textGrey, fontFamily: 'Share Tech Mono')));

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: assets.length,
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    Color statColor = asset.status == 'OPERATIONAL' ? AppTheme.accent : (asset.status == 'MAINTENANCE' ? AppTheme.warning : AppTheme.error);

                    return GestureDetector(
                      onTap: () => _showAddAssetForm(context, asset),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(15),
                        decoration: AppTheme.hudDecoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(asset.modelName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(asset.status, style: TextStyle(color: statColor, fontWeight: FontWeight.bold, fontFamily: 'Orbitron', fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text("TAG: ${asset.serialNumber} | LOC: ${asset.wardLocation}", style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                            const Divider(color: Colors.white10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("LAST SVC: ${asset.lastServiceDate}", style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                                Text("INTVL: ${asset.serviceInterval}", style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  }
                );
              }
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: GestureDetector(
              onTap: () => _showAddAssetForm(context),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), border: Border.all(color: AppTheme.primary)),
                child: const Text("ADD ASSET", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontFamily: 'Orbitron', letterSpacing: 2)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHudTab(String title, int index) {
    bool isSel = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSel ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          border: Border(bottom: BorderSide(color: isSel ? AppTheme.primary : Colors.white10, width: 3)),
        ),
        child: Text(title, textAlign: TextAlign.center, style: TextStyle(color: isSel ? AppTheme.primary : AppTheme.textGrey, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
      ),
    );
  }
}

// --- TERMINAL FORM FOR ADDING/EDITING ---
class _AssetEntryForm extends StatefulWidget {
  final String hospitalUnit;
  final String assetType;
  final HospitalAsset? existingAsset;
  final VoidCallback onComplete;

  const _AssetEntryForm({required this.hospitalUnit, required this.assetType, this.existingAsset, required this.onComplete});

  @override
  State<_AssetEntryForm> createState() => _AssetEntryFormState();
}

class _AssetEntryFormState extends State<_AssetEntryForm> {
  late TextEditingController _modelCtrl, _serialCtrl, _wardCtrl, _acqCtrl, _svcCtrl, _intCtrl, _noteCtrl;
  String _status = 'OPERATIONAL';

  @override
  void initState() {
    super.initState();
    _modelCtrl = TextEditingController(text: widget.existingAsset?.modelName ?? '');
    _serialCtrl = TextEditingController(text: widget.existingAsset?.serialNumber ?? '');
    _wardCtrl = TextEditingController(text: widget.existingAsset?.wardLocation ?? '');
    _acqCtrl = TextEditingController(text: widget.existingAsset?.dateAcquired ?? '2024-01-01');
    _svcCtrl = TextEditingController(text: widget.existingAsset?.lastServiceDate ?? '2024-01-01');
    _intCtrl = TextEditingController(text: widget.existingAsset?.serviceInterval ?? '6 MONTHS');
    _noteCtrl = TextEditingController(text: widget.existingAsset?.notes ?? '');
    if (widget.existingAsset != null) _status = widget.existingAsset!.status;
  }

  void _submit() async {
    final asset = HospitalAsset(
      id: widget.existingAsset?.id,
      assetType: widget.assetType,
      modelName: _modelCtrl.text,
      serialNumber: _serialCtrl.text,
      hospitalUnit: widget.hospitalUnit,
      wardLocation: _wardCtrl.text,
      status: _status,
      dateAcquired: _acqCtrl.text,
      lastServiceDate: _svcCtrl.text,
      serviceInterval: _intCtrl.text,
      notes: _noteCtrl.text,
    );

    if (widget.existingAsset == null) {
      await AssetService.instance.registerAsset(asset);
    } else {
      await AssetService.instance.updateAsset(asset);
    }
    
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existingAsset == null ? "REGISTER NEW ASSET" : "UPDATE ASSET", style: const TextStyle(color: AppTheme.primary, fontSize: 18, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildInput("MODEL NAME", _modelCtrl),
          Row(children: [Expanded(child: _buildInput("SERIAL / TAG", _serialCtrl)), const SizedBox(width: 10), Expanded(child: _buildInput("WARD / LOC", _wardCtrl))]),
          
          // Custom Dropdown
          const Text("> STATUS", style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _status, dropdownColor: AppTheme.bgLight, isExpanded: true,
                style: const TextStyle(color: Colors.white, fontFamily: 'Share Tech Mono'),
                items: ['OPERATIONAL', 'MAINTENANCE', 'OFFLINE', 'DECOMMISSIONED'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
            ),
          ),
          const SizedBox(height: 15),

          Row(children: [Expanded(child: _buildInput("LAST SERVICE", _svcCtrl)), const SizedBox(width: 10), Expanded(child: _buildInput("INTERVAL", _intCtrl))]),
          _buildInput("NOTES", _noteCtrl),
          
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _submit,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), border: Border.all(color: AppTheme.primary)),
              child: const Text("TRANSMIT REGISTRATION", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("> $label", style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
            child: TextField(controller: ctrl, style: const TextStyle(color: Colors.white, fontFamily: 'Share Tech Mono'), decoration: const InputDecoration(border: InputBorder.none, isDense: true)),
          ),
        ],
      ),
    );
  }
}