/// The voice assistant of a live set: speaks instructions and the model's verdicts, and executes short spoken
/// commands. Rule-based (no AI service). It never touches camera frames: it only reacts to the session's state
/// (phase, new verdicts, pain hold), and every speech call is asynchronous, so it cannot slow the pose pipeline.
///
/// Safety: a pain report pauses the set through the session's own pause and sets its pain hold; nothing here can
/// resume it (VoiceSessionControls.resume refuses during the hold). Manual buttons work without this class.
library;

import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:reeducation/l10n/l10n.dart';

import '../core/exercise_module.dart';
import '../core/session_controls.dart';
import 'speech_io.dart';
import 'voice_commands.dart';
import 'voice_config.dart';
import 'voice_lines.dart';

/// What the microphone / speaker is doing (shown next to the microphone button).
enum AssistantState {
  idle,
  listening,
  processing,
  speaking,
  unavailable,
  permissionDenied,
  error,
}

class VoiceAssistant extends ChangeNotifier {
  final VoiceSessionControls session;
  final SpeechOutput output;
  final SpeechInput input;
  final VoiceConfig config;
  final VoiceCommandParser parser;
  final DateTime Function() _now;

  VoiceAssistant({
    required this.session,
    required this.output,
    required this.input,
    this.config = const VoiceConfig(),
    this.parser = const VoiceCommandParser(),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  AssistantState state = AssistantState.idle;

  /// Text of the last recognised utterance (shown on screen).
  String? heard;

  /// The phone has no voice for the app language: English is spoken instead.
  bool languageFallback = false;

  /// Spoken feedback could not be started at all (no TTS engine).
  bool ttsUnavailable = false;

  late VoiceLines _lines;
  String _language = 'en';
  bool _ttsReady = false;
  bool _disposed = false;

  // speech queue
  final List<VoiceLine> _queue = [];
  VoiceLine? _speaking;
  final Map<String, DateTime> _lastSaid = {};
  VoiceLine? _lastInstruction;

  // session tracking
  SessionPhase? _lastPhase;
  int _lastVerdicts = 0;
  bool _lastPainHold = false;

  // commands run one after the other (no two session operations at the same time)
  Future<void> _commands = Future.value();

  /// Spoken lines (for tests and the screen).
  VoiceLines get lines => _lines;
  VoiceLine? get lastInstruction => _lastInstruction;
  bool get isListening => state == AssistantState.listening;
  bool get micUsable =>
      state != AssistantState.unavailable &&
      state != AssistantState.permissionDenied;

  /// Prepares the voice in the app [language] ('en', 'fr', 'ar') and starts following the session.
  /// Speech recognition is NOT started here (it asks for the microphone): only on a tap on the microphone.
  Future<void> init(String language) async {
    _language = language;
    _lines = VoiceLines(
      lookupAppLocalizations(Locale(language)),
      session.exercise,
      session.side,
    );
    _lastPhase = session.phase;
    _lastVerdicts = session.verdicts.length;
    _lastPainHold = session.painHold;
    session.addListener(_onSession);
    if (!config.spokenFeedback) return;
    _ttsReady = await output.init(
      ttsLanguageFor[language] ?? 'en-US',
      config.speechRate,
    );
    if (!_ttsReady && language != 'en') {
      _ttsReady = await output.init(ttsLanguageFor['en']!, config.speechRate);
      if (_ttsReady) {
        languageFallback = true;
        _lines = VoiceLines(
          lookupAppLocalizations(const Locale('en')),
          session.exercise,
          session.side,
        );
      }
    }
    ttsUnavailable = !_ttsReady;
    _notify();
  }

  // ------------------------------------------------------------------------------------------ session -> speech
  void _onSession() {
    if (_disposed) return;
    final phase = session.phase;
    if (session.painHold && !_lastPainHold) {
      // pain reported (button or voice): stop every ordinary message, speak the safety response
      _dropBelow(VoicePriority.safety);
      say(_lines.painResponse);
    }
    _lastPainHold = session.painHold;
    if (phase != _lastPhase) {
      final from = _lastPhase;
      _lastPhase = phase;
      _onPhase(phase, from);
    }
    final n = session.verdicts.length;
    if (n > _lastVerdicts) {
      final newOnes = session.verdicts.sublist(_lastVerdicts);
      _lastVerdicts = n;
      if (phase == SessionPhase.active) _onVerdicts(newOnes, n);
    }
  }

  void _onPhase(SessionPhase phase, SessionPhase? from) {
    switch (phase) {
      case SessionPhase.positioning:
        say(from == SessionPhase.paused ? _lines.resumed : _lines.stepBack);
      case SessionPhase.stillCountdown:
        say(_lines.standStill);
      case SessionPhase.active:
        say(_lines.start);
        _lastInstruction = _lines.exerciseInstruction;
      case SessionPhase.paused:
        _dropBelow(VoicePriority.instruction); // no more feedback about reps
        if (!session.painHold &&
            _speaking?.priority != VoicePriority.safety &&
            !_queueHas(VoicePriority.safety)) {
          say(_lines.paused);
        }
      case SessionPhase.finishing:
      case SessionPhase.done:
      case SessionPhase.failed:
        _dropBelow(VoicePriority.safety);
      default:
        break;
    }
  }

  /// One message per pass: the newest verdict (several at once would only pile up).
  /// One message per pass, about the newest rep: a good rep is counted ("Good rep" the first time, then "2",
  /// "3"... = the number of good reps so far); a mistake gets its correction; a low-confidence rep "not sure".
  void _onVerdicts(List<RepVerdict> newOnes, int total) {
    final v = newOnes.last;
    if (v.status == 'good') {
      final good = session.verdicts.where((x) => x.status == 'good').length;
      say(good <= 1 ? _lines.firstGoodRep : _lines.goodCount(good));
      return;
    }
    final line = _lines.forVerdict(v);
    if (line != null) say(line);
  }

  // ------------------------------------------------------------------------------------------ speech queue
  Duration _cooldown(VoiceLine line) => switch (line.key) {
    'fb_unsure' => config.unsureCooldown,
    _ =>
      line.priority == VoicePriority.feedback
          ? config.feedbackCooldown
          : config.instructionCooldown,
  };

  /// Queues [line]. Duplicates within their cooldown are dropped unless [force] (asked by the patient).
  /// Higher priority interrupts lower priority speech. During the pain hold only safety lines are said.
  void say(VoiceLine line, {bool force = false}) {
    if (_disposed) return;
    if (line.remember) _lastInstruction = line;
    if (!config.spokenFeedback || !_ttsReady) return;
    if (session.painHold && line.priority != VoicePriority.safety && !force) {
      return;
    }
    if (session.phase == SessionPhase.paused &&
        line.priority == VoicePriority.feedback) {
      return;
    }
    final now = _now();
    final last = _lastSaid[line.key];
    if (!force && last != null && now.difference(last) < _cooldown(line)) {
      return;
    }
    if (_speaking?.key == line.key || _queue.any((q) => q.key == line.key)) {
      return;
    }
    _lastSaid[line.key] = now;
    final current = _speaking;
    if (current != null && line.priority.index > current.priority.index) {
      _queue.removeWhere((q) => q.priority.index < line.priority.index);
      output
          .stop(); // interrupt: the pump continues with the more important line
    }
    _queue.add(line);
    _pump();
  }

  void _dropBelow(VoicePriority p) {
    _queue.removeWhere((q) => q.priority.index < p.index);
    if (_speaking != null && _speaking!.priority.index < p.index) output.stop();
  }

  bool _queueHas(VoicePriority p) => _queue.any((q) => q.priority == p);

  Future<void> _pump() async {
    if (_speaking != null || _queue.isEmpty || isListening || _disposed) return;
    // highest priority first, in order of arrival
    var best = 0;
    for (var i = 1; i < _queue.length; i++) {
      if (_queue[i].priority.index > _queue[best].priority.index) best = i;
    }
    final line = _queue.removeAt(best);
    _speaking = line;
    _setState(AssistantState.speaking);
    try {
      await output.speak(line.text);
    } catch (_) {}
    _speaking = null;
    if (state == AssistantState.speaking) _setState(AssistantState.idle);
    _pump();
  }

  // ------------------------------------------------------------------------------------------ listening
  /// The microphone button: starts one listening session, or stops the current one.
  Future<void> toggleListening() async {
    if (_disposed) return;
    if (isListening) {
      await input.stop();
      return;
    }
    if (state == AssistantState.processing) return;
    final avail = await input
        .init(); // the permission prompt, only after this tap
    if (avail != SttAvailability.available) {
      _setState(
        avail == SttAvailability.permissionDenied
            ? AssistantState.permissionDenied
            : AssistantState.unavailable,
      );
      return;
    }
    // stop speaking ordinary lines so the microphone does not hear the phone
    if (_speaking != null && _speaking!.priority != VoicePriority.safety) {
      await output.stop();
    }
    final locale = await input.localeFor(_language);
    heard = null;
    _setState(AssistantState.listening);
    final ok = await input.listen(
      localeId: locale,
      onPartial: (p) {
        heard = p;
        _notify();
      },
      onFinal: (text) => handleUtterance(text),
      onEnd: (err) {
        if (state == AssistantState.listening) {
          _setState(
            err == null ||
                    err == 'no_match' ||
                    err == 'error_no_match' ||
                    err == 'error_speech_timeout'
                ? AssistantState.idle
                : AssistantState.error,
          );
          _pump();
        }
      },
    );
    if (!ok && state == AssistantState.listening) {
      _setState(AssistantState.error);
    }
  }

  /// A recognised utterance (also the entry point for tests). Commands run one after the other.
  Future<void> handleUtterance(String text) {
    heard = text;
    _setState(AssistantState.processing);
    final cmd = parser.parse(text);
    debugPrint('[kinex voice] "$text" -> $cmd');
    _commands = _commands.then((_) => _execute(cmd, text)).catchError((
      Object e,
    ) {
      debugPrint('[kinex voice] command failed: $e');
    });
    return _commands.whenComplete(() {
      if (state == AssistantState.processing) _setState(AssistantState.idle);
      _pump();
    });
  }

  Future<void> _execute(VoiceCommand cmd, String text) async {
    switch (cmd.type) {
      case VoiceCommandType.painReport:
        if (!session.painHold) {
          await session.reportPain(source: 'voice', utterance: text);
        }
        say(_lines.painResponse, force: true);
      case VoiceCommandType.painAmbiguous:
        if (session.painHold) {
          say(_lines.painHoldRefuse, force: true);
        } else {
          await session.pause(
            PauseReason.painClarify,
            source: 'voice',
            utterance: text,
          );
          say(_lines.painClarify, force: true);
        }
      case VoiceCommandType.uncomfortable:
        if (session.painHold) {
          say(_lines.painHoldRefuse, force: true);
        } else {
          await session.pause(
            PauseReason.discomfort,
            source: 'voice',
            utterance: text,
          );
          say(_lines.uncomfortable, force: true);
        }
      case VoiceCommandType.pause:
        if (session.painHold) {
          say(_lines.painHoldRefuse, force: true);
        } else if (session.phase == SessionPhase.paused) {
          say(_lines.paused, force: true);
        } else {
          await session.pause(
            PauseReason.patient,
            source: 'voice',
            utterance: text,
          );
        }
      case VoiceCommandType.resume:
        if (session.painHold) {
          say(_lines.painHoldRefuse, force: true);
        } else if (session.phase == SessionPhase.paused) {
          await session.resume(source: 'voice');
        } else {
          say(_lines.alreadyRunning, force: true);
        }
      case VoiceCommandType.repeat:
        final last = _lastInstruction;
        say(last ?? _lines.nothingToRepeat, force: true);
      case VoiceCommandType.explainSimpler:
        final last = _lastInstruction;
        if (last == null) {
          say(_lines.nothingToRepeat, force: true);
        } else {
          say(
            VoiceLine(
              '${last.key}_simple',
              last.simple ?? last.text,
              priority: last.priority,
            ),
            force: true,
          );
        }
      case VoiceCommandType.help:
        say(_lines.help, force: true);
      case VoiceCommandType.unknown:
        say(_lines.notUnderstood, force: true);
    }
  }

  // ------------------------------------------------------------------------------------------ lifecycle
  void _setState(AssistantState s) {
    if (state == s) return;
    state = s;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Ends everything: speech stopped, queue cleared, listening cancelled, session no longer followed.
  Future<void> shutdown() async {
    if (_disposed) return;
    _disposed = true;
    session.removeListener(_onSession);
    _queue.clear();
    await output.stop();
    await input.cancel();
    await output.dispose();
  }

  @override
  void dispose() {
    shutdown();
    super.dispose();
  }
}
