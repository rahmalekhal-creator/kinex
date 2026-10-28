import 'package:flutter/material.dart';

import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/widgets/kinex_app_bar.dart';
import 'package:reeducation/widgets/kinex_screen_background.dart';

import '../data/app_notification.dart';
import '../data/notifications_api.dart';
import '../data/unread_notifier.dart';
import '../notification_text.dart';

/// A notification about one patient, for their physiotherapist (no exercise / most reps incorrect / pain reported):
/// the facts behind it, loaded again from the server (still this physiotherapist's patient?), and two actions -
/// open the patient's file, or write to the patient with a suggested text that is NOT sent automatically.
class NotificationDetailPage extends StatefulWidget {
  final AppNotification notification;
  final NotificationsApi? api;

  /// Opens the patient's file (PhysioPatientDetailPage).
  final void Function(BuildContext context, int patientId, String patientName) onOpenPatient;

  /// Opens the conversation with the patient, [draft] already typed in the box.
  final void Function(BuildContext context, int patientAccountId, String patientName, String draft) onMessagePatient;

  const NotificationDetailPage({
    super.key,
    required this.notification,
    required this.onOpenPatient,
    required this.onMessagePatient,
    this.api,
  });

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  late final NotificationsApi _api = widget.api ?? UnreadNotifier.instance.api;
  Map<String, dynamic>? _ctx;
  NotificationsFailure? _error;

  AppNotification get n => widget.notification;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _ctx = null;
    });
    try {
      final c = await _api.context(n.id);
      if (mounted) setState(() => _ctx = c);
    } on NotificationsException catch (e) {
      if (mounted) setState(() => _error = e.reason);
    }
  }

  Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : const {};
  List<Map<String, dynamic>> _list(Object? v) =>
      v is List ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];
  int _int(Object? v) => int.tryParse('${v ?? ''}') ?? 0;

  String _draft(AppLocalizations l, String name) {
    final exercise = n.str('exercise_name');
    return switch (n.type) {
      'inactivity' => l.notifDraftInactivity(name, n.str('date')),
      'incorrect_reps' => l.notifDraftIncorrect(name, exercise),
      'pain_report' => l.notifDraftPain(name, exercise),
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: kinexAppBar(title: l.notifDetailTitle),
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
      final text = switch (_error!) {
        NotificationsFailure.forbidden => l.notifNoLongerAssigned,
        NotificationsFailure.notFound => l.notifUnavailable,
        NotificationsFailure.signedOut => l.notifSignedOut,
        _ => l.notifLoadError,
      };
      final canRetry = _error == NotificationsFailure.network || _error == NotificationsFailure.server;
      return ListView(padding: const EdgeInsets.all(24), children: [
        const Icon(Icons.info_outline_rounded, size: 44, color: Color(0xFF98A2B3)),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, key: const Key('notif_detail_error')),
        if (canRetry) Center(child: TextButton(onPressed: _load, child: Text(l.retry))),
      ]);
    }
    final c = _ctx;
    if (c == null) return const Center(child: CircularProgressIndicator());
    final patient = _map(c['patient']);
    final patientName = (patient['name'] ?? n.str('patient_name')).toString();
    final patientAccountId = _int(patient['account_id']);
    final color = NotificationText.color(n);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(NotificationText.icon(n), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(NotificationText.title(l, n), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(NotificationText.body(l, n)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        ...switch (n.type) {
          'inactivity' => _inactivity(l, c),
          'incorrect_reps' => _incorrect(l, c),
          'pain_report' => _pain(l, c),
          _ => const <Widget>[],
        },
        const SizedBox(height: 20),
        if (n.type != 'inactivity' || !n.resolved) ...[
          Text(l.notifDraftHint, style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
          const SizedBox(height: 8),
        ],
        Wrap(spacing: 12, runSpacing: 8, children: [
          ElevatedButton.icon(
            key: const Key('notif_message_patient'),
            onPressed: patientAccountId > 0
                ? () => widget.onMessagePatient(context, patientAccountId, patientName, _draft(l, patientName))
                : null,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: Text(l.notifMessagePatient),
          ),
          OutlinedButton.icon(
            key: const Key('notif_open_patient'),
            onPressed: () => widget.onOpenPatient(context, _int(patient['id']), patientName),
            icon: const Icon(Icons.manage_accounts_outlined),
            label: Text(l.notifOpenPatient),
          ),
        ]),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...children,
          ]),
        ),
      );

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(a)),
          const SizedBox(width: 8),
          Text(b, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );

  List<Widget> _inactivity(AppLocalizations l, Map<String, dynamic> c) {
    final prescribed = _list(c['prescribed']);
    final done = _list(c['done_that_day']);
    return [
      _section(l.notifDay, [Text((c['date'] ?? n.str('date')).toString())]),
      _section(l.notifPrescribed, [
        for (final p in prescribed)
          _row((p['name'] ?? '').toString(), l.notifSetsReps(_int(p['sets']), _int(p['reps']))),
      ]),
      _section(l.notifDoneThatDay, [
        if (done.isEmpty) Text(l.notifNothingRecorded),
        for (final d in done) _row((d['name'] ?? '').toString(), l.notifRepsDone(_int(d['reps_done']))),
      ]),
      if (n.resolved)
        Row(children: [
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF12B76A)),
          const SizedBox(width: 8),
          Expanded(child: Text(l.notifResumedSince)),
        ]),
    ];
  }

  List<Widget> _incorrect(AppLocalizations l, Map<String, dynamic> c) {
    final set = _map(c['set']);
    if (set.isEmpty) return [Text(l.notifUnavailable)];
    final unsure = _int(set['unsure']);
    final judged = _int(set['good']) + _int(set['mistakes']);
    final summary = (set['summary'] ?? '').toString();
    return [
      _section(l.notifSetResult, [
        _row(l.exercise, (set['exercise_name'] ?? '').toString()),
        _row(l.notifReportedAt, (set['created_at'] ?? '').toString()),
        _row(l.notifCorrectReps, '${_int(set['good'])}'),
        _row(l.notifIncorrectReps, '${_int(set['mistakes'])}'),
        _row(l.notifUnsureReps, '$unsure'),
        const SizedBox(height: 6),
        // confident verdicts only: reps the camera could not judge are reported apart, never as mistakes
        Text(unsure > 0 ? l.notifTrackingPartly(unsure) : l.notifTrackingConfirmed(judged),
            key: const Key('notif_tracking_note'), style: const TextStyle(fontSize: 13, color: Color(0xFF667085))),
      ]),
      if (summary.isNotEmpty) _section(l.notifAssistantNotes, [Text(summary)]),
    ];
  }

  List<Widget> _pain(AppLocalizations l, Map<String, dynamic> c) {
    final set = _map(c['set']);
    final report = _map(c['report']);
    final level = n.numberOrNull('pain_level') ?? (report['pain_level'] == null ? null : _int(report['pain_level']));
    final events = set.isNotEmpty ? _list(set['events']) : _list(n.data['events']);
    final notes = (report['notes'] ?? n.str('notes')).toString().trim();
    return [
      _section(l.notifPainRating, [
        _row(l.exercise, n.str('exercise_name')),
        _row(l.notifReportedAt, n.str('reported_at')),
        _row(l.notifPainRating, level == null ? l.notifPainNoRating : '$level/10'),
      ]),
      if (events.isNotEmpty)
        _section(l.notifPainDuringSet, [
          for (final e in events) ...[
            Text(l.notifPainEvent(
                (e['time'] ?? '').toString(), e['source'] == 'voice' ? l.reportSourceVoice : l.reportSourceButton)),
            if ((e['utterance'] ?? '').toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: Text(l.notifPatientWords((e['utterance'] ?? '').toString().trim()),
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
          ],
        ]),
      if (notes.isNotEmpty) _section(l.notifPatientNotes, [Text(notes)]),
      Text(l.notifPatientReportOnly, style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
    ];
  }
}
