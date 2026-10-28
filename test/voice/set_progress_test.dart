// Counting good reps (voice + battery) and the end of the set: n good reps (n = the physiotherapist's reps, 10 by
// default) or 2n reps in total.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinex_pose/kinex_pose.dart';
import 'package:reeducation/features/exercise_ai/core/exercise_module.dart';
import 'package:reeducation/features/exercise_ai/core/live_session.dart';
import 'package:reeducation/features/exercise_ai/core/pose_recording.dart';
import 'package:reeducation/features/exercise_ai/voice/speech_io.dart';
import 'package:reeducation/features/exercise_ai/voice/voice_assistant.dart';
import 'package:reeducation/features/exercise_ai/widgets/rep_battery.dart';
import 'package:reeducation/l10n/l10n.dart';

final en = lookupAppLocalizations(const Locale('en'));

RepVerdict verdict(int rep, String status, [String label = 'elb']) =>
    RepVerdict(
      rep: rep,
      tPeakS: rep * 3.0,
      scored: true,
      label: status == 'good' ? 'good' : label,
      status: status,
      message: '',
      confidence: status == 'unsure' ? 0.4 : 0.9,
      probs: const [0.9, 0.1],
      bufferFrames: 0,
      bufferEndMs: 0,
      pipelineMs: 1,
      onnxMs: 0,
    );

/// Each scoring pass returns the next rep of [script] (g = good, m = mistake, u = unsure).
class ScriptedModule implements ExerciseModule {
  final String script;
  int _i = 0;
  ScriptedModule(this.script);

  @override
  Future<ScoringUpdate> score(
    PoseRecording rec,
    String exercise,
    String side,
    List<double> alreadyScored, {
    bool finalPass = false,
  }) async {
    if (_i >= script.length) return const ScoringUpdate([], 0, null, false, 1);
    final c = script[_i++];
    final v = verdict(
      alreadyScored.length + 1,
      c == 'g' ? 'good' : (c == 'm' ? 'mistake' : 'unsure'),
    );
    return ScoringUpdate([v], _i, 'left', false, 1);
  }

  @override
  String get name => 'test';
  @override
  List<ExerciseInfo> get exercises => const [];
  @override
  List<String> get modelVariants => const ['multitask'];
  @override
  Future<void> load(String exercise, String variant) async {}
  @override
  bool needsMask(String exercise) => false;
  @override
  Float32List? frameExtras(String exercise, PoseFrame frame) => null;
  @override
  List<String>? get extraNames => null;
  @override
  LiveTracker tracker(String exercise, String side) =>
      throw UnimplementedError();
  @override
  void dispose() {}
}

class RecOutput implements SpeechOutput {
  final List<String> spoken = [];
  @override
  Future<bool> init(String languageTag, double rate) async => true;
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class NoInput implements SpeechInput {
  @override
  Future<SttAvailability> init() async => SttAvailability.unavailable;
  @override
  Future<String?> localeFor(String language) async => null;
  @override
  Future<bool> listen({
    String? localeId,
    required void Function(String text) onFinal,
    required void Function(String? error) onEnd,
    void Function(String partial)? onPartial,
  }) async => false;
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

Future<LiveSession> runSet(String script, {RecOutput? out, int goodTarget = 0}) async {
  final s = LiveSession(
    module: ScriptedModule(script),
    exercise: 'e2',
    side: 'left',
    variant: 'multitask',
    goodTarget: goodTarget,
  );
  s.phase = SessionPhase.active;
  if (out != null) {
    final a = VoiceAssistant(session: s, output: out, input: NoInput());
    await a.init('en');
  }
  for (var i = 0; i < script.length && s.phase == SessionPhase.active; i++) {
    await s.scorePassForTest();
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  // let finish() complete
  for (var i = 0; i < 20 && s.phase == SessionPhase.finishing; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    // the camera plugin is not there in tests: KinexPose.stop() answers nothing
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('kinex_pose'),
          (call) async => null,
        );
  });

  test(
    'voice counts good reps: "Good rep" the first time, then 2, 3; a mistake gets its correction',
    () async {
      final out = RecOutput();
      await runSet('gmgg', out: out);
      expect(
        out.spoken.where((t) => t != en.voiceStart(en.exE2Title)).toList(),
        [
          en.fbGood, // 1st good rep
          en.fbE2Elb, // mistake: correction, not counted
          '2',
          '3',
        ],
      );
    },
  );

  test('the set ends by itself after 10 good reps', () async {
    final s = await runSet('gggggmgggggggg');
    expect(s.phase, SessionPhase.done);
    expect(s.goodCount, 10);
    expect(s.verdicts.length, 11);
  });

  test(
    'no reps given: the set ends after 20 reps in total (2 x 10), even without 10 good ones',
    () async {
      final s = await runSet('mgmumgmmgmumgmmgmmugggg');
      expect(s.phase, SessionPhase.done);
      expect(s.verdicts.length, 20);
      expect(s.goodCount, lessThan(10));
    },
  );

  test('physiotherapist asked for 5 reps: ends at 5 good reps', () async {
    final s = await runSet('gmggmggg', goodTarget: 5);
    expect(s.phase, SessionPhase.done);
    expect(s.goodCount, 5);
    expect(s.verdicts.length, 7);
  });

  test('physiotherapist asked for 5 reps: ends at 10 reps in total without 5 good ones', () async {
    final s = await runSet('mmgmugmmgmggg', goodTarget: 5);
    expect(s.phase, SessionPhase.done);
    expect(s.verdicts.length, 10);
    expect(s.goodCount, 3);
  });

  testWidgets(
    'the battery fills one cell per rep: green good, orange mistake, grey not sure',
    (t) async {
      final v = [
        verdict(1, 'good'),
        verdict(2, 'mistake'),
        verdict(3, 'unsure'),
        verdict(4, 'good'),
      ];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: 400,
                child: RepBattery(verdicts: v, goodTarget: 10, capacity: 15),
              ),
            ),
          ),
        ),
      );
      expect(find.text('2'), findsOneWidget); // good reps
      expect(find.text('/10'), findsOneWidget);
      Color colorOf(int i) =>
          ((t.widget<Container>(find.byKey(Key('battery_cell_$i'))).decoration!
                  as BoxDecoration)
              .color)!;
      expect(colorOf(0), repGood);
      expect(colorOf(1), repMistake);
      expect(colorOf(2), repUnsure);
      expect(colorOf(3), repGood);
      expect(
        find.byKey(const Key('battery_cell_4')),
        findsNothing,
      ); // still empty
    },
  );
}
