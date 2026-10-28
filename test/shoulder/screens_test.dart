// The screens that do not need the camera: exercise setup and the end-of-set summary.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:reeducation/l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeducation/features/exercise_ai/core/assignment_context.dart';
import 'package:reeducation/features/exercise_ai/core/exercise_module.dart';
import 'package:reeducation/features/exercise_ai/core/live_session.dart';
import 'package:reeducation/features/exercise_ai/pages/exercise_setup_page.dart';
import 'package:reeducation/features/exercise_ai/pages/set_summary_page.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_module.dart';

RepVerdict _v(int rep, String label, String status, String msg) => RepVerdict(
  rep: rep,
  tPeakS: rep * 2.0,
  scored: status != 'not_scored',
  label: label,
  status: status,
  message: msg,
  confidence: 0.9,
  probs: const [0.9, 0.1],
  bufferFrames: 100,
  bufferEndMs: 0,
  pipelineMs: 0,
  onnxMs: 0,
);

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

void main() {
  testWidgets(
    'setup page shows what the physiotherapist set and only asks camera, model and dev options',
    (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.5;
      await t.pumpWidget(
        _app(const ExerciseSetupPage(exerciseId: 'e2', side: 'left')),
      );
      expect(
        find.text('Arm abduction'),
        findsOneWidget,
      ); // the assigned exercise, shown
      expect(find.textContaining('Arm: left'), findsOneWidget);
      expect(find.text('set by your physiotherapist'), findsOneWidget);
      // nothing to choose about the exercise or the arm
      expect(find.text('Forward elevation with a stick'), findsNothing);
      expect(find.text('Left arm'), findsNothing);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Model'), findsOneWidget);
      expect(find.text('Show timing overlay'), findsOneWidget);
    },
  );

  testWidgets('e1 shows the injured arm', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    await t.pumpWidget(
      _app(const ExerciseSetupPage(exerciseId: 'e1', side: 'right')),
    );
    expect(find.textContaining('Injured arm: right'), findsOneWidget);
  });

  testWidgets(
    'summary counts reps, scored reps, good reps and mistakes by type',
    (t) async {
      final s = LiveSession(
        module: ShoulderModule(),
        exercise: 'e2',
        side: 'left',
        variant: 'multitask',
      );
      s.verdicts.addAll([
        _v(1, 'good', 'good', 'Good rep - well done'),
        _v(2, 'elb', 'mistake', 'Keep your elbow straight'),
        _v(3, 'elb', 'mistake', 'Keep your elbow straight'),
        _v(
          4,
          'shld',
          'unsure',
          'Not sure about this rep - check that your whole body is in view',
        ),
        _v(
          5,
          'not_scored',
          'not_scored',
          'Rep cut by the start/end of the recording - not scored',
        ),
      ]);
      t.view.physicalSize = const Size(1080, 4000);
      t.view.devicePixelRatio = 2.5;
      // no assignment -> nothing is sent (the "Saved and sent" card is not shown)
      await t.pumpWidget(
        _app(
          SetSummaryPage(session: s, exercise: ShoulderModule().exercises[1]),
        ),
      );
      expect(find.text('5'), findsOneWidget); // counted
      expect(find.text('4'), findsOneWidget); // scored
      expect(find.text('2'), findsOneWidget); // elbow mistakes
      expect(
        find.text('1 rep(s) could not be judged with confidence.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'summary of an assigned set tries to send it and offers a retry when the server is not reachable',
    (t) async {
      final s = LiveSession(
        module: ShoulderModule(),
        exercise: 'e2',
        side: 'left',
        variant: 'multitask',
      );
      s.verdicts.addAll([_v(1, 'good', 'good', 'Good rep - well done')]);
      t.view.physicalSize = const Size(1080, 4000);
      t.view.devicePixelRatio = 2.5;
      await t.runAsync(() async {
        await t.pumpWidget(
          _app(
            SetSummaryPage(
              session: s,
              exercise: ShoulderModule().exercises[1],
              side: 'left',
              assignment: const AssignmentContext(
                accountId: 11,
                patientExerciseId: 14,
                targetReps: 10,
              ),
            ),
          ),
        );
        await Future<void>.delayed(
          const Duration(seconds: 2),
        ); // the test environment has no network
        await t.pump();
      });
      expect(find.textContaining('Not sent'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    },
  );
}
