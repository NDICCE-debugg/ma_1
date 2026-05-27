# ma_1

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


##feautrers=> 1) dashboard -> real data from the db
2) Assets page -> crud functions
3)AI chat -> api intergraations
4) Comms -> notes as an addition
5) -> qr code scanner input, chat for dets
6) manuals -> as an independent window for file uploads, pdfs
7) auth credentials w firebase

## Android Google sign-in release checklist

Google sign-in on an installed APK only works when all three values match the
OAuth client configured in Firebase/Google Cloud:

- Android package name: `com.example.ma_1`
- APK signing certificate SHA-1/SHA-256
- Web OAuth client ID used as `serverClientId`

Production APKs must be signed with a stable release keystore, not the debug
keystore. Create it once and back it up securely:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v `
  -keystore android/app/upload-keystore.jks `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload
```

Copy `android/key.properties.example` to `android/key.properties` and fill in
the passwords used above. Then print the production fingerprints:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v `
  -keystore android/app/upload-keystore.jks `
  -alias upload
```

Add both SHA-1 and SHA-256 to the Android app in Google Cloud/Firebase if you
use native Google Sign-In. The current mobile auth path uses Supabase OAuth
redirects, so Supabase Auth must allow this mobile redirect URL:

```text
pulseauth://login-callback/
```

## Mobile backend URL

The Android APK cannot call `localhost` on your PC. For local testing, start the
Flask backend on the PC and build the APK with the PC's current LAN IP:

```powershell
flutter build apk --release --split-per-abi `
  --dart-define=PULSE_API_BASE_URL=http://172.16.30.18:5000/api
```

For production, deploy the backend behind HTTPS and build with that stable URL
instead of a private LAN IP.
