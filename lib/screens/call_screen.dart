import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class CallScreen extends StatefulWidget {
  final String contactName;
  final String? phoneNumber;
  final bool isVideoCall;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.contactName,
    this.phoneNumber,
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
  bool _isSpeakerOn = true;
  Timer? _timer;
  int _elapsedSeconds = 0;
  String? _dialerMessage;

  @override
  void initState() {
    super.initState();
    if (!widget.isIncoming && !widget.isVideoCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _placePhoneCall());
    } else if (!widget.isIncoming) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _connectCall();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _placePhoneCall() async {
    final phone = widget.phoneNumber?.trim() ?? '';
    if (phone.isEmpty) {
      setState(() {
        _dialerMessage = 'No phone number is saved for this contact.';
      });
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!mounted) return;
    setState(() {
      _dialerMessage = launched
          ? 'Opening device dialer for $phone'
          : 'Could not open the dialer. Number: $phone';
    });
    if (launched) {
      _connectCall();
    }
  }

  void _connectCall() {
    setState(() => _isConnected = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  String _formatElapsed() {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
            Container(
              color: const Color(0xFF0F172A),
              child: Center(
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.iceBlue.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.white24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.contactName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 54,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

          // PIP LOCAL CAMERA
          if (widget.isVideoCall && _isConnected && _isCameraOn)
            Positioned(
              top: 60,
              right: 20,
              child: Container(
                width: 92,
                height: 132,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: const Center(
                    child:
                        Icon(Icons.person_4_outlined, color: Colors.white24)),
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
                      child: Text(widget.contactName.substring(0, 1),
                          style: const TextStyle(
                              fontSize: 42,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter'))),
                  const SizedBox(height: 24),
                  Text(widget.contactName,
                      style: TextStyle(
                          color: widget.isVideoCall
                              ? Colors.white
                              : AppTheme.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter')),
                  const SizedBox(height: 8),
                  if ((widget.phoneNumber ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        widget.phoneNumber!,
                        style: TextStyle(
                          color: widget.isVideoCall
                              ? Colors.white70
                              : AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),

                  // Status Text
                  if (widget.isIncoming && !_isConnected)
                    Text(
                        "Incoming ${widget.isVideoCall ? 'Video' : 'Voice'} Call",
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 15))
                  else if (!_isConnected)
                    const Text("Connecting to Technician...",
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 15))
                  else
                    // Call Timer using Roboto Mono for data precision
                    Text(
                      _formatElapsed(),
                      style: GoogleFonts.robotoMono(
                        color: widget.isVideoCall
                            ? Colors.white70
                            : AppTheme.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (_dialerMessage != null) ...[
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        _dialerMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: widget.isVideoCall
                              ? Colors.white70
                              : AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
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
                gradient: widget.isVideoCall
                    ? LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.transparent
                        ],
                      )
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (widget.isIncoming && !_isConnected) ...[
                    _buildCallButton(Icons.call_end_rounded, AppTheme.error,
                        "Decline", () => Navigator.pop(context)),
                    _buildCallButton(Icons.call_rounded, AppTheme.success,
                        "Accept", _connectCall),
                  ] else ...[
                    // Mute Toggle
                    _buildCallButton(
                        _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        widget.isVideoCall
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.white,
                        "Mute",
                        () => setState(() => _isMuted = !_isMuted),
                        iconColor: widget.isVideoCall
                            ? Colors.white
                            : AppTheme.textPrimary),
                    // Video Toggle (Only for Video Calls)
                    if (widget.isVideoCall)
                      _buildCallButton(
                          _isCameraOn
                              ? Icons.video_camera_front_outlined
                              : Icons.videocam_off_rounded,
                          Colors.white.withValues(alpha: 0.2),
                          "Camera",
                          () => setState(() => _isCameraOn = !_isCameraOn)),
                    // Speaker Toggle
                    _buildCallButton(
                      _isSpeakerOn
                          ? Icons.spatial_audio_off_rounded
                          : Icons.volume_off_rounded,
                      widget.isVideoCall
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white,
                      "Speaker",
                      () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                      iconColor: widget.isVideoCall
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                    // End Call
                    _buildCallButton(Icons.call_end_rounded, AppTheme.error,
                        "End", () => Navigator.pop(context)),
                  ],
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCallButton(
      IconData icon, Color bgColor, String label, VoidCallback onTap,
      {Color iconColor = Colors.white}) {
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
              boxShadow: bgColor == Colors.white
                  ? [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10)
                    ]
                  : null,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
        ).animate().scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1, 1),
            duration: 200.ms),
        const SizedBox(height: 10),
        Text(label,
            style: TextStyle(
                color: widget.isVideoCall
                    ? Colors.white70
                    : AppTheme.textSecondary,
                fontSize: 12,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
