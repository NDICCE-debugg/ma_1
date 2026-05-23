import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/auth_service.dart';
import 'package:ma_1/services/gemini_service.dart';

// ─── Chat message model ──────────────────────────────────────────────────────

enum _Role { user, assistant, error }

class _ChatMessage {
  final _Role role;
  String text;
  bool isStreaming;
  final DateTime timestamp;

  _ChatMessage({
    required this.role,
    required this.text,
    this.isStreaming = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ─── Suggestion chips ────────────────────────────────────────────────────────

const List<String> _kSuggestions = [
  'Aeonmed VG70 turbine replacement steps',
  'ERR-TURB-09 alarm meaning and fix',
  'Pre-use checkout for Dräger Evita V500',
  'O2 sensor calibration procedure',
  'PEEP valve inspection checklist',
  'Mindray A5 sodalime canister change',
  'Flow sensor TSI calibration steps',
  'Ventilator PM schedule intervals',
];

// ─── Main Widget ─────────────────────────────────────────────────────────────

class AIAssistantView extends StatefulWidget {
  const AIAssistantView({super.key});

  @override
  State<AIAssistantView> createState() => _AIAssistantViewState();
}

class _AIAssistantViewState extends State<AIAssistantView> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<_ChatMessage> _messages = [];
  bool _isProcessing = false;
  bool _isListening = false;
  String _listeningText = '';

  late stt.SpeechToText _speech;
  late FlutterTts _tts;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initTts();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _tts.stop();
    super.dispose();
  }

  void _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.45);
  }

  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        if (instant) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        } else {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  // ─── Send message ───────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    text = text.trim();
    if (text.isEmpty || _isProcessing) return;

    _textCtrl.clear();
    _focusNode.requestFocus();

    setState(() {
      _messages.add(_ChatMessage(role: _Role.user, text: text));
      _isProcessing = true;
    });
    _scrollToBottom();

    // Add an empty streaming assistant message
    final assistantMsg = _ChatMessage(
      role: _Role.assistant,
      text: '',
      isStreaming: true,
    );
    setState(() => _messages.add(assistantMsg));

    try {
      final stream = GeminiService.instance.streamMessage(text);
      await for (final chunk in stream) {
        assistantMsg.text += chunk;
        setState(() {});
        _scrollToBottom();
      }
      assistantMsg.isStreaming = false;
      setState(() => _isProcessing = false);

      // Speak if voice was used
      if (_isListening) {
        await _tts.speak(assistantMsg.text);
      }
    } on GeminiException catch (e) {
      assistantMsg.role == _Role.error;
      final errMsg = _ChatMessage(
        role: _Role.error,
        text: e.message,
      );
      setState(() {
        _messages.removeLast(); // remove the empty assistant bubble
        _messages.add(errMsg);
        _isProcessing = false;
      });
    } catch (e) {
      final errMsg = _ChatMessage(
        role: _Role.error,
        text: 'Unexpected error: $e',
      );
      setState(() {
        _messages.removeLast();
        _messages.add(errMsg);
        _isProcessing = false;
      });
    }

    _scrollToBottom();
  }

  // ─── Voice ─────────────────────────────────────────────────────────────────

  void _toggleVoice() async {
    if (kIsWeb) {
      _showSnack('Voice input requires the mobile app.');
      return;
    }
    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
        _listeningText = '';
      });
      return;
    }

    final available = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    if (!available) {
      _showSnack('Microphone not available.');
      return;
    }

    setState(() => _isListening = true);
    _speech.listen(
      onResult: (val) {
        setState(() => _listeningText = val.recognizedWords);
        if (val.finalResult && val.recognizedWords.isNotEmpty) {
          setState(() {
            _isListening = false;
            _listeningText = '';
          });
          _sendMessage(val.recognizedWords);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
      ),
    );
  }

  // ─── New chat ───────────────────────────────────────────────────────────────

  void _newChat() {
    GeminiService.instance.newChat();
    setState(() => _messages.clear());
  }

  // ─── Helper ─────────────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Outfit')),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final user = AuthService.instance.currentUser;
    final name = (user?.userMetadata?['name'] as String?) ?? 'Technician';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          if (isWide) _buildSidebar(name, initial),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isWide),
                // API key warning banner
                if (!GeminiService.instance.isConfigured) _buildKeyBanner(),
                // Processing indicator
                if (_isProcessing)
                  LinearProgressIndicator(
                    minHeight: 2.5,
                    color: AppTheme.primary,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                  ),
                // Listening indicator
                if (_isListening) _buildListeningBanner(),
                // Messages or greeting
                Expanded(
                  child: _messages.isEmpty
                      ? _buildGreeting(name)
                      : _buildMessageList(),
                ),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── API KEY BANNER ─────────────────────────────────────────────────────────

  Widget _buildKeyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppTheme.warning.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined,
              color: AppTheme.warning, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Gemini API key not set. '
              'Open lib/utils/app_config.dart and paste your key into geminiApiKey.',
              style: TextStyle(
                  color: AppTheme.warning,
                  fontSize: 12,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(
                  const ClipboardData(text: 'lib/utils/app_config.dart'));
              _showSnack('Path copied to clipboard');
            },
            child: const Text('Copy path',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.warning,
                    fontFamily: 'Outfit')),
          ),
        ],
      ),
    );
  }

  // ─── LISTENING BANNER ───────────────────────────────────────────────────────

  Widget _buildListeningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppTheme.error.withValues(alpha: 0.06),
      child: Row(
        children: [
          const Icon(Icons.mic, color: AppTheme.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _listeningText.isEmpty
                  ? 'Listening… speak your question'
                  : '"$_listeningText"',
              style: const TextStyle(
                  color: AppTheme.error,
                  fontSize: 13,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: _toggleVoice,
            child: const Text('Cancel',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.error, fontFamily: 'Outfit')),
          ),
        ],
      ),
    );
  }

  // ─── SIDEBAR ────────────────────────────────────────────────────────────────

  Widget _buildSidebar(String userName, String initial) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'BioMed AI',
                style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'Outfit',
                    letterSpacing: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // New chat button
          InkWell(
            onTap: _newChat,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, color: Color(0xFF0F172A), size: 18),
                  SizedBox(width: 12),
                  Text('New chat',
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text('QUICK TOPICS',
              style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  fontFamily: 'Outfit')),
          const SizedBox(height: 10),

          ...[
            ('Ventilator Faults', Icons.air_outlined),
            ('Calibration Guides', Icons.tune_outlined),
            ('Spare Parts', Icons.inventory_2_outlined),
            ('PM Schedules', Icons.calendar_today_outlined),
            ('Alarm Codes', Icons.notifications_outlined),
          ].map((item) => _buildSidebarItem(item.$2, item.$1)),

          const Divider(height: 32, color: Color(0xFFE2E8F0)),

          const Text('RECENT',
              style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  fontFamily: 'Outfit')),
          const SizedBox(height: 8),
          _buildSidebarItem(
              Icons.chat_bubble_outline_rounded, 'VG70 O2 Calibration'),
          _buildSidebarItem(
              Icons.chat_bubble_outline_rounded, 'PEEP Valve Service'),
          _buildSidebarItem(
              Icons.chat_bubble_outline_rounded, 'ERR-TURB-09 Fix'),

          const Spacer(),

          // API key status indicator
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GeminiService.instance.isConfigured
                  ? AppTheme.success.withValues(alpha: 0.08)
                  : AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: GeminiService.instance.isConfigured
                    ? AppTheme.success.withValues(alpha: 0.2)
                    : AppTheme.warning.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  GeminiService.instance.isConfigured
                      ? Icons.check_circle_outline
                      : Icons.key_outlined,
                  size: 14,
                  color: GeminiService.instance.isConfigured
                      ? AppTheme.success
                      : AppTheme.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    GeminiService.instance.isConfigured
                        ? 'Gemini AI connected'
                        : 'API key needed',
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        color: GeminiService.instance.isConfigured
                            ? AppTheme.success
                            : AppTheme.warning),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Profile
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.secondary,
                child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName,
                        style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const Text('BioMed Technician',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: () => _sendMessage(title),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF475569), size: 15),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13,
                        fontFamily: 'Outfit')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TOP BAR ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar(bool isWide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          if (!isWide) ...[
            const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 18),
            const SizedBox(width: 8),
            const Text('BioMed AI',
                style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit')),
          ],
          const Spacer(),
          // Model label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppTheme.primary, size: 12),
                SizedBox(width: 5),
                Text('Gemini 1.5 Flash',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit')),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Clear button
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'New conversation',
              icon: const Icon(Icons.refresh_outlined,
                  size: 18, color: Color(0xFF475569)),
              onPressed: _newChat,
            ),
        ],
      ),
    );
  }

  // ─── GREETING ────────────────────────────────────────────────────────────────

  Widget _buildGreeting(String name) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      children: [
        Center(
          child: Column(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 56)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shimmer(duration: 2000.ms)
                  .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.1, 1.1),
                      duration: 1500.ms),
              const SizedBox(height: 20),
              Text(
                'Hello, ${name.split(' ').first}.',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                    letterSpacing: -0.5),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 8),
              const Text(
                'Your clinical engineering AI assistant.\nAsk me about faults, maintenance, alarms, or spare parts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                    fontFamily: 'Outfit',
                    height: 1.5),
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        ),
        const SizedBox(height: 40),

        // Suggestion chips grid
        const Text('Suggested questions',
            style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                fontFamily: 'Outfit')),
        const SizedBox(height: 12),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _kSuggestions
              .asMap()
              .entries
              .map((e) => _buildChip(e.value, delay: e.key * 40))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildChip(String text, {int delay = 0}) {
    return InkWell(
      onTap: () => _sendMessage(text),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF0F172A), fontSize: 13, fontFamily: 'Outfit')),
      ),
    )
        .animate()
        .fadeIn(delay: delay.ms, duration: 300.ms)
        .slideY(begin: 0.05, end: 0);
  }

  // ─── MESSAGE LIST ───────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg = _messages[i];
        return _buildMessageBubble(msg, i);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, int index) {
    final isUser = msg.role == _Role.user;
    final isError = msg.role == _Role.error;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Container(
                margin: const EdgeInsets.only(right: 10, top: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isError
                      ? AppTheme.error.withValues(alpha: 0.1)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError ? Icons.error_outline : Icons.auto_awesome,
                  color: isError ? AppTheme.error : AppTheme.primary,
                  size: 15,
                ),
              ),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Bubble
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFFF1F5F9)
                          : isError
                              ? AppTheme.error.withValues(alpha: 0.05)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? const Radius.circular(4) : null,
                        bottomLeft: !isUser ? const Radius.circular(4) : null,
                      ),
                      border: Border.all(
                        color: isError
                            ? AppTheme.error.withValues(alpha: 0.2)
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormattedText(msg.text, isError: isError),
                        if (msg.isStreaming) ...[
                          const SizedBox(height: 8),
                          _buildTypingIndicator(),
                        ],
                      ],
                    ),
                  ),

                  // Footer: source + copy button (for assistant messages)
                  if (!isUser && !isError && !msg.isStreaming)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'BioMed AI • Gemini 1.5 Flash',
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
                                fontStyle: FontStyle.italic,
                                fontFamily: 'Outfit'),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: msg.text));
                              _showSnack('Copied to clipboard');
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.copy_outlined,
                                  size: 13, color: Color(0xFF94A3B8)),
                            ),
                          ),
                          InkWell(
                            onTap: () async => await _tts.speak(msg.text),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.volume_up_outlined,
                                  size: 13, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0);
  }

  // Minimal structured text renderer (bold + bullets)
  Widget _buildFormattedText(String text, {bool isError = false}) {
    final color = isError ? AppTheme.error : const Color(0xFF0F172A);
    final lines = text.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        // Headers (##, ###)
        if (line.startsWith('### ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(line.replaceFirst('### ', ''),
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit')),
          );
        }
        if (line.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(line.replaceFirst('## ', ''),
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit')),
          );
        }
        // Bullet / numbered list
        if (line.trimLeft().startsWith('- ') ||
            line.trimLeft().startsWith('• ') ||
            RegExp(r'^\d+\. ').hasMatch(line.trimLeft())) {
          final indent = line.length - line.trimLeft().length;
          return Padding(
            padding:
                EdgeInsets.only(left: indent > 0 ? 16.0 : 0, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('  •  ',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 14,
                        fontFamily: 'Outfit')),
                Expanded(
                  child: _inlineText(
                      line
                          .trimLeft()
                          .replaceFirst(RegExp(r'^[-•\d]+[.\s]+'), ''),
                      color),
                ),
              ],
            ),
          );
        }
        // Bold **text**
        if (line.contains('**')) {
          return Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: _inlineText(line, color),
          );
        }
        // Empty line → spacing
        if (line.trim().isEmpty) return const SizedBox(height: 6);
        // Normal paragraph
        return Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2),
          child: Text(line,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  height: 1.55,
                  fontFamily: 'Outfit')),
        );
      }).toList(),
    );
  }

  Widget _inlineText(String text, Color defaultColor) {
    // Parse **bold** segments
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          fontWeight: i.isOdd ? FontWeight.bold : FontWeight.normal,
          color: defaultColor,
          fontSize: 14,
          height: 1.55,
          fontFamily: 'Outfit',
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(right: 4),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
              color: AppTheme.primary, shape: BoxShape.circle),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleY(
            delay: (i * 150).ms, duration: 600.ms, begin: 0.4, end: 1.0),
      ),
    );
  }

  // ─── INPUT AREA ─────────────────────────────────────────────────────────────

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Text field
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit'),
                    decoration: const InputDecoration(
                      hintText: 'Ask about faults, maintenance, alarms…',
                      hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontFamily: 'Outfit'),
                      border: InputBorder.none,
                      isDense: true,
                      fillColor: Colors.transparent,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (_) {
                      if (!_isProcessing) _sendMessage(_textCtrl.text);
                    },
                  ),
                ),

                const SizedBox(width: 8),

                // Voice button
                if (!kIsWeb)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: GestureDetector(
                      onTap: _toggleVoice,
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none_outlined,
                        color: _isListening
                            ? AppTheme.error
                            : const Color(0xFF94A3B8),
                        size: 22,
                      ),
                    ),
                  ),

                const SizedBox(width: 8),

                // Send button
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: GestureDetector(
                    onTap: _isProcessing
                        ? null
                        : () => _sendMessage(_textCtrl.text),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isProcessing
                            ? AppTheme.primary.withValues(alpha: 0.4)
                            : AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
