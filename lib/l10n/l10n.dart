import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Strings for code that has no BuildContext. Kept in sync with the app's
/// locale by MaterialApp.builder in main.dart.
class L10n {
  L10n._();

  static AppLocalizations current = lookupAppLocalizations(const Locale('en'));
}
