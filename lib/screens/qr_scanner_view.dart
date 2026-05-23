import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/sound_service.dart';
import 'package:ma_1/screens/asset_detail_view.dart';

class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key});

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  bool _isProcessing = false;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        try {
          final Map<String, dynamic> data = jsonDecode(barcode.rawValue!);
          
          if (data.containsKey('asset_id') || data.containsKey('id')) {
            setState(() => _isProcessing = true);
            
            // Professional confirmation sound
            try { SoundService.instance.playSuccess(); } catch (e) {}
            
            _scannerController.stop();

            // Minimal delay to allow the user to see the "Identified" state
            await Future.delayed(const Duration(milliseconds: 300));

            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => AssetDetailView(assetData: data)),
            );
            break;
          }
        } catch (e) {
          // Ignore invalid codes silently or show a subtle non-intrusive hint
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Camera requires black backdrop
      body: Stack(
        children: [
          // 1. THE CAMERA FEED
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          
          // 2. PROFESSIONAL MEDICAL OVERLAY (The Mask)
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6), 
              BlendMode.srcOut
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black, 
                    backgroundBlendMode: BlendMode.dstOut
                  ),
                ),
                Center(
                  child: Container(
                    height: 240,
                    width: 240,
                    decoration: BoxDecoration(
                      color: Colors.red, // This color is cleared by the BlendMode
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. SCANNER FRAME & GUIDES
          Center(
            child: Container(
              height: 240,
              width: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24, width: 1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Corner Guides in Medical Blue
                  _buildCorner(top: true, left: true),
                  _buildCorner(top: true, right: true),
                  _buildCorner(bottom: true, left: true),
                  _buildCorner(bottom: true, right: true),
                  
                  // Subtle Medical Pulse Line (replaces the red scanline)
                  const _ScanningPulseLine(),
                ],
              ),
            ),
          ),

          // 4. UI CONTROLS & TEXT
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        "Identify Equipment",
                        style: TextStyle(
                          color: Colors.white, 
                          fontFamily: 'Inter', 
                          fontSize: 18, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off, 
                          color: Colors.white
                        ),
                        onPressed: () {
                          setState(() => _isFlashOn = !_isFlashOn);
                          _scannerController.toggleTorch();
                        },
                      ),
                    ],
                  ),
                ),

                // Center Feedback
                if (_isProcessing)
                  Container(
                    margin: const EdgeInsets.only(bottom: 100),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, 
                            color: Colors.white
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Equipment Identified",
                          style: TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold, 
                            fontFamily: 'Inter'
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().scale(),

                // Bottom Instructions
                const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Text(
                    "Center the QR code on the equipment tag",
                    style: TextStyle(
                      color: Colors.white70, 
                      fontFamily: 'Inter', 
                      fontSize: 14
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner({bool top = false, bool bottom = false, bool left = false, bool right = false}) {
    return Positioned(
      top: top ? -2 : null,
      bottom: bottom ? -2 : null,
      left: left ? -2 : null,
      right: right ? -2 : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: top ? const BorderSide(color: AppTheme.primary, width: 4) : BorderSide.none,
            bottom: bottom ? const BorderSide(color: AppTheme.primary, width: 4) : BorderSide.none,
            left: left ? const BorderSide(color: AppTheme.primary, width: 4) : BorderSide.none,
            right: right ? const BorderSide(color: AppTheme.primary, width: 4) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(top && left ? 12 : 0),
            topRight: Radius.circular(top && right ? 12 : 0),
            bottomLeft: Radius.circular(bottom && left ? 12 : 0),
            bottomRight: Radius.circular(bottom && right ? 12 : 0),
          ),
        ),
      ),
    );
  }
}

class _ScanningPulseLine extends StatefulWidget {
  const _ScanningPulseLine();

  @override
  State<_ScanningPulseLine> createState() => _ScanningPulseLineState();
}

class _ScanningPulseLineState extends State<_ScanningPulseLine> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Positioned(
          top: _ctrl.value * 230,
          left: 10,
          right: 10,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(0),
                  AppTheme.primary.withOpacity(0.5),
                  AppTheme.primary.withOpacity(0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}