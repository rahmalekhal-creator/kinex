import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_notification.dart';
import 'notifications_api.dart';

/// The unread count shown on the bells. Polls the server (there is no push channel: see NOTIFICATIONS.md) while at
/// least one bell is on screen and the app is in the foreground, and is updated at once by the notifications page.
class UnreadNotifier extends ValueNotifier<UnreadCounts> with WidgetsBindingObserver {
  UnreadNotifier._() : super(UnreadCounts.zero);
  static final UnreadNotifier instance = UnreadNotifier._();

  static const pollEvery = Duration(seconds: 30);

  NotificationsApi api = NotificationsApi();
  Timer? _timer;
  int _users = 0;
  bool _foreground = true;
  bool _busy = false;

  void attach() {
    if (_users++ == 0) {
      WidgetsBinding.instance.addObserver(this);
      _schedule();
      refresh();
    }
  }

  void detach() {
    if (--_users <= 0) {
      _users = 0;
      _timer?.cancel();
      _timer = null;
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = _foreground && _users > 0 ? Timer.periodic(pollEvery, (_) => refresh()) : null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _schedule();
    if (_foreground) refresh();
  }

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      value = await api.count();
    } on NotificationsException {
      // keep the last known count; the page shows the error when opened
    } finally {
      _busy = false;
    }
  }

  void set(UnreadCounts counts) => value = counts;

  /// Logging out: no count for the next account until its first refresh.
  void reset() => value = UnreadCounts.zero;
}
