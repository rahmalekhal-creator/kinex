/// ─────────────────────────────────────────────────────────────────────────────
/// Kinex - Server configuration
///
/// Windows / web     → WAMP on this PC:  http://localhost/reed/
/// Android over USB  → http://127.0.0.1:8080/reed/, tunnelled to the PC's
///                     port 80. Run this once each time the phone is plugged in:
///                       adb reverse tcp:8080 tcp:80
///
/// To use another server (e.g. the PC's Wi-Fi IP, without a cable), pass:
///   flutter run --dart-define=SERVER_URL=http://192.168.1.X/reed/
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/foundation.dart';

const String _serverUrlOverride = String.fromEnvironment('SERVER_URL');

String get kServerBaseUrl {
  if (_serverUrlOverride.isNotEmpty) {
    return _serverUrlOverride.endsWith('/') ? _serverUrlOverride : '$_serverUrlOverride/';
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://127.0.0.1:8080/reed/';
  }
  return 'http://localhost/reed/';
}
