import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:ma_1/models/ai_request.dart';
import 'package:ma_1/services/sound_service.dart';

class AIAssistantView extends StatefulWidget {
  const AIAssistantView({super.key});

  @override
  State<AIAssistantView> createState() => _AIAssistantViewState();
}

class _AIAssistantViewState extends State<AIAssistantView> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  
  List<AiRequest> _requests = [];
  bool _isProcessing = false;
  
  // Hardware Services
  late stt.SpeechToText _speech;
  bool _isListening = false;
  late FlutterTts _flutterTts;
  final ImagePicker _picker = ImagePicker();

  // UPDATED: Your specific local Wi-Fi IP Address
  static const String _pcIpAddress = "10.160.120.215"; 
  final String _apiUrl = "http://$_pcIpAddress:5000/api/query";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();
    _loadHistory();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(0.9);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _loadHistory() async {
    final reqs = await DatabaseHelper.instance.getAiRequests();
    setState(() => _requests = reqs);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });
    }
  }

  // --- REAL BACKEND CONNECTION LOGIC ---
  Future<void> _processUserRequest(String input, String type, {String? imagePath}) async {
    if (input.isEmpty && imagePath == null) return;
    try { SoundService.instance.playTransmit(); } catch(e) {}

    // 1. Save user's question locally
    final userReq = AiRequest(
      inputText: input.isEmpty ? "[IMAGE CAPTURED]" : input,
      inputType: type,
      imagePath: imagePath,
      timestamp: DateTime.now().toIso8601String(),
      status: "sent",
    );
    await DatabaseHelper.instance.addAiRequest(userReq);
    _textCtrl.clear();
    await _loadHistory();

    setState(() => _isProcessing = true);

    // 2. Transmit to Flask Server
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"query": input}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiAnswer = data['answer'] ?? "No response received.";

        // 3. Save actual AI response from Server
        final sysReq = AiRequest(
          inputText: aiAnswer,
          inputType: 'system',
          timestamp: DateTime.now().toIso8601String(),
          status: 'delivered',
        );
        await DatabaseHelper.instance.addAiRequest(sysReq);

        if (type == 'voice') await _flutterTts.speak(aiAnswer);

      } else {
        throw Exception("Server connection failed");
      }
    } catch (e) {
      // Handle actual connection errors
      final errReq = AiRequest(
        inputText: "ERROR: UPLINK FAILED. UNABLE TO REACH AI CORE. PLEASE CHECK SERVER STATUS. ($e)",
        inputType: 'system',
        timestamp: DateTime.now().toIso8601String(),
        status: 'error',
      );
      await DatabaseHelper.instance.addAiRequest(errReq);
    }

    setState(() => _isProcessing = false);
    await _loadHistory();
  }

  // --- Input Handlers ---
  void _submitText() => _processUserRequest(_textCtrl.text.trim(), 'text');

  void _listenVoice() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') setState(() => _isListening = false);
        },
      );
      if (available) {
        setState(() => _isListening = true);
        try { SoundService.instance.playButtonPress(); } catch(e) {}
        _speech.listen(onResult: (val) {
            if (val.finalResult) _processUserRequest(val.recognizedWords, 'voice');
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _captureImage() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        final directory = await getApplicationDocumentsDirectory();
        final String savedPath = '${directory.path}/${path.basename(photo.path)}';
        await File(photo.path).copy(savedPath);
        _processUserRequest("", 'image', imagePath: savedPath);
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.smart_toy, color: _isProcessing ? AppTheme.warning : AppTheme.primary),
              const SizedBox(width: 10),
              const Text("BERT AI DIAGNOSTICS", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Orbitron')),
            ],
          ),
        ),
        
        if (_isProcessing) const LinearProgressIndicator(color: AppTheme.accent, backgroundColor: AppTheme.bgDark),

        // Chat History
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            itemCount: _requests.length,
            itemBuilder: (context, index) {
              final req = _requests[index];
              if (req.inputType == 'system') {
                return _buildAssistantBubble(req);
              } else {
                return _buildUserBubble(req);
              }
            },
          ),
        ),

        // Input Bar
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.primary, width: 2)), color: AppTheme.bgLight),
          child: SafeArea(
            child: Row(
              children: [
                GestureDetector(onTap: _captureImage, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(border: Border.all(color: Colors.white24)), child: const Icon(Icons.camera_alt, color: AppTheme.primary, size: 20))),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _listenVoice,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _isListening ? AppTheme.error.withOpacity(0.3) : Colors.transparent, border: Border.all(color: _isListening ? AppTheme.error : Colors.white24)),
                    child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? AppTheme.error : AppTheme.primary, size: 20).animate(target: _isListening ? 1 : 0).shimmer(duration: 500.ms),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                    child: TextField(
                      controller: _textCtrl,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Share Tech Mono'),
                      decoration: const InputDecoration(hintText: "ENTER QUERY...", hintStyle: TextStyle(color: AppTheme.textGrey), border: InputBorder.none),
                      onSubmitted: (_) => _submitText(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isProcessing ? null : _submitText,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _isProcessing ? Colors.grey : AppTheme.primary.withOpacity(0.2), border: Border.all(color: AppTheme.primary)),
                    child: const Icon(Icons.send, color: AppTheme.primary, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserBubble(AiRequest req) {
    IconData typeIcon = Icons.terminal;
    if (req.inputType == 'voice') typeIcon = Icons.mic;
    if (req.inputType == 'image') typeIcon = Icons.image;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15, left: 40),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.15), border: Border.all(color: AppTheme.primary)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(typeIcon, size: 12, color: AppTheme.primary),
                const SizedBox(width: 5),
                Text(req.inputType.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontFamily: 'Share Tech Mono', fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 5),
            if (req.imagePath != null && File(req.imagePath!).existsSync())
              Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(border: Border.all(color: AppTheme.primary)), child: Image.file(File(req.imagePath!), height: 150, fit: BoxFit.cover)),
            Text(req.inputText, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 5),
            Text("[${DateFormat('HH:mm').format(DateTime.parse(req.timestamp))}]", style: const TextStyle(fontSize: 8, color: AppTheme.primary, fontFamily: 'Share Tech Mono')),
          ],
        ),
      ).animate().fadeIn().slideX(begin: 0.1),
    );
  }

  Widget _buildAssistantBubble(AiRequest req) {
    bool isError = req.status == 'error';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 25, right: 40),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.bgLight, border: Border.all(color: isError ? AppTheme.error : AppTheme.primary.withOpacity(0.3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isError ? Icons.warning : Icons.smart_toy, size: 14, color: isError ? AppTheme.error : AppTheme.accent),
                const SizedBox(width: 8),
                Text("SYSTEM RESPONSE", style: TextStyle(fontSize: 10, color: isError ? AppTheme.error : AppTheme.accent, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            
            Text(req.inputText, style: TextStyle(color: isError ? AppTheme.error : Colors.white, fontSize: 14)),
            const SizedBox(height: 12),
            
            if (isError)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), border: Border.all(color: AppTheme.error.withOpacity(0.5))),
                child: const Text("UPLINK FAILURE", style: TextStyle(fontSize: 9, color: AppTheme.error, fontFamily: 'Share Tech Mono', fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ).animate().fadeIn().slideX(begin: -0.1),
    );
  }
}