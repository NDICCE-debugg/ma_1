import 'dart:convert';
import 'dart:typed_data';
import 'package:ma_1/services/api_client.dart';

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

  bool get isConfigured => true;

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

  /// Clear the model and chat session to force re-initialisation when key changes
  void resetModel() {}

  /// Starts a fresh conversation (clears history).
  void newChat() {}

  /// Sends a message and returns the full response text.
  /// Throws [GeminiException] on API errors.
  Future<String> sendMessage(
    String userMessage, {
    List<GeminiAttachment> attachments = const [],
  }) async {
    try {
      final response = await ApiClient.instance.post('/gemini/generate', {
        'query': userMessage,
        'system_instruction': _systemPrompt,
        'attachments': [
          for (final attachment in attachments)
            {
              'name': attachment.name,
              'mime_type': attachment.mimeType,
              'data': base64Encode(attachment.bytes),
            }
        ],
      });
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        if (response.statusCode == 503 || body['retryable'] == true) {
          throw GeminiException(
            body['error']?.toString() ??
                'Pulse AI is temporarily busy. Please retry in a moment.',
          );
        }
        throw GeminiException(body['error']?.toString() ?? 'Backend AI error');
      }
      final text = body['answer']?.toString().trim();
      if (text == null || text.isEmpty) {
        return 'No response received. Please try rephrasing your question.';
      }
      if (text.startsWith('GEMINI UPLINK SECURED') || text.contains('Awaiting GEMINI_API_KEY')) {
        throw GeminiException('Gemini API key is not configured.');
      }
      return text;
    } on AuthRequiredException catch (e) {
      throw GeminiException(e.message);
    } on GeminiException {
      rethrow;
    } catch (e) {
      throw GeminiException('Unexpected error: $e');
    }
  }

  /// Streams the response token-by-token.
  Stream<String> streamMessage(
    String userMessage, {
    List<GeminiAttachment> attachments = const [],
  }) async* {
    final text = await sendMessage(userMessage, attachments: attachments);
    final parts = RegExp(r'\S+\s*').allMatches(text).map((m) => m.group(0)!);
    final buffer = StringBuffer();
    var count = 0;
    for (final part in parts) {
      buffer.write(part);
      count++;
      if (count >= 10) {
        yield buffer.toString();
        buffer.clear();
        count = 0;
      }
    }
    if (buffer.isNotEmpty) yield buffer.toString();
  }
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => 'GeminiException: $message';
}
