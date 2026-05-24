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
  static const String geminiApiKey = 'AIzaSyAfqaJHbMxoRtwUYjRv-rsGgaoGiIJHluc';
  static const String simulationModel = 'gemini-2.5-flash';

  // Paste your Google Chat Incoming Webhook URL here to enable live workspace alerts (Path A)
  static const String googleChatWebhookUrl = '';

  // Google Chat API Configurations (Path B)
  // 1. Enter the target space resource name, e.g. 'spaces/AAAAi7X...'
  static const String googleChatSpaceName = 'spaces/AAQAKxT7NtU';
  // 2. Enter the service account email, e.g. 'service-account@project.iam.gserviceaccount.com'
  static const String googleServiceAccountEmail =
      'medass@michael-ragu-451620.iam.gserviceaccount.com';
  // 3. Enter the service account private key in PEM format (starts with -----BEGIN PRIVATE KEY-----)
  static const String googleServiceAccountPrivateKey =
      '-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCyQ4Pmqu840avR\nngv7Srob/qzOkTSsggCKNSJdq8Pz9e7yTwT8WBzV3b+4uZG55oqZXU64FF9+o7Vo\nrGh1qKbuFpeRDf/d5OUujQVAQPN+eai/hzFwLtydyQoqnZVPN7cK/8nl+2cengOB\nRY6dCn5BsseSHPd9QMcRLHsoaeLMJGUM+zZE0EcS78bfsh9JwnMDJo4bef/yAk7/\nsdqqetJNLzNRYCHKSZRLk7th5KVZVE5c8nET+0zpShuCf9Ozn1aX0ZmxnXWpuvQx\nO1sodfkNTk/NvI5BV1ej68Ys9+TZUH4RxsEWXRVyUj4gV8/dOXtOWcIPzTpgOxHX\nzAo/zOMVAgMBAAECggEACc5G8ihS8mguMGCmPhN1O1b+AHriT97y0qdrlYV+SOwt\nUazhFFRweZ8yDaI/jt9MnnUQgHW2bwvoTbK2KEq3q/8YJUWE3prZtH7TXB52hm2A\nx9BS+t3JCvDlG0UB0pK5AeTiIUF8AaYlgTXnS2IpYcnIypPHVV9708kDmUyBykLa\ntWaVLAbAvE7EbJA0Ek9Wm1pRb+0PTh0OU48gMbpUNUiZtkFm6bIon7S5qnH2vz1R\ndTzg+ddJtCo3YXCscvH0LD1Tdvyyclj4l6sg2vXtqtf/T1pGAcfbuI7Z90VRR1RZ\nUquEmAUtqllocJEwuW8vFEVweXyE39CACIQeCLBPXQKBgQDibzB8ocnrc8etLn0q\nOWcZrfJdLepWAPuC9xFgda29xj6ad/2TIEiDqU7feR44BAUh0vF2oTSGt8wk7CxP\nNadC/A0xngTWjkOGKE9luW7wBTHIL7fK/Ob4zJOt9HZE8zsvYATfnxbXRiM5H33h\nrP8Rj0mA3H+bVy4Xx3c22VTlrwKBgQDJiiv4uUHP75P8xEPA+ay8NEJolZzI5AFw\nmNI0IJitccqtPW749nrB9i5SWJM2o6GkFalVb2uONA3d5jYgUg4C1fZHPx2GrQMv\nyFH3am1R1e3vRUhXUxO8DQ9XMzs2VAl5FmSxkLaJMgBhG7hkTw3aDkbPcZTkZA/m\nLdyiM8/4ewKBgQDKUktisTU4WqVpyoYv+kZzHYfXVjVyT0JsDNLL+5oYXVCGuPws\nP8ZLTjaZWyFzL7ReOptiQjwqu4N+4j/dLrWbFpe7Y9Qy2b7f2pjG7d+AO0P1+R0i\nFMNUP4cdAbfDeAnEFOmF3iKMi7DhU5Ao22i1ifBFYb/rTwRyXtnYemxvJQKBgBNo\nWdmmxV6nvIF/yOKBaI/rHGYD2khCJJ1aKgvZA7rYFWNfYhtZaPLaqRVG8E43ra4m\nY9sVUq8r9hXjQF0WacD+J6wuuMIqUP899B62Qfa6eiIrcs7t8h2OyGZmSZJuv0bI\n0EOFIv7NMNopGDWYo0XXUBxT3LmtpRZOXkvEX4eXAoGBAIf/Ku+JULXkrhDYgT9I\nq+aYT70sU51Zm5h5dhoVPVWjeHURdcn4g9IbuuV4E/UcGW30Twm/x6BoI+A4FxB5\nUa+K2N9KZZ7dAXCViwJjnRpyn4SEfbn1D6tXYP5efhRAh0f7sf52M9os3ztadBtO\n7V+qoZw+jfUBFzZlB/CxrIKW\n-----END PRIVATE KEY-----\n';

  // Supabase (already configured, do not change)
  static const String supabaseUrl = 'https://awswkatcjffcsobusvic.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_JS_DyaON4AC8FoJMcEkOwg_6aYjl6d2';
}
