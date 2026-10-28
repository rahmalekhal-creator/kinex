// The session log's feedback view: a stored set (live_rep rows) shown as the structured end-of-set view, and the
// signal that makes the home screen re-fetch after a set is saved.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeducation/features/exercise_ai/core/set_events.dart';
import 'package:reeducation/features/exercise_ai/pages/session_feedback_page.dart';
import 'package:reeducation/features/exercise_ai/widgets/set_report_view.dart';
import 'package:reeducation/l10n/app_localizations.dart';

void main() {
  final reps = [
    {'rep': 1, 'label': 'good', 'status': 'good', 'confidence': 0.9, 'peak_deg': 40.2, 'target_deg': 35},
    {'rep': 2, 'label': 'good', 'status': 'below_target', 'confidence': 0.88, 'peak_deg': 20.4, 'target_deg': 30},
    {'rep': 3, 'label': 'knee', 'status': 'mistake', 'confidence': 0.8, 'peak_deg': 45, 'target_deg': 35},
    {'rep': 4, 'label': 'wrong_side', 'status': 'wrong_side', 'confidence': null, 'peak_deg': null, 'target_deg': null},
  ];

  test('stored reps -> verdicts', () {
    final v = [for (final r in reps) repFromJson(r)];
    expect([for (final r in v) r.scored], [true, true, true, false]);
    expect(v[1].peakDeg, closeTo(20.4, 1e-9));
    expect(v[1].targetDeg, 30);
    expect(v[3].confidence.isNaN, isTrue);
  });

  testWidgets('a stored e4 set renders as the end-of-set view', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SetReportView(exercise: 'e4', side: 'left', verdicts: [for (final r in reps) repFromJson(r)]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // metrics: 3 counted (the wrong-side rep does not count), 3 scored, 1 good
    expect(find.text('3'), findsNWidgets(2));
    expect(find.text('reps counted'), findsOneWidget);
    // mistakes by type with the readable name and the correction
    expect(find.text('Knee bends'), findsWidgets);
    expect(find.text('Keep your left knee straight while you lift the leg'), findsWidgets);
    // range: below target, then the median lift of the good-form reps against the target
    expect(find.text('Good form, below your target'), findsOneWidget);
    expect(find.textContaining('Leg lift: median'), findsOneWidget);
    // the wrong-side rep is reported, not counted
    expect(find.text('1 rep(s) done with the other leg were not counted.'), findsOneWidget);
    // every rep
    expect(find.text('Every rep'), findsOneWidget);
    expect(find.textContaining('target 30 deg, you reached 20 deg'), findsOneWidget);
  });

  test('a saved set notifies the listeners (the home screen re-fetches)', () {
    var calls = 0;
    void listener() => calls++;
    SetEvents.saved.addListener(listener);
    SetEvents.notifySaved();
    SetEvents.notifySaved();
    SetEvents.saved.removeListener(listener);
    expect(calls, 2);
  });
}
