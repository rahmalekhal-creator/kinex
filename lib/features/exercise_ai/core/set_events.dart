/// App-wide signal that a live set was saved on the server, so screens that show progress (the patient's home:
/// progress bar, exercise list, history) re-fetch at once instead of waiting for the next login.
library;

import 'package:flutter/foundation.dart';

class SetEvents {
  SetEvents._();

  /// Incremented each time a set has been saved (the server answered): listeners re-fetch.
  static final ValueNotifier<int> saved = ValueNotifier<int>(0);

  static void notifySaved() => saved.value++;
}
