import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';

class CallScreen extends StatefulWidget {
  final String contactName;
  final bool isVideoCall;
  final bool isIncoming;

  const CallScreen({
    super.key, 
    required this.contactName, 
    required this.isVideoCall,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isCameraOn = true;

  @override
  void initState() {
    super.initState();
    if (!widget.isIncoming) {
      // Simulate connection delay for UI
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isConnected = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // VIDEO FEED PLACEHOLDER (Agora Remote View goes here)
          if (widget.isVideoCall && _isConnected)
            Container(color: const Color(0xFF1A1A2E)), 
            
          // PIP LOCAL CAMERA (Agora Local View goes here)
          if (widget.isVideoCall && _isConnected && _isCameraOn)
            Positioned(
              bottom: 120, right: 20,
              child: Container(
                width: 100, height: 150,
                decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.primary, width: 2)),
                child: const Center(child: Text("You", style: TextStyle(color: Colors.white, fontSize: 10))),
              ),
            ),

          // INCOMING / CONNECTING UI
          if (widget.isIncoming || !_isConnected)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(radius: 50, backgroundColor: AppTheme.primary.withOpacity(0.2), child: Text(widget.contactName.substring(0, 1), style: const TextStyle(fontSize: 40, color: AppTheme.primary, fontFamily: 'Orbitron'))).animate(onPlay: (c) => c.repeat(reverse: true)).scale(end: const Offset(1.1, 1.1)),
                  const SizedBox(height: 30),
                  Text(widget.contactName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(widget.isIncoming ? "Incoming ${widget.isVideoCall ? 'video' : 'voice'} call" : "Connecting...", style: const TextStyle(color: AppTheme.textGrey, fontSize: 16)),
                ],
              ),
            ),

          // ACTIVE AUDIO UI
          if (!widget.isVideoCall && _isConnected)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(radius: 60, backgroundColor: AppTheme.primary.withOpacity(0.1), child: Text(widget.contactName.substring(0, 1), style: const TextStyle(fontSize: 50, color: AppTheme.primary, fontFamily: 'Orbitron'))),
                  const SizedBox(height: 30),
                  Text(widget.contactName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text("00:14", style: TextStyle(color: AppTheme.primary, fontSize: 18, fontFamily: 'Share Tech Mono')), // Timer logic
                ],
              ),
            ),

          // BOTTOM CONTROLS
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.only(bottom: 40, top: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent]),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (widget.isIncoming) ...[
                    _buildButton(Icons.call_end, Colors.red, "Decline", () => Navigator.pop(context)),
                    _buildButton(Icons.call, AppTheme.success, "Accept", () => setState(() => _isConnected = true)),
                  ] else ...[
                    if (widget.isVideoCall) _buildButton(_isCameraOn ? Icons.videocam : Icons.videocam_off, Colors.white24, "Video", () => setState(() => _isCameraOn = !_isCameraOn)),
                    _buildButton(_isMuted ? Icons.mic_off : Icons.mic, Colors.white24, "Mute", () => setState(() => _isMuted = !_isMuted)),
                    _buildButton(Icons.volume_up, Colors.white24, "Speaker", () {}),
                    _buildButton(Icons.call_end, Colors.red, "End", () => Navigator.pop(context)),
                  ],
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildButton(IconData icon, Color bgColor, String label, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}