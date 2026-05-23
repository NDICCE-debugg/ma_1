import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
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
      // Simulate professional connection delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isConnected = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Medical apps use clean backgrounds for audio, dark/focused for video
    return Scaffold(
      backgroundColor: widget.isVideoCall ? Colors.black : AppTheme.background,
      body: Stack(
        children: [
          // VIDEO FEED AREA
          if (widget.isVideoCall && _isConnected)
            Container(color: const Color(0xFF0F172A)), // Placeholder for Remote View
            
          // PIP LOCAL CAMERA
          if (widget.isVideoCall && _isConnected && _isCameraOn)
            Positioned(
              top: 60, right: 20,
              child: Container(
                width: 90, height: 130,
                decoration: BoxDecoration(
                  color: Colors.black, 
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1)
                ),
                child: const Center(child: Icon(Icons.person, color: Colors.white24)),
              ),
            ),

          // AUDIO CALL BACKGROUND (Medical Gradient)
          if (!widget.isVideoCall)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, AppTheme.background],
                ),
              ),
              child: SizedBox.expand(),
            ),

          // MAIN CALL INFO
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Profile Avatar - Clean and non-pulsing
                  CircleAvatar(
                    radius: 54, 
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      widget.contactName.substring(0, 1), 
                      style: const TextStyle(fontSize: 42, color: AppTheme.primary, fontWeight: FontWeight.bold, fontFamily: 'Inter')
                    )
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.contactName, 
                    style: TextStyle(
                      color: widget.isVideoCall ? Colors.white : AppTheme.textPrimary, 
                      fontSize: 26, 
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter'
                    )
                  ),
                  const SizedBox(height: 8),
                  
                  // Status Text
                  if (widget.isIncoming && !_isConnected)
                    Text("Incoming ${widget.isVideoCall ? 'Video' : 'Voice'} Call", 
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15))
                  else if (!_isConnected)
                    const Text("Connecting to Technician...", 
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 15))
                  else
                    // Call Timer using Roboto Mono for data precision
                    Text("00:14", 
                      style: GoogleFonts.robotoMono(
                        color: widget.isVideoCall ? Colors.white70 : AppTheme.primary, 
                        fontSize: 18, 
                        fontWeight: FontWeight.w500
                      )),
                ],
              ),
            ),
          ),

          // PROFESSIONAL CONTROL BAR
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.only(bottom: 50, top: 20),
              decoration: BoxDecoration(
                gradient: widget.isVideoCall ? LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                ) : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (widget.isIncoming && !_isConnected) ...[
                    _buildCallButton(Icons.close, AppTheme.error, "Decline", () => Navigator.pop(context)),
                    _buildCallButton(Icons.check, AppTheme.success, "Accept", () => setState(() => _isConnected = true)),
                  ] else ...[
                    // Mute Toggle
                    _buildCallButton(
                      _isMuted ? Icons.mic_off : Icons.mic_none, 
                      widget.isVideoCall ? Colors.white.withValues(alpha: 0.2) : Colors.white, 
                      "Mute", 
                      () => setState(() => _isMuted = !_isMuted),
                      iconColor: widget.isVideoCall ? Colors.white : AppTheme.textPrimary
                    ),
                    // Video Toggle (Only for Video Calls)
                    if (widget.isVideoCall)
                      _buildCallButton(
                        _isCameraOn ? Icons.videocam_outlined : Icons.videocam_off_outlined, 
                        Colors.white.withValues(alpha: 0.2), 
                        "Camera", 
                        () => setState(() => _isCameraOn = !_isCameraOn)
                      ),
                    // Speaker Toggle
                    _buildCallButton(
                      Icons.volume_up_outlined, 
                      widget.isVideoCall ? Colors.white.withValues(alpha: 0.2) : Colors.white, 
                      "Speaker", 
                      () {},
                      iconColor: widget.isVideoCall ? Colors.white : AppTheme.textPrimary
                    ),
                    // End Call
                    _buildCallButton(Icons.call_end, AppTheme.error, "End", () => Navigator.pop(context)),
                  ],
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCallButton(IconData icon, Color bgColor, String label, VoidCallback onTap, {Color iconColor = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              color: bgColor,
              boxShadow: bgColor == Colors.white ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)] : null,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
        ).animate().scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 200.ms),
        const SizedBox(height: 10),
        Text(
          label, 
          style: TextStyle(
            color: widget.isVideoCall ? Colors.white70 : AppTheme.textSecondary, 
            fontSize: 12, 
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500
          )
        ),
      ],
    );
  }
}