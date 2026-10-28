import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';

const _prefsKey = 'app_language';

/// Languages offered in the language picker, with their native names.
const kLanguageNames = <String, String>{
  'en': 'English',
  'fr': 'Français',
  'ar': 'العربية',
};

/// Picks the starting language: the saved choice, else the device language
/// when supported, else English.
Locale resolveInitialLocale(String? savedCode) {
  final supported = AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
  if (savedCode != null && supported.contains(savedCode)) {
    return Locale(savedCode);
  }
  final device = PlatformDispatcher.instance.locale.languageCode;
  return Locale(supported.contains(device) ? device : 'en');
}

class LocaleController extends StateNotifier<Locale> {
  LocaleController(super.initial);

  Future<void> setLanguage(String code) async {
    if (code == state.languageCode) return;
    state = Locale(code);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {
      // Persisting is best-effort; the language still changes for this session.
    }
  }
}

/// Overridden in main() with the locale restored from storage.
final localeProvider = StateNotifierProvider<LocaleController, Locale>(
  (ref) => LocaleController(resolveInitialLocale(null)),
);

Future<Locale> loadSavedLocale() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return resolveInitialLocale(prefs.getString(_prefsKey));
  } catch (_) {
    return resolveInitialLocale(null);
  }
}
