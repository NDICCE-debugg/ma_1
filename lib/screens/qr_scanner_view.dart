import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/utils/animation_helper.dart';
import 'package:ma_1/services/sound_service.dart';
import 'package:ma_1/screens/asset_detail_view.dart';

class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key});

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _scanlineCtrl;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
    _scanlineCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _scanlineCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        try {
          // Expecting JSON: {"asset_id": 1, "model_name": "Aeonmed VG70", ...}
          final Map<String, dynamic> data = jsonDecode(barcode.rawValue!);
          
          if (data.containsKey('asset_id')) {
            setState(() => _isProcessing = true);
            SoundService.instance.playSuccess();
            _scannerController.stop();

            // Simulate lock-on delay for HUD effect
            await Future.delayed(const Duration(milliseconds: 800));

            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => AssetDetailView(assetData: data)),
            );
            break;
          }
        } catch (e) {
          // Not a valid asset JSON, ignore or show error
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          
          // HUD OVERLAY
          ColorFiltered(
            colorFilter: ColorFilter.mode(AppTheme.bgDark.withOpacity(0.8), BlendMode.srcOut),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut),
                ),
                Center(
                  child: Container(
                    height: 250,
                    width: 250,
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          // SCANNER GRAPHICS
          Center(
            child: SizedBox(
              height: 250,
              width: 250,
              child: Stack(
                children: [
                  HudBrackets(child: Container()),
                  
                  // Animated Scanline
                  AnimatedBuilder(
                    animation: _scanlineCtrl,
                    builder: (context, child) {
                      return Positioned(
                        top: _scanlineCtrl.value * 240,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.transparent, AppTheme.error, AppTheme.primary, Colors.transparent]),
                            boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.5), blurRadius: 10)],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.98, 0.98), end: const Offset(1.02, 1.02), duration: 1.seconds),
          ),

          // UI TEXT & BUTTONS
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.primary), onPressed: () => Navigator.pop(context)),
                      const Text("TARGET ACQUISITION", style: TextStyle(color: AppTheme.primary, fontFamily: 'Orbitron', fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ],
                  ),
                ),
                if (_isProcessing)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    color: AppTheme.accent.withOpacity(0.2),
                    child: const GlitchText("ASSET IDENTIFIED. SECURING DATA...", style: TextStyle(color: AppTheme.accent, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Text("ALIGN ASSET CODE WITH SCANNER", style: TextStyle(color: AppTheme.textGrey, fontFamily: 'Share Tech Mono', letterSpacing: 2)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}