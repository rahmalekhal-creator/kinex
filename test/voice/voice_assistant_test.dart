// Voice assistant: spoken feedback, commands, the pain safety hold, resources, concurrency.
// Text-to-speech and speech recognition are faked; pausing uses the real LiveSession.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeducation/features/exercise_ai/core/exercise_module.dart';
import 'package:reeducation/features/exercise_ai/core/live_session.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_module.dart';
import 'package:reeducation/features/exercise_ai/voice/speech_io.dart';
import 'package:reeducation/features/exercise_ai/voice/voice_assistant.dart';
import 'package:reeducation/features/exercise_ai/widgets/live_controls.dart';
import 'package:reeducation/l10n/l10n.dart';

final en = lookupAppLocalizations(const Locale('en'));

/// Records what is said; speaking completes at once unless [hold] is set.
class FakeOutput implements SpeechOutput {
  final List<String> spoken = [];
  int stops = 0;
  bool disposed = false;
  bool available = true;
  Completer<void>? hold;

  @override
  Future<bool> init(String languageTag, double rate) async => available;
  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    if (hold != null) await hold!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    final h = hold;
    if (h != null && !h.isCompleted) h.complete();
  }

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeInput implements SpeechInput {
  SttAvailability availability = SttAvailability.available;
  bool cancelled = false;
  int listens = 0;
  @override
  Future<SttAvailability> init() async => availability;
  @override
  Future<String?> localeFor(String language) async => null;
  @override
  Future<bool> listen({
    String? localeId,
    required void Function(String text) onFinal,
    required void Function(String? error) onEnd,
    void Function(String partial)? onPartial,
  }) async {
    listens++;
    return true;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async => cancelled = true;
}

/// A session whose verdicts the test can add (feedback tests).
class FakeSession extends ChangeNotifier implements VoiceSessionControls {
  @override
  SessionPhase phase = SessionPhase.active;
  @override
  bool painHold = false;
  @override
  final List<RepVerdict> verdicts = [];
  @override
  String get exercise => 'e2';
  @override
  String get side => 'left';
  int pauses = 0;

  void addVerdict(String status, String label) {
    verdicts.add(
      RepVerdict(
        rep: verdicts.length + 1,
        tPeakS: verdicts.length * 3.0,
        scored: status != 'not_scored',
        label: label,
        status: status,
        message: 'model message',
        confidence: status == 'unsure' ? 0.4 : 0.9,
        probs: const [0.1, 0.9],
        bufferFrames: 0,
        bufferEndMs: 0,
        pipelineMs: 0,
        onnxMs: 0,
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> pause(
    PauseReason reason, {
    String source = 'button',
    String? utterance,
  }) async {
    pauses++;
    phase = SessionPhase.paused;
    notifyListeners();
  }

  @override
  Future<bool> resume({String source = 'button'}) async => false;
  @override
  Future<void> reportPain({required String source, String? utterance}) async {}
}

LiveSession realSession() {
  final s = LiveSession(
    module: ShoulderModule(),
    exercise: 'e2',
    side: 'left',
    variant: 'multitask',
  );
  s.phase = SessionPhase.active;
  return s;
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeOutput out;
  late FakeInput inp;
  late DateTime now;

  setUp(() {
    out = FakeOutput();
    inp = FakeInput();
    now = DateTime(2026, 10, 11, 10);
  });

  Future<VoiceAssistant> assistant(VoiceSessionControls s) async {
    final a = VoiceAssistant(
      session: s,
      output: out,
      input: inp,
      clock: () => now,
    );
    await a.init('en');
    return a;
  }

  test(
    '1. a detected movement correction is spoken (the model\'s class, in the app language)',
    () async {
      final s = FakeSession();
      await assistant(s);
      s.addVerdict('mistake', 'elb');
      await settle();
      expect(out.spoken, contains(en.fbE2Elb));
    },
  );

  test(
    '1b. a low-confidence rep is not spoken as a mistake: the "not sure" message instead',
    () async {
      final s = FakeSession();
      await assistant(s);
      s.addVerdict('unsure', 'shld');
      await settle();
      expect(out.spoken, isNot(contains(en.fbE2Shld)));
      expect(out.spoken, contains(en.fbUnsure));
    },
  );

  test('2. the same correction is not repeated within its cooldown', () async {
    final s = FakeSession();
    await assistant(s);
    for (var i = 0; i < 3; i++) {
      s.addVerdict('mistake', 'elb'); // a rep every 3 s
      await settle();
      now = now.add(const Duration(seconds: 3));
    }
    expect(out.spoken.where((t) => t == en.fbE2Elb).length, 1);
    now = now.add(
      const Duration(seconds: 3),
    ); // 9 s after the first one: said again
    s.addVerdict('mistake', 'elb');
    await settle();
    expect(out.spoken.where((t) => t == en.fbE2Elb).length, 2);
  });

  test('3. "repeat" repeats the last instruction', () async {
    final s = FakeSession();
    final a = await assistant(s);
    s.addVerdict('mistake', 'lean');
    await settle();
    await a.handleUtterance('Repeat');
    await settle();
    expect(out.spoken.where((t) => t == en.fbE2Lean).length, 2);
  });

  test('4. "I don\'t understand" gives the simpler explanation', () async {
    final s = FakeSession();
    final a = await assistant(s);
    s.addVerdict('mistake', 'shld');
    await settle();
    await a.handleUtterance("I don't understand");
    await settle();
    expect(out.spoken.last, en.fbE2ShldSimple);
  });

  test('5. "pause" calls the real pause of the session', () async {
    final s = realSession();
    final a = await assistant(s);
    await a.handleUtterance('Pause');
    expect(s.phase, SessionPhase.paused);
    expect(s.painHold, isFalse);
    expect(s.events.single.type, 'pause');
    expect(s.events.single.source, 'voice');
  });

  test(
    '6. a clear pain report pauses, sets the hold, records one event and says the safety response',
    () async {
      final s = realSession();
      final a = await assistant(s);
      await a.handleUtterance('It hurts');
      await settle();
      expect(s.phase, SessionPhase.paused);
      expect(s.painHold, isTrue);
      expect(s.events.where((e) => e.type == 'pain_report').length, 1);
      expect(s.events.first.utterance, 'It hurts');
      expect(out.spoken, contains(en.voicePainResponse));
      // reported again: no duplicate event
      await a.handleUtterance("I'm in pain");
      expect(s.events.where((e) => e.type == 'pain_report').length, 1);
    },
  );

  test(
    '6b. the pain button (no voice at all) also pauses with the hold, and the voice gives the response',
    () async {
      final s = realSession();
      await assistant(s);
      await s.reportPain(source: 'button');
      await settle();
      expect(s.painHold, isTrue);
      expect(s.phase, SessionPhase.paused);
      expect(s.events.single.source, 'button');
      expect(out.spoken, contains(en.voicePainResponse));
    },
  );

  test(
    '7. the pain hold cannot be bypassed by "continue" nor by resume()',
    () async {
      final s = realSession();
      final a = await assistant(s);
      await a.handleUtterance('ça fait mal');
      await a.handleUtterance('continue');
      await a.handleUtterance('resume');
      expect(await s.resume(), isFalse);
      expect(s.phase, SessionPhase.paused);
      expect(s.painHold, isTrue);
      expect(s.events.any((e) => e.type == 'resume'), isFalse);
      await settle();
      expect(out.spoken, contains(en.voicePainHoldRefuse));
    },
  );

  test(
    '8. an ambiguous statement about pain pauses and asks, without a pain report',
    () async {
      final s = realSession();
      final a = await assistant(s);
      await a.handleUtterance('does it hurt if I lift higher?');
      await settle();
      expect(s.phase, SessionPhase.paused);
      expect(s.painHold, isFalse);
      expect(s.events.single.type, 'pain_clarify');
      expect(out.spoken, contains(en.voicePainClarify));
      // "I'm uncomfortable" also pauses and asks
      final s2 = realSession();
      final a2 = await assistant(s2);
      await a2.handleUtterance("I'm uncomfortable");
      expect(s2.phase, SessionPhase.paused);
      expect(s2.painHold, isFalse);
      expect(s2.events.single.type, 'discomfort');
    },
  );

  testWidgets(
    '9. speech recognition unavailable: the manual Pause and "I feel pain" buttons still work',
    (t) async {
      final s = realSession();
      final a = VoiceAssistant(
        session: s,
        output: out,
        input: inp..availability = SttAvailability.unavailable,
      );
      await t.runAsync(() async {
        await a.init('en');
        await a.toggleListening();
      });
      expect(a.state, AssistantState.unavailable);
      await t.pumpWidget(
        _app(
          Column(
            children: [
              MicStatus(assistant: a),
              MicButton(assistant: a),
              LiveControlsBar(session: s, onFinish: () {}),
            ],
          ),
        ),
      );
      expect(find.text(en.micUnavailable), findsOneWidget);
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('live_pause')));
        await settle();
      });
      expect(s.phase, SessionPhase.paused);
      await t.pumpWidget(_app(LiveControlsBar(session: s, onFinish: () {})));
      expect(find.byKey(const Key('live_resume')), findsOneWidget);
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('live_pain')));
        await settle();
      });
      expect(s.painHold, isTrue);
      // during the pain hold there is no Resume button, only Finish
      await t.pumpWidget(_app(LiveControlsBar(session: s, onFinish: () {})));
      expect(find.byKey(const Key('live_resume')), findsNothing);
      expect(find.byKey(const Key('live_pain')), findsNothing);
      expect(find.byKey(const Key('live_finish')), findsOneWidget);
    },
  );

  test(
    '9b. microphone permission refused: state shown, no listening, no repeated prompt without a tap',
    () async {
      final s = realSession();
      inp.availability = SttAvailability.permissionDenied;
      final a = await assistant(s);
      expect(inp.listens, 0); // nothing asked before the tap
      await a.toggleListening();
      expect(a.state, AssistantState.permissionDenied);
      expect(inp.listens, 0);
    },
  );

  test('10. ending the session stops speech and releases resources', () async {
    final s = FakeSession();
    out.hold = Completer<void>(); // speech still going on
    final a = await assistant(s);
    s.addVerdict('mistake', 'elb');
    await settle();
    await a.shutdown();
    expect(out.stops, greaterThan(0));
    expect(out.disposed, isTrue);
    expect(inp.cancelled, isTrue);
    final said = out.spoken.length;
    s.addVerdict('mistake', 'lean'); // the session is no longer followed
    await settle();
    expect(out.spoken.length, said);
  });

  test(
    '11. simultaneous commands do not conflict: one pain event, no resume, hold kept',
    () async {
      final s = realSession();
      final a = await assistant(s);
      await Future.wait([
        a.handleUtterance('pause'),
        a.handleUtterance('it hurts'),
        a.handleUtterance('continue'),
        a.handleUtterance('pause'),
        a.handleUtterance('I feel pain'),
      ]);
      expect(s.phase, SessionPhase.paused);
      expect(s.painHold, isTrue);
      expect(s.events.where((e) => e.type == 'pain_report').length, 1);
      expect(s.events.where((e) => e.type == 'pause').length, 1);
      expect(s.events.where((e) => e.type == 'resume'), isEmpty);
    },
  );

  test(
    '12. speech never blocks the session: notifications return at once while TTS is still speaking',
    () async {
      final s = FakeSession();
      out.hold = Completer<void>(); // TTS never finishes on its own
      await assistant(s);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        s.addVerdict(
          i.isEven ? 'mistake' : 'good',
          'elb',
        ); // what a scoring pass / frame update triggers
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(50));
      expect(
        out.spoken.length,
        1,
      ); // one line speaking, the rest suppressed or queued, nothing waited on
    },
  );

  test('pain hold: ordinary feedback is no longer spoken', () async {
    final s = FakeSession();
    final a = await assistant(s);
    s.painHold = true;
    s.phase = SessionPhase.paused;
    s.notifyListeners();
    await settle();
    out.spoken.clear();
    a.say(a.lines.help); // an ordinary line
    s.addVerdict('mistake', 'elb');
    await settle();
    expect(out.spoken, isEmpty);
  });

  test(
    'language fallback: no French voice on the phone -> English voice and English text',
    () async {
      final s = FakeSession();
      final o = _LangOutput({'en-US'});
      final a = VoiceAssistant(
        session: s,
        output: o,
        input: inp,
        clock: () => now,
      );
      await a.init('fr');
      expect(a.languageFallback, isTrue);
      s.addVerdict('mistake', 'elb');
      await settle();
      expect(o.spoken.single, en.fbE2Elb);
    },
  );
}

class _LangOutput extends FakeOutput {
  final Set<String> langs;
  _LangOutput(this.langs);
  @override
  Future<bool> init(String languageTag, double rate) async =>
      langs.contains(languageTag);
}

Widget _app(Widget child) => ProviderScope(
  child: MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  ),
);
