import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/auth_service.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:ma_1/services/gemini_service.dart';
import 'package:ma_1/services/manual_rag_service.dart';
import 'package:ma_1/services/rag_api_service.dart';
import 'package:ma_1/screens/manuals_library_screen.dart';
import 'package:ma_1/widgets/pulse_logo.dart';
import 'package:ma_1/utils/app_snackbar.dart';

// â”€â”€â”€ Chat message model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

enum _Role { user, assistant, error }

class _ChatMessage {
  final _Role role;
  String text;
  bool isStreaming;
  final List<GeminiAttachment> attachments;
  final DateTime timestamp;

  _ChatMessage({
    required this.role,
    required this.text,
    this.isStreaming = false,
    this.attachments = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _PromptMode {
  final String label;
  final IconData icon;
  final String instruction;

  const _PromptMode(this.label, this.icon, this.instruction);
}

// â”€â”€â”€ Suggestion chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const List<String> _kSuggestions = [
  'Aeonmed VG70 turbine replacement steps',
  'ERR-TURB-09 alarm meaning and fix',
  'Pre-use checkout for Drager Evita V500',
  'O2 sensor calibration procedure',
  'PEEP valve inspection checklist',
  'Mindray A5 sodalime canister change',
  'Flow sensor TSI calibration steps',
  'Ventilator PM schedule intervals',
];

const List<_PromptMode> _kPromptModes = [
  _PromptMode(
    'Triage',
    Icons.manage_search_outlined,
    'Answer as a fault triage workflow. Start with immediate safety checks, '
        'then likely causes, tests, and escalation criteria.',
  ),
  _PromptMode(
    'Procedure',
    Icons.format_list_numbered_outlined,
    'Answer as a controlled maintenance procedure with tools, prerequisites, '
        'steps, verification, and documentation notes.',
  ),
  _PromptMode(
    'Parts',
    Icons.inventory_2_outlined,
    'Focus on spare parts, compatibility checks, supplier notes, lead-time '
        'risk, and substitution warnings.',
  ),
  _PromptMode(
    'Explain',
    Icons.school_outlined,
    'Teach the concept clearly for a biomedical technician. Keep it concise '
        'and include what to check on the machine.',
  ),
];

// â”€â”€â”€ Main Widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
  final List<GeminiAttachment> _attachments = [];
  int _selectedModeIndex = 0;
  bool _isProcessing = false;
  bool _isListening = false;
  bool _cancelRequested = false;
  bool _isLoadingHistory = false;
  String _listeningText = '';
  int? _activeConversationId;
  String? _activeConversationTitle;
  List<Map<String, dynamic>> _conversationHistory = [];

  late stt.SpeechToText _speech;
  late FlutterTts _tts;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _focusNode.addListener(_handleComposerFocusChange);
    _initTts();
    _loadConversationHistory();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.removeListener(_handleComposerFocusChange);
    _focusNode.dispose();
    _tts.stop();
    super.dispose();
  }

  void _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.45);
  }

  void _handleComposerFocusChange() => setState(() {});

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

  // â”€â”€â”€ Send message â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _sendMessage(String text) async {
    text = text.trim();
    if ((text.isEmpty && _attachments.isEmpty) || _isProcessing) return;

    final mode = _kPromptModes[_selectedModeIndex];
    final files = List<GeminiAttachment>.from(_attachments);
    final attachmentInstruction = files.isEmpty
        ? ''
        : '\n\nAttached clinical media: ${files.map((f) => '${f.name} (${f.mimeType})').join(', ')}. '
            'Inspect the attachment(s) and connect observations to the technician question.';
    final technicianQuestion = text.isEmpty
        ? 'Analyze the attached machine media and provide a safe biomedical engineering assessment.'
        : text;
    final ragContext =
        await ManualRagService.instance.buildContext(technicianQuestion);
    final priorContext = _buildPriorConversationContext();
    final ragInstruction = ragContext.hasContext
        ? '\n\n${ragContext.promptBlock}\n\nRAG ANSWER RULES:\n'
            '- Use uploaded manual context first.\n'
            '- Include a short "Manual sources used" section.\n'
            '- If the manual does not contain a requested limit or procedure, say so.\n'
        : '\n\nNo uploaded manual context matched this question. Answer from general biomedical engineering knowledge and recommend checking the manufacturer manual.';
    final prompt =
        '${mode.instruction}$attachmentInstruction$priorContext$ragInstruction\n\nTechnician question: $technicianQuestion';
    final modelAttachments = [
      ...files,
      ...ragContext.attachments,
    ];

    await _ensureActiveConversation(technicianQuestion);

    _textCtrl.clear();
    _focusNode.requestFocus();

    setState(() {
      _messages.add(_ChatMessage(
        role: _Role.user,
        text: technicianQuestion,
        attachments: files,
      ));
      _attachments.clear();
      _isProcessing = true;
      _cancelRequested = false;
    });
    await _persistAiMessage(
      role: _Role.user,
      text: technicianQuestion,
      attachments: files,
    );
    _scrollToBottom();

    // Add an empty streaming assistant message
    final assistantMsg = _ChatMessage(
      role: _Role.assistant,
      text: 'Preparing a safe answer...',
      isStreaming: true,
    );
    setState(() => _messages.add(assistantMsg));

    try {
      final shouldUseBackendRag =
          files.isEmpty && _shouldUseBackendRag(technicianQuestion);
      if (shouldUseBackendRag) {
        try {
          setState(() {
            assistantMsg.text =
                'Checking indexed manuals and calibration references...';
          });
          final ragAnswer = await RagApiService.instance
              .queryManuals(
                query: technicianQuestion,
              )
              .timeout(const Duration(seconds: 18));
          if (ragAnswer.hasManualContext &&
              ragAnswer.answer.trim().isNotEmpty) {
            assistantMsg.text = _formatRagAnswer(ragAnswer);
            assistantMsg.isStreaming = false;
            setState(() {
              _isProcessing = false;
              _cancelRequested = false;
            });
            await _persistAiMessage(
              role: _Role.assistant,
              text: assistantMsg.text,
            );
            _scrollToBottom();
            return;
          }
        } catch (e) {
          debugPrint('Backend RAG unavailable, falling back to local AI: $e');
        }
      }

      setState(() {
        assistantMsg.text = 'Contacting Pulse AI securely...';
      });
      final stream = GeminiService.instance
          .streamMessage(prompt, attachments: modelAttachments);
      var receivedFirstChunk = false;
      await for (final chunk in stream) {
        if (_cancelRequested) break;
        if (!receivedFirstChunk) {
          assistantMsg.text = '';
          receivedFirstChunk = true;
        }
        assistantMsg.text += chunk;
        setState(() {});
        _scrollToBottom();
      }
      if (_cancelRequested && assistantMsg.text.trim().isEmpty) {
        assistantMsg.text = 'Response stopped.';
      } else if (assistantMsg.text.trim().isEmpty) {
        assistantMsg.text =
            'Pulse AI did not return text. Check backend logs and retry.';
      }
      assistantMsg.isStreaming = false;
      setState(() {
        _isProcessing = false;
        _cancelRequested = false;
      });
      await _persistAiMessage(role: _Role.assistant, text: assistantMsg.text);

      // Speak if voice was used
      if (_isListening) {
        await _tts.speak(assistantMsg.text);
      }
    } on GeminiException catch (e) {
      final errMsg = _ChatMessage(
        role: _Role.error,
        text: e.message,
      );
      setState(() {
        _messages.removeLast(); // remove the empty assistant bubble
        _messages.add(errMsg);
        _isProcessing = false;
        _cancelRequested = false;
      });
      await _persistAiMessage(role: _Role.error, text: e.message);
    } catch (e) {
      final errMsg = _ChatMessage(
        role: _Role.error,
        text: 'Unexpected error: $e',
      );
      setState(() {
        _messages.removeLast();
        _messages.add(errMsg);
        _isProcessing = false;
        _cancelRequested = false;
      });
      await _persistAiMessage(role: _Role.error, text: 'Unexpected error: $e');
    }

    _scrollToBottom();
  }

  bool _shouldUseBackendRag(String query) {
    final lower = query.toLowerCase();
    const manualTerms = [
      'manual',
      'procedure',
      'calibration',
      'calibrate',
      'service',
      'schematic',
      'fault code',
      'error code',
      'alarm code',
      'maintenance',
      'pm schedule',
      'section',
      'page',
      'manufacturer',
    ];
    const modelTerms = [
      'vg70',
      'evita',
      'v500',
      'mindray',
      'wato',
      'drager',
      'draeger',
      'aeonmed',
    ];
    return manualTerms.any(lower.contains) || modelTerms.any(lower.contains);
  }

  String _formatRagAnswer(RagQueryResult result) {
    final answer = result.answer.trim();
    if (result.sources.isEmpty) return answer;
    if (answer.toLowerCase().contains('manual sources used')) return answer;
    final sources = result.sources.take(5).map((source) {
      final page =
          source.pageNumber == null ? '' : ', page ${source.pageNumber}';
      final section = (source.sectionTitle ?? '').trim().isEmpty
          ? ''
          : ' - ${source.sectionTitle}';
      return '- ${source.fileName}$page$section';
    }).join('\n');
    return '$answer\n\nManual sources used:\n$sources';
  }

  // â”€â”€â”€ Voice â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _toggleVoice() async {
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
          if (!mounted) return;
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
        if (!mounted) return;
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

  // â”€â”€â”€ New chat â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _loadConversationHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final history = await DatabaseHelper.instance.getAiConversations();
      if (!mounted) return;
      setState(() => _conversationHistory = history);
    } catch (e) {
      if (mounted) _showSnack('Could not load AI history: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _ensureActiveConversation(String firstPrompt) async {
    if (_activeConversationId != null) return;
    final title = _conversationTitle(firstPrompt);
    final id = await DatabaseHelper.instance.createAiConversation(
      title: title,
      preview: _conversationPreview(firstPrompt),
    );
    if (!mounted) return;
    setState(() {
      _activeConversationId = id;
      _activeConversationTitle = title;
    });
    await _loadConversationHistory();
  }

  Future<void> _persistAiMessage({
    required _Role role,
    required String text,
    List<GeminiAttachment> attachments = const [],
  }) async {
    final conversationId = _activeConversationId;
    if (conversationId == null || text.trim().isEmpty) return;

    final attachmentSummary = attachments
        .map((a) => {
              'name': a.name,
              'mimeType': a.mimeType,
            })
        .toList();
    await DatabaseHelper.instance.addAiConversationMessage(
      conversationId: conversationId,
      role: _roleKey(role),
      text: text,
      attachmentsJson:
          attachmentSummary.isEmpty ? null : jsonEncode(attachmentSummary),
    );
    await DatabaseHelper.instance.updateAiConversation(
      id: conversationId,
      title: _activeConversationTitle ?? _conversationTitle(text),
      preview: _conversationPreview(text),
    );
    await _loadConversationHistory();
  }

  Future<void> _openConversation(Map<String, dynamic> conversation) async {
    if (_isProcessing) {
      _showSnack('Stop the current response before opening history.');
      return;
    }

    final id = conversation['id'] as int?;
    if (id == null) return;

    final rows = await DatabaseHelper.instance.getAiConversationMessages(id);
    GeminiService.instance.newChat();
    if (!mounted) return;
    setState(() {
      _activeConversationId = id;
      _activeConversationTitle =
          conversation['title']?.toString() ?? 'Pulse conversation';
      _attachments.clear();
      _messages
        ..clear()
        ..addAll(rows.map((row) => _messageFromHistory(row)));
      _isProcessing = false;
      _cancelRequested = false;
    });
    _scrollToBottom(instant: true);
  }

  _ChatMessage _messageFromHistory(Map<String, dynamic> row) {
    return _ChatMessage(
      role: _roleFromKey(row['role']?.toString()),
      text: row['text']?.toString() ?? '',
      timestamp: DateTime.tryParse(row['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String _buildPriorConversationContext() {
    if (_messages.isEmpty) return '';
    final recent = _messages
        .where((message) => message.text.trim().isNotEmpty)
        .toList()
        .reversed
        .take(8)
        .toList()
        .reversed;
    final lines = recent.map((message) {
      final speaker = switch (message.role) {
        _Role.user => 'Technician',
        _Role.assistant => 'Pulse AI',
        _Role.error => 'System error',
      };
      return '$speaker: ${_compactForPrompt(message.text)}';
    }).join('\n');
    return '\n\nPrevious conversation context:\n$lines';
  }

  String _roleKey(_Role role) {
    return switch (role) {
      _Role.user => 'user',
      _Role.assistant => 'assistant',
      _Role.error => 'error',
    };
  }

  _Role _roleFromKey(String? role) {
    return switch (role) {
      'user' => _Role.user,
      'assistant' => _Role.assistant,
      'error' => _Role.error,
      _ => _Role.assistant,
    };
  }

  String _conversationTitle(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return 'Machine media review';
    return clean.length <= 44 ? clean : '${clean.substring(0, 41)}...';
  }

  String _conversationPreview(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return 'No preview available';
    return clean.length <= 84 ? clean : '${clean.substring(0, 81)}...';
  }

  String _compactForPrompt(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.length <= 420 ? clean : '${clean.substring(0, 417)}...';
  }

  void _newChat() {
    GeminiService.instance.newChat();
    setState(() {
      _activeConversationId = null;
      _activeConversationTitle = null;
      _messages.clear();
      _attachments.clear();
      _isProcessing = false;
      _cancelRequested = true;
    });
  }

  void _stopGenerating() {
    if (!_isProcessing) return;
    setState(() => _cancelRequested = true);
  }

  Future<void> _pickImageAttachment() async {
    await _pickAttachment(
      typeLabel: 'image',
      extensions: const ['jpg', 'jpeg', 'png', 'webp', 'heic'],
      fallbackMimeType: 'image/jpeg',
    );
  }

  Future<void> _pickAttachment({
    required String typeLabel,
    required List<String> extensions,
    required String fallbackMimeType,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: false,
        withData: true,
      );

      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;

      if (bytes.length > 18 * 1024 * 1024) {
        _showSnack('The $typeLabel file is too large. Use a file under 18 MB.');
        return;
      }

      setState(() {
        _attachments.add(GeminiAttachment(
          name: file.name,
          mimeType: _mimeTypeFor(file.name, fallbackMimeType),
          bytes: bytes,
        ));
      });
    } catch (e) {
      _showSnack('Could not attach $typeLabel: $e');
    }
  }

  String _mimeTypeFor(String fileName, String fallback) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'ogg' => 'audio/ogg',
      'webm' => 'audio/webm',
      _ => fallback,
    };
  }

  // â”€â”€â”€ Helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showSnack(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('error') || lower.contains('failed') || lower.contains('could not')) {
      AppSnackBar.error(context, msg);
    } else if (lower.contains('stop') || lower.contains('large') || lower.contains('not available')) {
      AppSnackBar.warning(context, msg);
    } else if (lower.contains('copied') || lower.contains('success')) {
      AppSnackBar.success(context, msg);
    } else {
      AppSnackBar.info(context, msg);
    }
  }

  Future<void> _openManualLibrary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManualsLibraryScreen()),
    );
  }

  // â”€â”€â”€ BUILD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                _buildSafetyBanner(),
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

  // â”€â”€â”€ API KEY BANNER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSafetyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.iceBlue.withValues(alpha: 0.18),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_outlined, color: AppTheme.primary, size: 16),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Clinical safety mode: verify against the service manual, isolate power/gas sources, and escalate patient-facing decisions.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
              'Backend AI key not available. '
              'Set GEMINI_API_KEY in backend/.env and restart the Flask service.',
              style: TextStyle(
                  color: AppTheme.warning,
                  fontSize: 12,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: 'backend/.env'));
              _showSnack('Backend env path copied to clipboard');
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

  // â”€â”€â”€ LISTENING BANNER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                  ? 'Listening... speak your question'
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

  // â”€â”€â”€ SIDEBAR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
              PulseLogo(size: 24, borderRadius: 6),
              SizedBox(width: 8),
              Text(
                'Pulse AI',
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

          InkWell(
            onTap: _openManualLibrary,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.secondary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondary.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.menu_book_outlined, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Manuals library',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 17),
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

          Row(
            children: [
              const Expanded(
                child: Text('HISTORY',
                    style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        fontFamily: 'Outfit')),
              ),
              IconButton(
                tooltip: 'Refresh history',
                visualDensity: VisualDensity.compact,
                onPressed: _loadConversationHistory,
                icon: const Icon(Icons.refresh_rounded,
                    size: 15, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (_conversationHistory.isEmpty)
            const Text(
              'No saved AI conversations yet.',
              style: TextStyle(
                  color: Color(0xFF64748B), fontSize: 12, fontFamily: 'Outfit'),
            )
          else
            ..._conversationHistory
                .take(7)
                .map((conversation) => _buildHistoryItem(conversation)),

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
                    const Text('Pulse Technician',
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

  // â”€â”€â”€ TOP BAR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildHistoryItem(Map<String, dynamic> conversation) {
    final id = conversation['id'] as int?;
    final selected = id != null && id == _activeConversationId;
    final title = conversation['title']?.toString() ?? 'Pulse conversation';
    final preview = conversation['preview']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _openConversation(conversation),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: AppTheme.primary.withValues(alpha: 0.14))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: selected ? AppTheme.primary : const Color(0xFF64748B),
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? AppTheme.primary
                            : const Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.w600,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistoryDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'AI conversation history',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoadingHistory)
                  const LinearProgressIndicator(minHeight: 2)
                else if (_conversationHistory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No saved AI conversations yet.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _conversationHistory.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (context, index) {
                        final conversation = _conversationHistory[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history_rounded,
                              color: AppTheme.primary),
                          title: Text(
                            conversation['title']?.toString() ??
                                'Pulse conversation',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          subtitle: Text(
                            conversation['preview']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Outfit'),
                          ),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _openConversation(conversation);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isWide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          if (!isWide) ...[
            const PulseLogo(size: 22, borderRadius: 6),
            const SizedBox(width: 8),
            const Text('Pulse AI',
                style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit')),
          ],
          const Spacer(),
          if (MediaQuery.of(context).size.width > 620)
            FilledButton.tonalIcon(
              onPressed: _openManualLibrary,
              icon: const Icon(Icons.menu_book_outlined, size: 17),
              label: const Text('Manuals'),
            )
          else
            IconButton(
              tooltip: 'Manuals library',
              icon: const Icon(Icons.menu_book_outlined,
                  size: 18, color: Color(0xFF475569)),
              onPressed: _openManualLibrary,
            ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Conversation history',
            icon: const Icon(Icons.history_rounded,
                size: 18, color: Color(0xFF475569)),
            onPressed: _showHistoryDialog,
          ),
          const SizedBox(width: 4),
          if (_isProcessing)
            TextButton.icon(
              onPressed: _stopGenerating,
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: const Text('Stop'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.error,
                textStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          if (MediaQuery.of(context).size.width > 560) _buildModeSelector(),
          const SizedBox(width: 10),
          const PulseLogo(size: 32, borderRadius: 9),
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

  // â”€â”€â”€ GREETING â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildModeSelector() {
    final selected = _kPromptModes[_selectedModeIndex];
    return PopupMenuButton<int>(
      tooltip: 'Response mode',
      onSelected: (index) => setState(() => _selectedModeIndex = index),
      itemBuilder: (context) => [
        for (int i = 0; i < _kPromptModes.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(
                  _kPromptModes[i].icon,
                  color: i == _selectedModeIndex
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  _kPromptModes[i].label,
                  style: TextStyle(
                    color: i == _selectedModeIndex
                        ? AppTheme.primary
                        : AppTheme.textPrimary,
                    fontFamily: 'Outfit',
                    fontWeight: i == _selectedModeIndex
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected.icon, color: AppTheme.textSecondary, size: 14),
            const SizedBox(width: 6),
            Text(
              selected.label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down,
                color: AppTheme.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(String name) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      children: [
        Center(
          child: Column(
            children: [
              const PulseLogo(size: 64, borderRadius: 18)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shimmer(duration: 2000.ms)
                  .scale(
                      begin: const Offset(0.94, 0.94),
                      end: const Offset(1.04, 1.04),
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
              const SizedBox(height: 18),
              Container(
                constraints: const BoxConstraints(maxWidth: 760),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.health_and_safety_outlined,
                        color: AppTheme.warning, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Use AI for technician decision support, not as a replacement for manufacturer manuals, hospital SOPs, or clinical judgement.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 280.ms),
            ],
          ),
        ),
        const SizedBox(height: 32),

        if (MediaQuery.of(context).size.width <= 560) ...[
          const Text('Response mode',
              style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontFamily: 'Outfit')),
          const SizedBox(height: 10),
          _buildModeChips(),
          const SizedBox(height: 24),
        ],

        const Text('Clinical workflows',
            style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                fontFamily: 'Outfit')),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final cards = [
              _buildWorkflowCard(
                Icons.manage_search_outlined,
                'Fault triage',
                'Safety checks, likely causes, tests, escalation.',
                'Triage ERR-TURB-09 on an Aeonmed VG70 with safety-first steps',
              ),
              _buildWorkflowCard(
                Icons.fact_check_outlined,
                'Service procedure',
                'Tools, steps, verification, service log notes.',
                'Create a preventive maintenance checklist for a Mindray A5',
              ),
              _buildWorkflowCard(
                Icons.inventory_2_outlined,
                'Parts planning',
                'Part IDs, compatibility, stock risk, suppliers.',
                'What spare parts should we keep for VG70 oxygen sensor faults?',
              ),
            ];
            return compact
                ? Column(children: cards)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: cards
                        .map((card) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: card,
                              ),
                            ))
                        .toList(),
                  );
          },
        ),
        const SizedBox(height: 32),

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

  Widget _buildModeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < _kPromptModes.length; i++)
          ChoiceChip(
            selected: i == _selectedModeIndex,
            avatar: Icon(_kPromptModes[i].icon, size: 15),
            label: Text(_kPromptModes[i].label),
            onSelected: (_) => setState(() => _selectedModeIndex = i),
            labelStyle: TextStyle(
              color:
                  i == _selectedModeIndex ? Colors.white : AppTheme.textPrimary,
              fontSize: 12,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
            ),
            selectedColor: AppTheme.primary,
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
      ],
    );
  }

  Widget _buildWorkflowCard(
    IconData icon,
    String title,
    String description,
    String prompt,
  ) {
    return InkWell(
      onTap: () => _sendMessage(prompt),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.35,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
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

  // â”€â”€â”€ MESSAGE LIST â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                        Text(
                          isUser
                              ? _formatTime(msg.timestamp)
                              : 'Pulse AI - ${_formatTime(msg.timestamp)}',
                          style: TextStyle(
                            color: isUser
                                ? AppTheme.textSecondary
                                : AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (msg.attachments.isNotEmpty) ...[
                          _buildAttachmentList(msg.attachments, compact: true),
                          const SizedBox(height: 8),
                        ],
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
                            'Pulse AI - Gemini 2.5 Flash',
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

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildAttachmentList(
    List<GeminiAttachment> attachments, {
    bool compact = false,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final attachment in attachments)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 11,
              vertical: compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: AppTheme.iceBlue.withValues(alpha: compact ? 0.18 : 0.26),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  attachment.isImage
                      ? Icons.image_outlined
                      : Icons.graphic_eq_outlined,
                  color: AppTheme.primary,
                  size: compact ? 14 : 16,
                ),
                const SizedBox(width: 7),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? 180 : 260),
                  child: Text(
                    attachment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Rich markdown renderer for AI responses.
  Widget _buildFormattedText(String text, {bool isError = false}) {
    final color = isError ? AppTheme.error : const Color(0xFF0F172A);
    final baseStyle = TextStyle(
      color: color,
      fontSize: 14,
      height: 1.55,
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w500,
    );

    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: baseStyle,
        strong: baseStyle.copyWith(fontWeight: FontWeight.w800),
        em: baseStyle.copyWith(fontStyle: FontStyle.italic),
        h1: baseStyle.copyWith(
          color: isError ? AppTheme.error : AppTheme.primary,
          fontSize: 19,
          height: 1.25,
          fontWeight: FontWeight.w800,
        ),
        h2: baseStyle.copyWith(
          color: isError ? AppTheme.error : AppTheme.primary,
          fontSize: 17,
          height: 1.3,
          fontWeight: FontWeight.w800,
        ),
        h3: baseStyle.copyWith(
          color: isError ? AppTheme.error : AppTheme.primary,
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w800,
        ),
        listBullet: baseStyle.copyWith(
          color: isError ? AppTheme.error : AppTheme.primary,
          fontWeight: FontWeight.bold,
        ),
        blockquote: baseStyle.copyWith(color: AppTheme.textSecondary),
        code: baseStyle.copyWith(
          color: AppTheme.primary,
          backgroundColor: AppTheme.iceBlue.withValues(alpha: 0.28),
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.muted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.divider),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        a: baseStyle.copyWith(
          color: AppTheme.primary,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.bold,
        ),
        tableHead: baseStyle.copyWith(fontWeight: FontWeight.w800),
        tableBody: baseStyle.copyWith(fontSize: 13),
      ),
    );
  }

  /*
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
            line.trimLeft().startsWith('- ') ||
            RegExp(r'^\d+\. ').hasMatch(line.trimLeft())) {
          final indent = line.length - line.trimLeft().length;
          return Padding(
            padding:
                EdgeInsets.only(left: indent > 0 ? 16.0 : 0, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('  -  ',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 14,
                        fontFamily: 'Outfit')),
                Expanded(
                  child: _inlineText(
                      line
                          .trimLeft()
                          .replaceFirst(RegExp(r'^[--\d]+[.\s]+'), ''),
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
        // Empty line â†’ spacing
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

  */

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

  // â”€â”€â”€ INPUT AREA â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildComposerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: _isProcessing ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.iceBlue.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
      ),
    );
  }

  Widget _buildPendingAttachmentSummary() {
    return Tooltip(
      message: _attachments.map((a) => a.name).join('\n'),
      child: InkWell(
        onTap: () => setState(() => _attachments.clear()),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _attachments.any((a) => a.isImage)
                    ? Icons.image_outlined
                    : Icons.graphic_eq_outlined,
                color: AppTheme.success,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '${_attachments.length}',
                style: const TextStyle(
                  color: AppTheme.success,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.close, color: AppTheme.success, size: 13),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final canSend =
        (_textCtrl.text.trim().isNotEmpty || _attachments.isNotEmpty) &&
            !_isProcessing;
    final hasFocus = _focusNode.hasFocus;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: hasFocus
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: hasFocus ? 18 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
              gradient: hasFocus
                  ? LinearGradient(
                      colors: [
                        AppTheme.iceBlue.withValues(alpha: 0.22),
                        Colors.white,
                      ],
                    )
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildComposerIconButton(
                  icon: Icons.image_outlined,
                  tooltip: 'Attach machine image',
                  onTap: _pickImageAttachment,
                ),
                const SizedBox(width: 4),
                _buildComposerIconButton(
                  icon: _isListening ? Icons.mic_rounded : Icons.mic_none,
                  tooltip: _isListening ? 'Stop recording' : 'Record prompt',
                  onTap: _toggleVoice,
                ),
                const SizedBox(width: 10),
                if (_attachments.isNotEmpty) ...[
                  _buildPendingAttachmentSummary(),
                  const SizedBox(width: 10),
                ],
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
                      hintText: 'Ask, record a prompt, or attach an image...',
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
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (canSend) _sendMessage(_textCtrl.text);
                    },
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: GestureDetector(
                    onTap: _isProcessing
                        ? _stopGenerating
                        : canSend
                            ? () => _sendMessage(_textCtrl.text)
                            : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isProcessing
                            ? AppTheme.error
                            : canSend
                                ? AppTheme.primary
                                : AppTheme.border,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                          _isProcessing ? Icons.stop : Icons.arrow_upward,
                          color: Colors.white,
                          size: 16),
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
