import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ma_1/utils/app_config.dart';

class GeminiAttachment {
  final String name;
  final String mimeType;
  final Uint8List bytes;

  const GeminiAttachment({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  bool get isImage => mimeType.startsWith('image/');
  bool get isAudio => mimeType.startsWith('audio/');
}

/// Clinical Gemini Service
/// Wraps google_generative_ai with a biomedical technician system prompt,
/// conversation history, and streaming support.
class GeminiService {
  static final GeminiService instance = GeminiService._init();
  GeminiService._init();

  GenerativeModel? _model;
  ChatSession? _chat;

  // System instruction tuned for biomedical equipment technicians
  static const String _systemPrompt = '''
You are Pulse AI, an expert clinical engineering assistant embedded in a hospital
biomedical equipment management system. You assist qualified biomedical equipment
technicians (BMETs) and clinical engineers with:

- Troubleshooting medical device faults and error codes
- Step-by-step servicing and preventive maintenance procedures
- Interpreting alarm codes, waveform anomalies, and sensor readings
- ICU ventilator management (Aeonmed VG70, Drager Evita V500, Mindray A5, WATO EX-35)
- Patient monitoring systems, infusion pumps, defibrillators, and anaesthetic machines
- Spare parts identification and supplier recommendations
- Compliance with IEC 60601, HTM 08-01, and local hospital technical standards
- Calibration procedures and post-repair verification checklists

RULES:
- Respond in clear, technical but readable English suited for a trained BMET
- Always structure complex answers with numbered steps or bullet points
- For drug dosages or patient-facing clinical decisions, defer to a physician
- If unsure, say so - never hallucinate specifications or part numbers
- Keep responses concise unless the user explicitly asks for detail
- When giving maintenance steps, always include safety warnings first
- When manual context is provided, ground the answer in that context and cite the
  uploaded manual source titles. If the manual context is insufficient, state the
  gap clearly instead of inventing values, limits, or part numbers.
''';

  bool get isConfigured =>
      AppConfig.geminiApiKey.isNotEmpty &&
      AppConfig.geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE';

  /// Initialises the model and starts a new chat session.
  void _ensureInitialized() {
    if (_model != null) return;
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: AppConfig.geminiApiKey,
      systemInstruction: Content.system(_systemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.4,
        maxOutputTokens: 2048,
        topP: 0.95,
      ),
    );
    _chat = _model!.startChat();
  }

  /// Starts a fresh conversation (clears history).
  void newChat() {
    _chat = _model?.startChat();
  }

  /// Sends a message and returns the full response text.
  /// Throws [GeminiException] on API errors.
  Future<String> sendMessage(
    String userMessage, {
    List<GeminiAttachment> attachments = const [],
  }) async {
    if (!isConfigured) {
      throw GeminiException(
        'Gemini API key not configured. '
        'Open lib/utils/app_config.dart and paste your key into geminiApiKey.',
      );
    }
    _ensureInitialized();

    try {
      final response = await _chat!.sendMessage(
        _buildUserContent(userMessage, attachments),
      );
      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        return 'No response received. Please try rephrasing your question.';
      }
      return text.trim();
    } on GenerativeAIException catch (e) {
      throw GeminiException('Gemini API error: ${e.message}');
    } catch (e) {
      throw GeminiException('Unexpected error: $e');
    }
  }

  /// Streams the response token-by-token.
  Stream<String> streamMessage(
    String userMessage, {
    List<GeminiAttachment> attachments = const [],
  }) async* {
    if (!isConfigured) {
      throw GeminiException(
        'Gemini API key not configured. '
        'Open lib/utils/app_config.dart and paste your key.',
      );
    }
    _ensureInitialized();

    try {
      final stream =
          _chat!.sendMessageStream(_buildUserContent(userMessage, attachments));
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) yield text;
      }
    } on GenerativeAIException catch (e) {
      throw GeminiException('Gemini API error: ${e.message}');
    } catch (e) {
      throw GeminiException('Unexpected error: $e');
    }
  }

  Content _buildUserContent(
    String userMessage,
    List<GeminiAttachment> attachments,
  ) {
    if (attachments.isEmpty) return Content.text(userMessage);

    return Content.multi([
      TextPart(userMessage),
      for (final attachment in attachments)
        DataPart(attachment.mimeType, attachment.bytes),
    ]);
  }
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => 'GeminiException: $message';
}
