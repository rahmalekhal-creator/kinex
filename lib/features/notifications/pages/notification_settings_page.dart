import 'package:flutter/material.dart';

import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/widgets/kinex_app_bar.dart';
import 'package:reeducation/widgets/kinex_screen_background.dart';

import '../data/notifications_api.dart';
import '../data/unread_notifier.dart';

/// Which notification types the account receives, saved on the server: a type turned off is not created at all
/// (nothing is stored for it, and turning it back on does not bring back what happened meanwhile).
class NotificationSettingsPage extends StatefulWidget {
  final NotificationsApi? api;

  const NotificationSettingsPage({super.key, this.api});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  late final NotificationsApi _api = widget.api ?? UnreadNotifier.instance.api;
  Map<String, bool>? _prefs;
  NotificationsFailure? _error;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final p = await _api.prefs();
      if (mounted) setState(() => _prefs = p);
    } on NotificationsException catch (e) {
      if (mounted) setState(() => _error = e.reason);
    }
  }

  Future<void> _set(String type, bool on) async {
    final l = context.l10n;
    if (!on && type == 'pain_report') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l.notifPrefPainOffTitle),
          content: Text(l.notifPrefPainOffBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(l.notifPrefTurnOff)),
          ],
        ),
      );
      if (ok != true) return;
    }
    final before = _prefs!;
    setState(() {
      _prefs = {...before, type: on};
      _saving.add(type);
    });
    try {
      final p = await _api.setPref(type, on);
      if (mounted) setState(() => _prefs = p);
    } on NotificationsException {
      if (!mounted) return;
      setState(() => _prefs = before);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.notifLoadError)));
    } finally {
      if (mounted) setState(() => _saving.remove(type));
    }
  }

  static (String, String, IconData) _describe(AppLocalizations l, String type) => switch (type) {
        'pain_report' => (l.notifCategoryPain, l.notifPrefPainHint, Icons.healing_rounded),
        'incorrect_reps' => (l.notifPrefIncorrect, l.notifPrefIncorrectHint, Icons.rule_rounded),
        'inactivity' => (l.notifPrefInactivity, l.notifPrefInactivityHint, Icons.event_busy_rounded),
        'message' => (l.notifCategoryMessages, l.notifPrefMessageHint, Icons.chat_bubble_outline_rounded),
        'routine_update' => (l.notifCategoryRoutine, '', Icons.fitness_center_rounded),
        _ => (type, '', Icons.notifications_none_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: kinexAppBar(title: l.notifSettingsTitle),
      body: KinexScreenBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _body(l),
          ),
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l) {
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        Text(_error == NotificationsFailure.signedOut ? l.notifSignedOut : l.notifLoadError, textAlign: TextAlign.center),
        if (_error != NotificationsFailure.signedOut) Center(child: TextButton(onPressed: _load, child: Text(l.retry))),
      ]);
    }
    final prefs = _prefs;
    if (prefs == null) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(l.notifSettingsIntro, style: const TextStyle(color: Color(0xFF667085))),
        const SizedBox(height: 12),
        for (final e in prefs.entries)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Builder(builder: (context) {
              final (title, hint, icon) = _describe(l, e.key);
              return SwitchListTile(
                key: Key('pref_${e.key}'),
                secondary: Icon(icon),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: hint.isEmpty ? null : Text(hint),
                value: e.value,
                onChanged: _saving.contains(e.key) ? null : (v) => _set(e.key, v),
              );
            }),
          ),
      ],
    );
  }
}
