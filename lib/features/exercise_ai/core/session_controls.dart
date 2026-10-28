/// What other parts of the app (the voice assistant, the buttons) may ask of a live set.
/// Implemented by [LiveSession]; kept small so it can be faked in tests.
library;

import 'package:flutter/foundation.dart';

import 'exercise_module.dart';

enum SessionPhase {
  starting,
  positioning,
  stillCountdown,
  active,

  /// Recording and judging are stopped. See [VoiceSessionControls.painHold] for the pain safety hold.
  paused,
  finishing,
  done,
  failed,
}

/// Why the set was paused (recorded with the event).
enum PauseReason {
  /// The patient pressed Pause or said "pause".
  patient,

  /// The patient said they were uncomfortable: paused, and asked whether it hurts.
  discomfort,

  /// The patient said something about pain that was not a clear report (a question, a negation...): paused to be safe.
  painClarify,

  /// The patient reported pain: safety hold, no ordinary resume.
  pain,
}

/// Something that happened during the set, kept for the report sent to the physiotherapist.
class SessionEvent {
  /// pause / resume / pain_report / discomfort / pain_clarify
  final String type;
  final DateTime at;

  /// Seconds since the set started (the first "start").
  final double setSeconds;

  /// voice / button, and what was heard for voice.
  final String source;
  final String? utterance;

  const SessionEvent(
    this.type,
    this.at,
    this.setSeconds,
    this.source, [
    this.utterance,
  ]);
}

abstract class VoiceSessionControls implements Listenable {
  SessionPhase get phase;

  /// True once the patient reported pain: the set stays paused until it is ended.
  bool get painHold;

  List<RepVerdict> get verdicts;
  String get exercise;
  String get side;

  /// Pauses the set (does nothing when it is not running). Safe to call several times.
  Future<void> pause(PauseReason reason, {String source, String? utterance});

  /// Resumes after an ordinary pause. Returns false (and stays paused) during the pain hold.
  Future<bool> resume({String source});

  /// Patient-reported pain: pause + safety hold + one event. Repeated reports during the hold add nothing.
  Future<void> reportPain({required String source, String? utterance});
}
