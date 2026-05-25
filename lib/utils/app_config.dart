/// App-wide configuration constants.
///
/// Keep production secrets out of Flutter client bundles. Prefer passing values
/// through --dart-define for local experiments and backend-side secrets for
/// production integrations.
class AppConfig {
  // Never ship Gemini keys in Flutter. AI calls must go through the backend.
  static const String geminiApiKey = '';
  static const String simulationModel = 'gemini-2.5-flash';

  // Google Chat credentials are backend-only. Do not compile webhooks or service
  // account material into Flutter clients.
  static const bool enableGoogleChatApi = false;
  static const String googleChatWebhookUrl = '';
  static const String googleChatSpaceName = '';
  static const String googleServiceAccountEmail = '';
  static const String googleServiceAccountPrivateKey = '';

  // Supabase (already configured, do not change)
  static const String supabaseUrl = 'https://awswkatcjffcsobusvic.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_JS_DyaON4AC8FoJMcEkOwg_6aYjl6d2';
}
