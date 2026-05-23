/// ──────────────────────────────────────────────────────────────────────────
/// App-wide configuration constants
///
/// HOW TO SET YOUR GEMINI API KEY:
///   1. Go to https://aistudio.google.com/app/apikey
///   2. Create or copy your key
///   3. Paste it as the value of [geminiApiKey] below
///   4. Save the file and hot restart the app
///
/// ⚠️  DO NOT commit this file to a public git repository with a real key.
///     Add `lib/utils/app_config.dart` to your .gitignore for production apps.
/// ──────────────────────────────────────────────────────────────────────────
class AppConfig {
  // ── PASTE YOUR GEMINI API KEY HERE ──────────────────────────────────────
  static const String geminiApiKey = 'AIzaSyDSTgR9pKapiXoJ3dqw1kv9aU69XN0QHlY';

  // Supabase (already configured, do not change)
  static const String supabaseUrl = 'https://awswkatcjffcsobusvic.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_JS_DyaON4AC8FoJMcEkOwg_6aYjl6d2';
}
