import 'package:flutter/foundation.dart' show kDebugMode;

// lib/config.dart
// CHANGED: production default is now the deployed Render backend; debug
// builds (flutter run, IDE debug) still default to localhost so local dev
// is unaffected. --dart-define=API_BASE_URL=... always wins over both.
//   flutter run --dart-define=API_BASE_URL=https://daily-backend-srmr.onrender.com/api
//   flutter build apk --dart-define=API_BASE_URL=https://daily-backend-srmr.onrender.com/api
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: kDebugMode
      ? 'http://localhost:3001/api'
      : 'https://daily-backend-srmr.onrender.com/api',
);
