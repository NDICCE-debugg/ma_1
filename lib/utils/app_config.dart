/// App-wide configuration constants.
///
/// Keep production secrets out of Flutter client bundles. Prefer passing values
/// through --dart-define for local experiments and backend-side secrets for
/// production integrations.
class AppConfig {
  // Local development Gemini key. Move this behind a backend proxy for production.
  static const String geminiApiKey = 'AIzaSyAfqaJHbMxoRtwUYjRv-rsGgaoGiIJHluc';
  static const String simulationModel = 'gemini-2.5-flash';

  // Paste your Google Chat Incoming Webhook URL here to enable live workspace alerts (Path A)
  static const bool enableGoogleChatApi =
      bool.fromEnvironment('ENABLE_GOOGLE_CHAT_API', defaultValue: false);
  static const String googleChatWebhookUrl =
      String.fromEnvironment('GOOGLE_CHAT_WEBHOOK_URL', defaultValue: '');

  // Google Chat API Configurations (Path B)
  // 1. Enter the target space resource name, e.g. 'spaces/AAAAi7X...'
  static const String googleChatSpaceName =
      String.fromEnvironment('GOOGLE_CHAT_SPACE_NAME', defaultValue: '');
  // 2. Enter the service account email, e.g. 'service-account@project.iam.gserviceaccount.com'
  static const String googleServiceAccountEmail =
      String.fromEnvironment('GOOGLE_SERVICE_ACCOUNT_EMAIL', defaultValue: '');
  // 3. Enter the service account private key in PEM format (starts with -----BEGIN PRIVATE KEY-----)
  static const String googleServiceAccountPrivateKey = String.fromEnvironment(
      'GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY',
      defaultValue: '');

  // Supabase (already configured, do not change)
  static const String supabaseUrl = 'https://awswkatcjffcsobusvic.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_JS_DyaON4AC8FoJMcEkOwg_6aYjl6d2';
}

