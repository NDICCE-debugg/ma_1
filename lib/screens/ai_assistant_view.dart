import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:ma_1/models/ai_request.dart';

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
  
  late stt.SpeechToText _speech;
  bool _isListening = false;
  late FlutterTts _flutterTts;
  final ImagePicker _picker = ImagePicker();

  static const String _pcIpAddress = "10.160.120.215"; 
  String get _apiUrl => kIsWeb 
      ? "http://localhost:5000/api/query" 
      : "http://$_pcIpAddress:5000/api/query";

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
    await _flutterTts.setPitch(1.0); // More natural pitch for medical context
    await _flutterTts.setSpeechRate(0.45);
  }

  Future<void> _loadHistory() async {
    final reqs = await DatabaseHelper.instance.getAiRequests();
    setState(() => _requests = reqs);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, 
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });
    }
  }

  Future<void> _processUserRequest(String input, String type, {String? imagePath}) async {
    if (input.isEmpty && imagePath == null) return;

    // 1. Save user's question locally
    final userReq = AiRequest(
      inputText: input.isEmpty ? "Image captured for analysis" : input,
      inputType: type,
      imagePath: imagePath,
      timestamp: DateTime.now().toIso8601String(),
      status: "sent",
    );
    await DatabaseHelper.instance.addAiRequest(userReq);
    _textCtrl.clear();
    await _loadHistory();

    setState(() => _isProcessing = true);

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"query": input}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiAnswer = data['answer'] ?? "No data available.";

        final sysReq = AiRequest(
          inputText: aiAnswer,
          inputType: 'system',
          timestamp: DateTime.now().toIso8601String(),
          status: 'delivered',
        );
        await DatabaseHelper.instance.addAiRequest(sysReq);

        if (type == 'voice') await _flutterTts.speak(aiAnswer);

      } else {
        throw Exception("Connection failed");
      }
    } catch (e) {
      final errReq = AiRequest(
        inputText: "Connection Error: Unable to reach clinical database. Please verify server status. ($e)",
        inputType: 'system',
        timestamp: DateTime.now().toIso8601String(),
        status: 'error',
      );
      await DatabaseHelper.instance.addAiRequest(errReq);
    }

    setState(() => _isProcessing = false);
    await _loadHistory();
  }

  void _submitText() => _processUserRequest(_textCtrl.text.trim(), 'text');

  void _listenVoice() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
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
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      final directory = await getApplicationDocumentsDirectory();
      final String savedPath = '${directory.path}/${path.basename(photo.path)}';
      await File(photo.path).copy(savedPath);
      _processUserRequest("", 'image', imagePath: savedPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(
        children: [
          // Professional Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.psychology, color: AppTheme.primary, size: 28),
                const SizedBox(width: 12),
                Text("AI Assistant", 
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primaryDark)),
                const Spacer(),
                const Text("Manuals Online", 
                  style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          if (_isProcessing) 
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppTheme.primary, 
              backgroundColor: Colors.transparent),

          // Chat History
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                return req.inputType == 'system' ? _buildAssistantBubble(req) : _buildUserBubble(req);
              },
            ),
          ),

          // Clean Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  _buildCircleIconButton(Icons.camera_alt_outlined, _captureImage),
                  const SizedBox(width: 8),
                  _buildCircleIconButton(
                    _isListening ? Icons.mic : Icons.mic_none_outlined, 
                    _listenVoice, 
                    isActive: _isListening
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textCtrl,
                        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          hintText: "Ask a technical question...", 
                          hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _submitText(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isProcessing ? null : _submitText,
                    child: CircleAvatar(
                      backgroundColor: _isProcessing ? AppTheme.neutral : AppTheme.primary,
                      radius: 20,
                      child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton(IconData icon, VoidCallback onTap, {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.error.withValues(alpha: 0.1) : AppTheme.background,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isActive ? AppTheme.error : AppTheme.textSecondary, size: 22),
      ),
    );
  }

  Widget _buildUserBubble(AiRequest req) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 50),
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (req.imagePath != null && File(req.imagePath!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(req.imagePath!), height: 160, fit: BoxFit.cover),
              ),
            const SizedBox(height: 4),
            Text(req.inputText, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0),
    );
  }

  Widget _buildAssistantBubble(AiRequest req) {
    bool isError = req.status == 'error';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20, right: 50),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: isError ? AppTheme.error : AppTheme.primary, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isError ? Icons.report_problem : Icons.smart_toy_outlined, 
                  size: 14, color: isError ? AppTheme.error : AppTheme.primary),
                const SizedBox(width: 6),
                Text(isError ? "System Alert" : "Clinical Assistant", 
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, 
                  color: isError ? AppTheme.error : AppTheme.primary)),
              ],
            ),
            const SizedBox(height: 8),
            Text(req.inputText, 
              style: TextStyle(color: isError ? AppTheme.error : AppTheme.textPrimary, fontSize: 14, height: 1.4)),
            if (!isError) ...[
              const SizedBox(height: 10),
              const Text("Source: Clinical Service Manuals", 
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
            ]
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
    );
  }
}