import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:ma_1/services/chat_service.dart';

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

  // Speech-to-Text & Text-to-Speech components
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _listeningText = '';
  bool _isGeneratingResponse = false;
  String? _captions;

  @override
  void initState() {
    super.initState();
    _initSpeechAndAudio();

    if (widget.isIncoming) {
      // Ring first, wait for user acceptance
    } else {
      // Outgoing call - automatically connect in 1.5 seconds for immersive app simulation
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _connectCall();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  void _initSpeechAndAudio() async {
    _tts = FlutterTts();
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.05);
    await _tts.setSpeechRate(0.45);

    _speech = stt.SpeechToText();
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      _speechAvailable = false;
    }
  }

  String _getContactId() {
    final name = widget.contactName.toLowerCase();
    if (name.contains('chipo')) return 'dr-chipo-moyo';
    if (name.contains('farai')) return 'farai-gumbo';
    if (name.contains('tendai')) return 'tendai-chidi';
    if (name.contains('sekai')) return 'dr-sekai-nzenza';
    if (name.contains('rufaro')) return 'rufaro-moyo';
    if (name.contains('kuda')) return 'kudakwashe-hove';
    return '';
  }

  String _getGreeting() {
    final contactId = _getContactId();
    switch (contactId) {
      case 'dr-chipo-moyo':
        return "Hello colleague. We have a low oxygen alarm on the Bed 2 Aeonmed ventilator. What is its current pressure reading?";
      case 'farai-gumbo':
        return "Hey colleague. I finished calibrating the Evita PEEP valve assembly. Let me know if you need to run the diagnostic checklists.";
      case 'tendai-chidi':
        return "Emergency alert, colleague. The central oxygen plant pipeline pressure is dropping below 4.2 bar. Confirm we are on reserve banks!";
      case 'dr-sekai-nzenza':
        return "Good day, colleague. I am preparing the ICU technical capacity review. Are all ventilators fully compliant with the safety audit?";
      case 'rufaro-moyo':
        return "Hello. I am compiling the department spare parts list. Do we have the replacement turbines ready on Shelf B2?";
      case 'kudakwashe-hove':
        return "Hi colleague. The blood gas analyzer pH reading is drifting in the laboratory. Did you bring the calibration buffers?";
      default:
        return "Hello. This is clinical support, how can I help you coordinate today?";
    }
  }

  List<String> _getQuickReplies() {
    final contactId = _getContactId();
    switch (contactId) {
      case 'dr-chipo-moyo':
        return [
          "O2 cell reads 88% and pressure is 3.1 bar.",
          "Switching to oxygen cylinder reserve banks.",
          "Can you check Bed 2 log history?"
        ];
      case 'farai-gumbo':
        return [
          "Calibrated, but leakage test is borderline.",
          "Do we have spare turbines on Shelf B2?",
          "Can you help with the electrical safety run?"
        ];
      case 'tendai-chidi':
        return [
          "Manifold pressure dropped below 4.2 bar!",
          "Confirming compressor operating temperature.",
          "Checking the primary regulator valve."
        ];
      case 'dr-sekai-nzenza':
        return [
          "ICU ventilator audit is completed.",
          "High pressure alarm is resolved.",
          "Service logs are uploaded."
        ];
      case 'rufaro-moyo':
        return [
          "Turbine inventory is restocked on Shelf B2.",
          "Awaiting purchase request approval.",
          "Drafting technical compliance sheet."
        ];
      case 'kudakwashe-hove':
        return [
          "Bringing pH reference buffers to the lab.",
          "Ready to run verification check.",
          "Reagent levels are confirmed."
        ];
      default:
        return [
          "Technical service is complete.",
          "Machine is ready for patient use.",
          "Awaiting technical approval."
        ];
    }
  }

  void _connectCall() {
    final greeting = _getGreeting();
    setState(() {
      _isConnected = true;
      _captions = "${widget.contactName}: $greeting";
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    // Speak greeting!
    _tts.speak(greeting);
  }

  void _onUserResponse(String text) async {
    if (_isGeneratingResponse || text.isEmpty) return;
    _tts.stop();
    setState(() {
      _captions = "You: $text";
      _isGeneratingResponse = true;
    });

    final reply = await ChatService.instance.getSimulatedCallReply(
      contactId: _getContactId(),
      userSpeechText: text,
      callHistory: [],
    );

    if (!mounted) return;
    setState(() {
      _captions = "${widget.contactName}: $reply";
      _isGeneratingResponse = false;
    });

    // Speak response!
    await _tts.speak(reply);
  }

  void _toggleListening() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) {
      final init = await _speech.initialize();
      if (!init) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone access is not configured.")),
        );
        return;
      }
      _speechAvailable = true;
    }

    setState(() => _isListening = true);
    _speech.listen(
      onResult: (result) {
        setState(() {
          _listeningText = result.recognizedWords;
        });
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          setState(() => _isListening = false);
          _onUserResponse(result.recognizedWords);
        }
      },
    );
  }

  String _formatElapsed() {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isVideoCall ? Colors.black : AppTheme.background,
      body: Stack(
        children: [
          // VIDEO FEED FEEDBACK
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

          // GRADIENT BACKGROUND FOR AUDIO CALL
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

          // MAIN CALL DISPLAY INFO & CONTROLS
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Header Area
                CircleAvatar(
                  radius: 46,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    widget.contactName.substring(0, 1),
                    style: const TextStyle(
                        fontSize: 36,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.contactName,
                  style: TextStyle(
                      color: widget.isVideoCall ? Colors.white : AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter'),
                ),
                const SizedBox(height: 4),
                if ((widget.phoneNumber ?? '').isNotEmpty)
                  Text(
                    widget.phoneNumber!,
                    style: TextStyle(
                      color: widget.isVideoCall ? Colors.white70 : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 8),
                // Connection timer or status
                if (!_isConnected)
                  const Text("Connecting secure hospital line...",
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))
                else
                  Text(
                    _formatElapsed(),
                    style: GoogleFonts.robotoMono(
                      color: widget.isVideoCall ? Colors.white70 : AppTheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                const SizedBox(height: 20),

                // Live Captions & Triage Console
                if (_isConnected)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildCaptionsConsole(),
                          _buildQuickRepliesPanel(),
                        ],
                      ),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),

                // Interactive Audio / Voice controls & Quick Actions
                if (_isConnected) _buildVoiceInputIndicator(),

                // BOTTOM CALL CONTROL BAR
                _buildCallControlBar(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionsConsole() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.isVideoCall ? Colors.black54 : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: widget.isVideoCall ? Colors.white12 : AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.closed_caption_rounded,
                  color: widget.isVideoCall ? Colors.white70 : AppTheme.primary,
                  size: 18),
              const SizedBox(width: 8),
              Text(
                "LIVE CLINICAL CAPTIONS",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  fontFamily: 'Inter',
                  color: widget.isVideoCall ? Colors.white54 : AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              if (_isGeneratingResponse)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _captions ?? "Dialing...",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: widget.isVideoCall ? Colors.white : AppTheme.textPrimary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickRepliesPanel() {
    final replies = _getQuickReplies();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              "QUICK RESPONSE CHIPS",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: widget.isVideoCall ? Colors.white54 : AppTheme.textSecondary,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: replies.map((reply) {
              return ActionChip(
                backgroundColor: widget.isVideoCall
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white,
                side: BorderSide(
                    color: widget.isVideoCall ? Colors.white12 : AppTheme.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                label: Text(
                  reply,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.isVideoCall ? Colors.white.withValues(alpha: 0.9) : AppTheme.primaryDark,
                  ),
                ),
                onPressed: () => _onUserResponse(reply),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceInputIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          if (_isListening && _listeningText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                '"$_listeningText"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          GestureDetector(
            onTap: _toggleListening,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening
                    ? AppTheme.error.withValues(alpha: 0.15)
                    : AppTheme.primary.withValues(alpha: 0.1),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: _isListening ? AppTheme.error : AppTheme.primary,
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isListening ? "Listening... Tap to stop" : "Tap Mic to speak hands-free",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: widget.isVideoCall ? Colors.white70 : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallControlBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (widget.isIncoming && !_isConnected) ...[
          _buildCallButton(Icons.call_end_rounded, AppTheme.error, "Decline",
              () => Navigator.pop(context)),
          _buildCallButton(
              Icons.call_rounded, AppTheme.success, "Accept", _connectCall),
        ] else ...[
          // Secure mute toggle
          _buildCallButton(
            _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            widget.isVideoCall ? Colors.white12 : Colors.white,
            "Mute",
            () => setState(() => _isMuted = !_isMuted),
            iconColor: widget.isVideoCall ? Colors.white : AppTheme.textPrimary,
          ),
          // Camera video toggle
          if (widget.isVideoCall)
            _buildCallButton(
              _isCameraOn
                  ? Icons.video_camera_front_outlined
                  : Icons.videocam_off_rounded,
              Colors.white12,
              "Camera",
              () => setState(() => _isCameraOn = !_isCameraOn),
            ),
          // Speaker phone toggle
          _buildCallButton(
            _isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            widget.isVideoCall ? Colors.white12 : Colors.white,
            "Speaker",
            () => setState(() => _isSpeakerOn = !_isSpeakerOn),
            iconColor: widget.isVideoCall ? Colors.white : AppTheme.textPrimary,
          ),
          // End the call securely
          _buildCallButton(
            Icons.call_end_rounded,
            AppTheme.error,
            "End Call",
            () => Navigator.pop(context),
          ),
        ],
      ],
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              boxShadow: bgColor == Colors.white
                  ? [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]
                  : null,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
        ).animate().scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1, 1),
            duration: 150.ms),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
              color: widget.isVideoCall ? Colors.white70 : AppTheme.textSecondary,
              fontSize: 11,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

