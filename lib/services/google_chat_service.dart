import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:ma_1/utils/app_config.dart';

/// Service to broadcast high-fidelity cards and alerts to Google Chat Spaces.
/// Supports both Incoming Webhooks (Path A) and full Google Chat API REST with
/// Service Account authentication via platform-safe JWT OAuth2 (Path B).
class GoogleChatService {
  static final GoogleChatService instance = GoogleChatService._init();
  GoogleChatService._init();

  /// Checks if the webhook pipeline (Path A) is configured
  bool get isConfiguredForWebhook =>
      AppConfig.googleChatWebhookUrl.isNotEmpty &&
      AppConfig.googleChatWebhookUrl.startsWith('https://chat.googleapis.com/');

  /// Checks if the Google Chat API pipeline (Path B) is configured
  bool get isConfiguredForApi =>
      AppConfig.googleServiceAccountEmail.isNotEmpty &&
      AppConfig.googleServiceAccountPrivateKey.isNotEmpty &&
      AppConfig.googleChatSpaceName.isNotEmpty;

  /// Returns true if either delivery pipeline is configured
  bool get isConfigured => isConfiguredForWebhook || isConfiguredForApi;

  /// Performs secure, server-less OAuth2 authentication with Google token endpoints
  /// using signed JWT assertions (RS256). Works fully on Flutter Web (Chrome).
  Future<String?> _getAccessToken() async {
    final email = AppConfig.googleServiceAccountEmail.trim();
    final rawKey = AppConfig.googleServiceAccountPrivateKey.trim();

    if (email.isEmpty || rawKey.isEmpty) return null;

    try {
      // Normalize Escaped/Raw PEM formatting
      final formattedPrivateKey = rawKey.replaceAll(r'\n', '\n');

      final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final exp = iat + 3600; // 1 hour token validity

      final jwt = JWT(
        {
          'iss': email,
          'scope': 'https://www.googleapis.com/auth/chat.bot https://www.googleapis.com/auth/chat.messages.readonly https://www.googleapis.com/auth/chat.messages',
          'aud': 'https://oauth2.googleapis.com/token',
          'exp': exp,
          'iat': iat,
        },
      );

      final key = RSAPrivateKey(formattedPrivateKey);
      final assertion = jwt.sign(key, algorithm: JWTAlgorithm.RS256);

      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': assertion,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token']?.toString();
      } else {
        debugPrint('[GOOGLE CHAT AUTH ERROR] Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[GOOGLE CHAT AUTH EXCEPTION] Error: $e');
      return null;
    }
  }

  /// Fetches the last 20 messages from the configured Google Chat Space (Path B)
  Future<List<Map<String, dynamic>>> fetchMessages() async {
    if (!isConfiguredForApi) return [];

    final token = await _getAccessToken();
    if (token == null) {
      debugPrint('[GOOGLE CHAT API ERROR] - Could not retrieve access token for fetching messages');
      return [];
    }

    final spaceName = AppConfig.googleChatSpaceName.trim();
    final url = 'https://chat.googleapis.com/v1/$spaceName/messages?pageSize=20';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> messagesList = data['messages'] ?? [];
        
        return messagesList.map((m) {
          final sender = m['sender'] ?? {};
          final senderName = sender['displayName']?.toString() ?? 'Clinical Team Member';
          final text = m['text']?.toString() ?? (m['cardsV2'] != null ? 'Actionable Card Broadcast' : '');
          final createTime = m['createTime']?.toString() ?? DateTime.now().toUtc().toIso8601String();
          final messageId = m['name']?.toString() ?? '';
          
          final isMe = sender['email']?.toString() == AppConfig.googleServiceAccountEmail;

          return {
            'id': messageId,
            'sender_id': isMe ? 'me' : 'gchat-user',
            'sender_name': senderName,
            'message_text': text,
            'timestamp': createTime,
            'delivery_state': 'sent',
          };
        }).toList().reversed.toList(); // Chronological order
      } else {
        debugPrint('[GOOGLE CHAT API ERROR] - Failed to fetch messages. Status: ${response.statusCode}, Body: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('[GOOGLE CHAT API EXCEPTION] - Failed to fetch messages. Error: $e');
      return [];
    }
  }

  /// Dispatches a simple text message to Google Chat
  Future<bool> sendTextMessage(String text) async {
    final payload = {'text': text};
    return _dispatchPayload(payload, 'Simple Text Message');
  }

  /// Dispatches an emergency triage card to Google Chat when a critical fault is logged
  Future<bool> sendEmergencyPageCard({
    required String assetModel,
    required String serialNumber,
    required String wardLocation,
    required String faultDescription,
    required String severity,
    required String loggedBy,
  }) async {
    final severityColor = severity.toUpperCase() == 'CRITICAL' || severity.toUpperCase() == 'HIGH'
        ? '#E11D48' // High-contrast Red
        : '#D97706'; // High-contrast Amber

    final cardPayload = {
      'cardsV2': [
        {
          'cardId': 'clinical_emergency_dispatch',
          'card': {
            'header': {
              'title': '🚨 CLINICAL TRIAGE EMERGENCY PAGE',
              'subtitle': 'Critical Medical Equipment Failure Alert',
              'imageUrl': 'https://img.icons8.com/color/96/alarm.png',
              'imageType': 'CIRCLE',
            },
            'sections': [
              {
                'header': 'Asset & Dispatch Details',
                'widgets': [
                  {
                    'decoratedText': {
                      'topLabel': 'DEVICE MODEL',
                      'text': assetModel,
                      'startIcon': {'knownIcon': 'DESCRIPTION'},
                    }
                  },
                  {
                    'decoratedText': {
                      'topLabel': 'SERIAL NUMBER',
                      'text': serialNumber,
                      'startIcon': {'knownIcon': 'TICKET'},
                    }
                  },
                  {
                    'decoratedText': {
                      'topLabel': 'WARD LOCATION',
                      'text': wardLocation,
                      'startIcon': {'knownIcon': 'MAP_PIN'},
                    }
                  },
                  {
                    'decoratedText': {
                      'topLabel': 'FAULT DESCRIPTION',
                      'text': faultDescription,
                      'startIcon': {'knownIcon': 'HOTEL'},
                    }
                  },
                  {
                    'decoratedText': {
                      'topLabel': 'SEVERITY STATUS',
                      'text': '<font color="$severityColor"><b>${severity.toUpperCase()}</b></font>',
                      'startIcon': {'knownIcon': 'FLAG'},
                    }
                  },
                  {
                    'decoratedText': {
                      'topLabel': 'LOGGED BY',
                      'text': loggedBy,
                      'startIcon': {'knownIcon': 'PERSON'},
                    }
                  },
                ],
              },
              {
                'widgets': [
                  {
                    'buttonList': {
                      'buttons': [
                        {
                          'text': 'LAUNCH REPAIR COCKPIT',
                          'onClick': {
                            'openLink': {
                              'url': 'http://localhost:3000/#/cockpit',
                            }
                          }
                        }
                      ]
                    }
                  }
                ]
              }
            ],
          },
        }
      ]
    };

    return _dispatchPayload(cardPayload, 'Clinical Emergency Page Card');
  }

  /// Dispatches a Google Meet invitation card to Google Chat when a consultation is scheduled
  Future<bool> sendMeetingCard({
    required String topic,
    required String time,
    required String host,
    required String joinUrl,
  }) async {
    final cardPayload = {
      'cardsV2': [
        {
          'cardId': 'clinical_tele_consultation',
          'card': {
            'header': {
              'title': '📅 CLINICAL CONSULTATION SCHEDULED',
              'subtitle': 'Secure Tele-health Consultation Invitation',
              'imageUrl': 'https://img.icons8.com/color/96/video-call.png',
              'imageType': 'CIRCLE',
            },
            'sections': [
              {
                'header': 'Agenda & Details',
                'widgets': [
                  {
                    'decoratedText': {
                      'topLabel': 'CONSULTATION TOPIC',
                      'text': topic,
                      'startIcon': {'knownIcon': 'MEMBERSHIP'},
                    }
                  },
                  {
                    'decoratedText': {
                      'topLabel': 'TIME STATUS',
                      'text': time,
                      'startIcon': {'knownIcon': 'CLOCK'},
                    }
                  },
                  {
                    'decoratedText': {
                      'topLabel': 'HOST COORDINATOR',
                      'text': host,
                      'startIcon': {'knownIcon': 'PERSON'},
                    }
                  },
                ],
              },
              {
                'widgets': [
                  {
                    'buttonList': {
                      'buttons': [
                        {
                          'text': 'JOIN VIDEO MEETING ROOM',
                          'onClick': {
                            'openLink': {
                              'url': joinUrl,
                            }
                          }
                        }
                      ]
                    }
                  }
                ]
              }
            ],
          },
        }
      ]
    };

    return _dispatchPayload(cardPayload, 'Consultation Meeting Invitation Card');
  }

  /// Core helper to serialize and POST the JSON payload to the configured endpoint
  Future<bool> _dispatchPayload(Map<String, dynamic> payload, String debugName) async {
    final jsonString = jsonEncode(payload);

    if (!isConfigured) {
      debugPrint('============================================================');
      debugPrint('[MOCK GOOGLE CHAT INTEGRATION] - Payload for "$debugName":');
      debugPrint(const JsonEncoder.withIndent('  ').convert(payload));
      debugPrint('============================================================');
      return true; // Return true as mock success
    }

    if (isConfiguredForWebhook) {
      // PATH A: Incoming Webhook delivery pipeline
      try {
        final response = await http.post(
          Uri.parse(AppConfig.googleChatWebhookUrl),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonString,
        );

        if (response.statusCode == 200) {
          debugPrint('Successfully dispatched webhook: $debugName');
          return true;
        } else {
          debugPrint('Failed to dispatch webhook: $debugName, Status: ${response.statusCode}');
          debugPrint('Response body: ${response.body}');
          return false;
        }
      } catch (e) {
        debugPrint('Exception dispatching webhook: $debugName. Error: $e');
        return false;
      }
    } else {
      // PATH B: Full Google Chat API delivery pipeline via Service Account OAuth2
      final token = await _getAccessToken();
      if (token == null) {
        debugPrint('[GOOGLE CHAT API ERROR] - Could not retrieve access token for "$debugName"');
        return false;
      }

      final spaceName = AppConfig.googleChatSpaceName.trim();
      final url = 'https://chat.googleapis.com/v1/$spaceName/messages';

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token',
          },
          body: jsonString,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('Successfully dispatched to Google Chat API: $debugName');
          return true;
        } else {
          debugPrint('Failed to dispatch to Google Chat API: $debugName, Status: ${response.statusCode}');
          debugPrint('Response body: ${response.body}');
          return false;
        }
      } catch (e) {
        debugPrint('Exception dispatching to Google Chat API: $debugName. Error: $e');
        return false;
      }
    }
  }
}
