// Notification center, app side: parsing, the API client (token, errors), the page (states, read / mark all,
// categories, pagination) and the physiotherapist's detail page (re-checked access, draft never sent).
// The server is replaced by an in-memory stand-in of reed/notifications_api.php; the real backend is tested by
// tool/test_notifications.py against the database.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reeducation/features/notifications/data/app_notification.dart';
import 'package:reeducation/features/notifications/data/notifications_api.dart';
import 'package:reeducation/features/notifications/data/unread_notifier.dart';
import 'package:reeducation/features/notifications/notification_text.dart';
import 'package:reeducation/features/notifications/pages/notification_detail_page.dart';
import 'package:reeducation/features/notifications/pages/notification_settings_page.dart';
import 'package:reeducation/features/notifications/pages/notifications_page.dart';
import 'package:reeducation/l10n/app_localizations_en.dart';
import 'package:reeducation/l10n/l10n.dart';

Widget _app(Widget child) => ProviderScope(
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          L10n.current = AppLocalizations.of(context);
          return child!;
        },
        home: child,
      ),
    );

Map<String, dynamic> _n(int id, String type, String category,
        {int priority = 0, bool read = false, Map<String, dynamic> data = const {}, String at = '2026-10-13 10:00:00'}) =>
    {
      'id': id,
      'type': type,
      'category': category,
      'priority': priority,
      'title': 'server title $id',
      'body': 'server body $id',
      'data': data,
      'created_at': at,
      'read': read,
      'resolved': false,
    };

/// In-memory notifications_api.php: same parameters, same answers, same status codes.
class FakeServer {
  final List<Map<String, dynamic>> items;
  final requests = <http.Request>[];
  int failNext = 0;
  String? failAction; // only this action fails (null: any)
  int contextStatus = 200;
  Map<String, dynamic> contextBody = const {};
  final prefs = <String, bool>{'pain_report': true, 'incorrect_reps': true, 'inactivity': true, 'message': true};

  FakeServer(this.items);

  Map<String, dynamic> _counts() {
    final by = {for (final c in UnreadCounts.categories) c: 0};
    for (final n in items.where((n) => n['read'] != true)) {
      by[n['category'] as String] = by[n['category']]! + 1;
    }
    return {'unread': by.values.fold<int>(0, (a, b) => a + b), 'unread_by_category': by};
  }

  late final client = MockClient((r) async {
    requests.add(r);
    if (r.headers['X-Auth-Token'] != 'tok') return http.Response('{"error":true}', 401);
    final q = r.method == 'GET' ? r.url.queryParameters : Uri.splitQueryString(r.body);
    if (failNext > 0 && (failAction == null || failAction == q['action'])) {
      failNext--;
      return http.Response('oops', 500);
    }
    Map<String, dynamic> out;
    switch (q['action']) {
      case 'list':
        final cat = q['category'] ?? 'all';
        final sel = items.where((n) => cat == 'all' || n['category'] == cat).toList();
        final page = int.parse(q['page'] ?? '1'), limit = int.parse(q['limit'] ?? '20');
        final slice = sel.skip((page - 1) * limit).take(limit).toList();
        out = {
          'items': slice,
          'has_more': sel.length > page * limit,
          'server_now': '2026-10-13 10:05:00',
          ..._counts(),
        };
      case 'count':
        out = _counts();
      case 'read':
        final n = items.where((n) => n['id'] == int.parse(q['id']!));
        if (n.isEmpty) return http.Response('{"error":true}', 404);
        n.first['read'] = true;
        out = _counts();
      case 'read_all':
        for (final n in items) {
          if (q['category'] == 'all' || n['category'] == q['category']) n['read'] = true;
        }
        out = _counts();
      case 'prefs':
        out = {'prefs': prefs};
      case 'set_pref':
        prefs[q['type']!] = q['enabled'] == '1';
        out = {'prefs': prefs};
      case 'context':
        return http.Response(json.encode(contextBody), contextStatus);
      default:
        return http.Response('{"error":true}', 400);
    }
    return http.Response(json.encode({'error': false, ...out}), 200);
  });

  NotificationsApi api({String? token = 'tok'}) => NotificationsApi(client: client, baseUrl: 'http://x/', token: () => token);
}

void main() {
  final l = AppLocalizationsEn();

  group('model', () {
    test('parses a notification and the unread counts', () {
      final n = AppNotification.fromJson(_n(5, 'pain_report', 'pain', priority: 2, data: {'pain_level': '7', 'patient_name': 'Ali'}));
      expect(n.id, 5);
      expect(n.isUrgent, isTrue);
      expect(n.isAboutPatient, isTrue);
      expect(n.numberOrNull('pain_level'), 7);
      expect(n.createdAt, DateTime(2026, 10, 13, 10));
      final c = UnreadCounts.fromJson({'unread': 3, 'unread_by_category': {'pain': 2, 'messages': 1}});
      expect(c.of('all'), 3);
      expect(c.of('pain'), 2);
      expect(c.of('routine'), 0);
    });

    test('text in the user language, from the facts (not the server sentence)', () {
      AppNotification n(String type, String cat, Map<String, dynamic> d) => AppNotification.fromJson(_n(1, type, cat, data: d));
      expect(NotificationText.title(l, n('message', 'messages', {'sender_name': 'Dr Sara'})), 'New message from Dr Sara');
      expect(NotificationText.body(l, n('incorrect_reps', 'progress', {'exercise_name': 'Abduction', 'mistakes': 9, 'judged': 10})),
          'Abduction · 9 of 10 judged repetitions incorrect');
      expect(NotificationText.body(l, n('pain_report', 'pain', {'exercise_name': 'Flexion', 'pain_level': null})),
          'Flexion · reported during the exercise');
      expect(NotificationText.title(l, n('something_new', 'progress', {})), 'server title 1');
    });

    test('age against the server clock', () {
      final now = DateTime(2026, 10, 13, 10, 5);
      expect(NotificationText.when(l, DateTime(2026, 10, 13, 10, 4, 30), now), 'just now');
      expect(NotificationText.when(l, DateTime(2026, 10, 13, 9, 50), now), '15 min ago');
      expect(NotificationText.when(l, DateTime(2026, 10, 13, 7, 0), now), '3 h ago');
      expect(NotificationText.when(l, DateTime(2026, 10, 12, 23, 0), now), 'Yesterday');
      expect(NotificationText.when(l, DateTime(2026, 10, 1, 8, 3), now), '2026-10-01 08:03');
    });
  });

  group('api client', () {
    test('sends the login token; no token -> no request', () async {
      final s = FakeServer([_n(1, 'message', 'messages')]);
      expect((await s.api().count()).total, 1);
      expect(s.requests.single.headers['X-Auth-Token'], 'tok');
      await expectLater(s.api(token: null).count(),
          throwsA(isA<NotificationsException>().having((e) => e.reason, 'reason', NotificationsFailure.signedOut)));
      expect(s.requests, hasLength(1));
    });

    test('maps the status codes', () async {
      final s = FakeServer([]);
      await expectLater(s.api(token: 'bad').list(),
          throwsA(isA<NotificationsException>().having((e) => e.reason, 'r', NotificationsFailure.signedOut)));
      s.contextStatus = 403;
      await expectLater(s.api().context(1),
          throwsA(isA<NotificationsException>().having((e) => e.reason, 'r', NotificationsFailure.forbidden)));
      s.contextStatus = 404;
      await expectLater(s.api().context(1),
          throwsA(isA<NotificationsException>().having((e) => e.reason, 'r', NotificationsFailure.notFound)));
      s.failNext = 1;
      await expectLater(s.api().count(),
          throwsA(isA<NotificationsException>().having((e) => e.reason, 'r', NotificationsFailure.server)));
    });
  });

  group('notifications page', () {
    late FakeServer server;
    final opened = <int>[];

    Future<void> open(WidgetTester t) async {
      UnreadNotifier.instance.api = server.api();
      await t.pumpWidget(_app(NotificationsPage(api: server.api(), onOpen: (_, n) async => opened.add(n.id))));
      await t.pumpAndSettle();
    }

    Future<void> close(WidgetTester t) async {
      await t.pumpWidget(const SizedBox()); // stops the poll timer
    }

    setUp(() {
      opened.clear();
      server = FakeServer([
        _n(3, 'pain_report', 'pain', priority: 2, data: {'patient_name': 'Ali', 'exercise_name': 'Abduction', 'pain_level': 7}),
        _n(2, 'message', 'messages', data: {'sender_name': 'Ali', 'preview': 'My shoulder is better'}),
        _n(1, 'routine_update', 'routine', read: true, data: {'exercise_name': 'Flexion', 'sets': 3, 'reps': 10}),
      ]);
    });

    testWidgets('list, unread count, urgent mark', (t) async {
      await open(t);
      expect(find.text('2 unread'), findsOneWidget);
      expect(find.text('Ali reported pain'), findsOneWidget);
      expect(find.text('Abduction · pain 7/10'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('My shoulder is better'), findsOneWidget);
      expect(find.text('Flexion: 3 sets × 10 reps'), findsOneWidget);
      expect(find.text('5 min ago'), findsNWidgets(3));
      expect(UnreadNotifier.instance.value.total, 2);
      await close(t);
    });

    testWidgets('opening one marks it read and opens its target', (t) async {
      await open(t);
      await t.tap(find.text('New message from Ali'));
      await t.pumpAndSettle();
      expect(opened, [2]);
      expect(server.items.firstWhere((n) => n['id'] == 2)['read'], isTrue);
      expect(find.text('1 unread'), findsOneWidget);
      expect(UnreadNotifier.instance.value.total, 1);
      await close(t);
    });

    testWidgets('mark one read (dot) and mark all read', (t) async {
      await open(t);
      await t.tap(find.byKey(const Key('notif_read_3')));
      await t.pumpAndSettle();
      expect(find.text('1 unread'), findsOneWidget);
      expect(opened, isEmpty);
      await t.tap(find.byKey(const Key('notif_mark_all')));
      await t.pumpAndSettle();
      expect(find.text('0 unread'), findsOneWidget);
      expect(server.items.every((n) => n['read'] == true), isTrue);
      expect(find.byKey(const Key('notif_mark_all')), findsNothing);
      await close(t);
    });

    testWidgets('categories filter on the server', (t) async {
      await open(t);
      await t.ensureVisible(find.byKey(const Key('notif_cat_pain')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('notif_cat_pain')));
      await t.pumpAndSettle();
      expect(server.requests.last.url.queryParameters['category'], 'pain');
      expect(find.text('Ali reported pain'), findsOneWidget);
      expect(find.text('New message from Ali'), findsNothing);
      await t.ensureVisible(find.byKey(const Key('notif_cat_routine')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('notif_cat_routine')));
      await t.pumpAndSettle();
      expect(find.text('Your exercise plan was updated'), findsOneWidget);
      await close(t);
    });

    testWidgets('empty and error states, retry', (t) async {
      server = FakeServer([]);
      await open(t);
      expect(find.text('No notifications yet'), findsOneWidget);
      await close(t);

      server = FakeServer([_n(1, 'message', 'messages', data: {'sender_name': 'Ali'})])
        ..failNext = 1
        ..failAction = 'list';
      await open(t);
      expect(find.textContaining('Could not load the notifications'), findsOneWidget);
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(find.text('New message from Ali'), findsOneWidget);
      await close(t);
    });

    testWidgets('pages of 20, next page on demand', (t) async {
      server = FakeServer([for (var i = 45; i >= 1; i--) _n(i, 'message', 'messages', data: {'sender_name': 'P$i'})]);
      await open(t);
      expect(server.requests.last.url.queryParameters['page'], '1');
      await t.scrollUntilVisible(find.text('New message from P1'), 400,
          scrollable: find.descendant(of: find.byKey(const Key('notif_list')), matching: find.byType(Scrollable)));
      await t.pumpAndSettle();
      final pages = server.requests.where((r) => r.url.queryParameters['action'] == 'list').map((r) => r.url.queryParameters['page']);
      expect(pages, containsAll(['1', '2', '3']));
      await close(t);
    });
  });

  group('physiotherapist detail', () {
    Future<FakeServer> show(WidgetTester t, Map<String, dynamic> n, Map<String, dynamic> ctx,
        {int status = 200, List<String>? drafts, List<int>? patients}) async {
      final s = FakeServer([n])
        ..contextBody = ctx
        ..contextStatus = status;
      await t.pumpWidget(_app(NotificationDetailPage(
        notification: AppNotification.fromJson(n),
        api: s.api(),
        onOpenPatient: (_, id, _) => patients?.add(id),
        onMessagePatient: (_, _, _, draft) => drafts?.add(draft),
      )));
      await t.pumpAndSettle();
      return s;
    }

    final patient = {'id': 7, 'account_id': 30, 'name': 'Ali'};

    testWidgets('incorrect reps: numbers, tracking note, draft is only prepared', (t) async {
      final drafts = <String>[], patients = <int>[];
      final s = await show(
        t,
        _n(9, 'incorrect_reps', 'progress', priority: 1, data: {'patient_name': 'Ali', 'exercise_name': 'Abduction', 'mistakes': 9, 'judged': 10}),
        {
          'error': false,
          'patient': patient,
          'set': {'good': 1, 'mistakes': 9, 'unsure': 2, 'exercise_name': 'Abduction', 'created_at': '2026-10-13 09:00:00', 'summary': 'Arm too low x9'},
        },
        drafts: drafts,
        patients: patients,
      );
      expect(find.byKey(const Key('notif_tracking_note')), findsOneWidget);
      expect(find.textContaining('2 repetition(s) could not be judged reliably'), findsOneWidget);
      expect(find.text('Arm too low x9'), findsOneWidget);
      await t.tap(find.byKey(const Key('notif_message_patient')));
      await t.tap(find.byKey(const Key('notif_open_patient')));
      expect(drafts.single, contains('Abduction'));
      expect(patients, [7]);
      // nothing but the context was asked: no message is sent from here
      expect(server(s), ['context']);
    });

    testWidgets('pain: the patient\'s own words, no rating yet, not a diagnosis', (t) async {
      await show(
        t,
        _n(4, 'pain_report', 'pain', priority: 2, data: {'patient_name': 'Ali', 'exercise_name': 'Flexion', 'reported_at': '2026-10-13 09:00:00'}),
        {
          'error': false,
          'patient': patient,
          'set': {'events': [{'time': '0:42', 'source': 'voice', 'utterance': 'it hurts'}]},
        },
      );
      expect(find.text('No rating given yet'), findsOneWidget);
      expect(find.textContaining('it hurts'), findsOneWidget);
      expect(find.text("This is the patient's own report, not a medical finding."), findsOneWidget);
    });

    testWidgets('inactivity: prescribed vs done that day', (t) async {
      await show(
        t,
        _n(5, 'inactivity', 'progress', priority: 1, data: {'patient_name': 'Ali', 'date': '2026-10-12', 'prescribed': 1}),
        {
          'error': false,
          'patient': patient,
          'date': '2026-10-12',
          'prescribed': [{'name': 'Flexion', 'sets': 3, 'reps': 10}],
          'done_that_day': [],
        },
      );
      expect(find.text('2026-10-12'), findsOneWidget);
      expect(find.text('3 × 10'), findsOneWidget);
      expect(find.text('No exercise was recorded that day.'), findsOneWidget);
    });

    testWidgets('patient no longer assigned -> explained, no data', (t) async {
      await show(t, _n(6, 'pain_report', 'pain', data: {'patient_name': 'Ali'}), {'error': true}, status: 403);
      expect(find.text('This patient is no longer assigned to you.'), findsOneWidget);
      expect(find.byKey(const Key('notif_message_patient')), findsNothing);
    });
  });

  group('physiotherapist settings', () {
    testWidgets('lists the types, saves a switch on the server', (t) async {
      final s = FakeServer([]);
      await t.pumpWidget(_app(NotificationSettingsPage(api: s.api())));
      await t.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNWidgets(4));
      await t.tap(find.byKey(const Key('pref_message')));
      await t.pumpAndSettle();
      expect(s.prefs['message'], isFalse);
      expect(s.requests.last.method, 'POST');
      expect(t.widget<SwitchListTile>(find.byKey(const Key('pref_message'))).value, isFalse);
    });

    testWidgets('turning pain alerts off asks first', (t) async {
      final s = FakeServer([]);
      await t.pumpWidget(_app(NotificationSettingsPage(api: s.api())));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('pref_pain_report')));
      await t.pumpAndSettle();
      expect(find.text('Turn off pain alerts?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(s.prefs['pain_report'], isTrue);
      await t.tap(find.byKey(const Key('pref_pain_report')));
      await t.pumpAndSettle();
      await t.tap(find.text('Turn off'));
      await t.pumpAndSettle();
      expect(s.prefs['pain_report'], isFalse);
    });
  });
}

List<String?> server(FakeServer s) => s.requests.map((r) => r.url.queryParameters['action']).toList();
