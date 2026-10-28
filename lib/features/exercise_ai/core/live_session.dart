/// The live set: camera frames -> buffer -> repeated scoring of the finished reps -> verdicts.
/// Generic: everything exercise-specific is in the [ExerciseModule].
///
/// Pause / resume / pain hold (used by the buttons and the voice assistant):
///   running (positioning, stillCountdown, active) --pause--> paused --resume--> positioning (new segment)
///   any running state --reportPain--> paused + painHold: resume() refuses; only finish() ends it.
/// While paused nothing is recorded or judged. On resume a new segment starts with a fresh buffer (and a new
/// "stand still" moment), so the paused gap never becomes part of the movement that is analysed.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:kinex_pose/kinex_pose.dart';

import 'exercise_module.dart';
import 'pose_recording.dart';
import 'session_controls.dart';
import 'tracked_exercises.dart';

export 'session_controls.dart'
    show SessionPhase, PauseReason, SessionEvent, VoiceSessionControls;

/// Key joints that must be in view: shoulders, elbows, wrists, hips.
const _keyJoints = [11, 12, 13, 14, 15, 16, 23, 24];

/// Leg exercises (e4) film the whole body: the knees and ankles must be in view too.
const _legJoints = [11, 12, 15, 16, 23, 24, 25, 26, 27, 28];

class TimingStats {
  final List<double> inferMs = [],
      prepMs = [],
      extrasMs = [],
      pipelineMs = [],
      onnxMsPerRep = [];

  static Map<String, double> summary(List<double> v) {
    if (v.isEmpty) return const {};
    final s = [...v]..sort();
    double q(double p) =>
        s[math.min(s.length - 1, (p * (s.length - 1)).round())];
    return {
      'n': s.length.toDouble(),
      'mean': s.reduce((a, b) => a + b) / s.length,
      'p50': q(0.5),
      'p90': q(0.9),
      'max': s.last,
    };
  }

  Map<String, dynamic> toJson() => {
    'mediapipe_ms_per_frame': summary(inferMs),
    'image_prep_ms_per_frame': summary(prepMs),
    'silhouette_ms_per_frame': summary(extrasMs),
    'pipeline_ms_per_pass': summary(pipelineMs),
    'onnx_ms_per_rep': summary(onnxMsPerRep),
  };
}

class LiveSession extends ChangeNotifier implements VoiceSessionControls {
  final ExerciseModule module;
  @override
  final String exercise, side;
  final String variant;
  final bool frontCamera;
  final double stillSeconds;

  /// The set ends by itself after [goodTarget] good reps (the reps the physiotherapist asked for), or after
  /// [maxReps] reps in total, good or not (by default twice [goodTarget]).
  final int goodTarget;
  final int maxReps;

  /// MediaPipe on the GPU (developer option; the default CPU matches the training landmarks).
  final bool useGpu;

  /// Analyse the camera frames at 1280 px (developer option). By default 640 px, or 1280 when the exercise needs
  /// the person mask (its silhouette numbers depend on the mask resolution).
  final bool fullResolution;

  LiveSession({
    required this.module,
    required this.exercise,
    required this.side,
    required this.variant,
    this.frontCamera = true,
    this.stillSeconds = 2.0,
    int goodTarget = 10,
    int? maxReps,
    this.useGpu = false,
    this.fullResolution = false,
  }) : goodTarget = goodTarget > 0 ? goodTarget : 10,
       maxReps = maxReps ?? 2 * (goodTarget > 0 ? goodTarget : 10);

  @override
  SessionPhase phase = SessionPhase.starting;
  String? error;
  bool previewMirrored = true;
  PoseFrame? lastFrame;

  /// Latest frame for the skeleton painter (repaints on its own, without rebuilding the screen).
  final ValueNotifier<PoseFrame?> frame = ValueNotifier<PoseFrame?>(null);

  /// One line of live numbers for the developer overlay (fps, backlog, per-stage times).
  String perfLine = '';
  double liveAngle = double.nan;
  double countdown = 0;
  @override
  final List<RepVerdict> verdicts = [];
  RepVerdict? latest;
  String? arm;
  bool sideConflict = false;
  int repsFound = 0;
  final TimingStats timing = TimingStats();

  // ---- pause / pain hold
  @override
  bool painHold = false;
  PauseReason? pauseReason;
  final List<SessionEvent> events = [];
  final Stopwatch _setClock = Stopwatch();

  // the buffer of the current segment (from the start of its 'stand still' moment)
  final List<double> _t = [];
  final List<Float32List?> _lm = [], _world = [], _extras = [];
  int _framesAtLastPass = 0;
  bool _busy = false;
  StreamSubscription<PoseFrame>? _sub;
  LiveTracker? _tracker;
  double _stillStartMs = 0;
  List<double>? _stillRef;

  /// Verdicts of earlier segments (before a pause): the reps of this segment are numbered after them.
  int _segmentStart = 0;

  /// Frames between two scoring passes: at least 0.5 s, more when a pass is slow (the pass re-analyses the whole
  /// segment, so on a slow phone it would otherwise keep a core busy and slow MediaPipe down).
  int _passEvery = 15;

  int get bufferFrames => _t.length;

  /// Reps judged good so far (the counter shown and spoken).
  int get goodCount => verdicts.where((v) => v.status == 'good').length;
  int get repCount => math.max(_tracker?.count ?? 0, countedReps);

  /// Reps that count toward the set: a rep done with the wrong arm / leg does not.
  int get countedReps => verdicts.where((v) => v.status != 'wrong_side').length;

  /// The latest rep was done with the wrong arm / leg (the screen asks to switch).
  bool get wrongSideNow => latest?.status == 'wrong_side';
  bool get needsMask => module.needsMask(exercise);
  bool get isRunning =>
      phase == SessionPhase.positioning ||
      phase == SessionPhase.stillCountdown ||
      phase == SessionPhase.active;

  Future<void> start() async {
    try {
      await module.load(exercise, variant);
      _tracker = module.tracker(exercise, side);
      _sub = KinexPose.frames().listen(
        _onFrame,
        onError: (Object e) => _fail('$e'),
      );
      previewMirrored = await KinexPose.start(
        front: frontCamera,
        mask: module.needsMask(exercise),
        gpu: useGpu,
        maxSide: fullResolution || module.needsMask(exercise) ? 1280 : 640,
      );
      phase = SessionPhase.positioning;
      notifyListeners();
    } catch (e) {
      _fail('$e');
    }
  }

  void _fail(String msg) {
    error = msg;
    phase = SessionPhase.failed;
    notifyListeners();
  }

  void _log(String type, String source, [String? utterance]) {
    events.add(
      SessionEvent(
        type,
        DateTime.now(),
        _setClock.elapsedMilliseconds / 1000.0,
        source,
        utterance,
      ),
    );
  }

  // ------------------------------------------------------------------------------------------ pause / resume / pain
  @override
  Future<void> pause(
    PauseReason reason, {
    String source = 'button',
    String? utterance,
  }) async {
    if (!isRunning) {
      return; // already paused, finishing or done: nothing to do (no duplicate event)
    }
    final wasActive = phase == SessionPhase.active;
    phase = SessionPhase.paused;
    pauseReason = reason;
    _log(
      switch (reason) {
        PauseReason.pain => 'pain_report',
        PauseReason.discomfort => 'discomfort',
        PauseReason.painClarify => 'pain_clarify',
        PauseReason.patient => 'pause',
      },
      source,
      utterance,
    );
    notifyListeners();
    if (wasActive) await _closeSegment();
  }

  @override
  Future<bool> resume({String source = 'button'}) async {
    if (painHold || phase != SessionPhase.paused) return false;
    _clearBuffer();
    _segmentStart = verdicts.length;
    pauseReason = null;
    phase = SessionPhase.positioning;
    _log('resume', source);
    notifyListeners();
    return true;
  }

  @override
  Future<void> reportPain({required String source, String? utterance}) async {
    if (painHold) return; // one event per hold
    if (phase == SessionPhase.finishing ||
        phase == SessionPhase.done ||
        phase == SessionPhase.failed) {
      return;
    }
    painHold = true;
    if (isRunning) {
      await pause(PauseReason.pain, source: source, utterance: utterance);
    } else {
      // already paused (e.g. after "I'm uncomfortable"): the pause becomes a pain hold
      pauseReason = PauseReason.pain;
      _log('pain_report', source, utterance);
      notifyListeners();
    }
  }

  /// The reps that finished before the pause are still judged (a rep cut by the pause is not counted);
  /// then the segment's buffer is dropped.
  Future<void> _closeSegment() async {
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    _trimTail(
      1500,
    ); // the moment the patient stopped (reaching for the phone, reacting to pain)
    if (_t.length > 1) await _scorePass();
    _clearBuffer();
  }

  // ------------------------------------------------------------------------------------------ frames
  bool _inView(PoseFrame f) {
    final lm = f.lm;
    if (lm == null) return false;
    for (final j in isLegExercise(exercise) ? _legJoints : _keyJoints) {
      final x = lm[j * 5], y = lm[j * 5 + 1], vis = lm[j * 5 + 3];
      if (!(x >= 0 && x <= 1 && y >= 0 && y <= 1) || !(vis >= 0.5)) {
        return false;
      }
    }
    return true;
  }

  /// Wrist positions relative to the shoulder mid point, in torso lengths (stillness check).
  List<double>? _pose(PoseFrame f) {
    final lm = f.lm;
    if (lm == null) return null;
    double x(int j) => lm[j * 5] * f.width;
    double y(int j) => lm[j * 5 + 1] * f.height;
    final mx = 0.5 * (x(11) + x(12)), my = 0.5 * (y(11) + y(12));
    final tl = math.sqrt(
      math.pow(mx - 0.5 * (x(23) + x(24)), 2) +
          math.pow(my - 0.5 * (y(23) + y(24)), 2),
    );
    if (tl <= 0) return null;
    return [
      for (final j
          in isLegExercise(exercise)
              ? const [15, 16, 13, 14, 27, 28]
              : const [15, 16, 13, 14]) ...[(x(j) - mx) / tl, (y(j) - my) / tl],
    ];
  }

  // ---- perf accounting (developer overlay + log): frames/s, handler time, backlog of the frame stream
  final Stopwatch _wall = Stopwatch();
  double _firstT = double.nan;
  double _lastReport = 0,
      _handlerMsSum = 0,
      _ageSum = 0,
      _inferSum = 0,
      _prepSum = 0,
      _lagMs = 0,
      _fps = 30,
      _maskSum = 0;
  int _nFrames = 0, _lastSig = 0, _droppedSum = 0;
  String _delegate = 'cpu';

  void _onFrame(PoseFrame f) {
    final sw = Stopwatch()..start();
    _handle(f);
    _handlerMsSum += sw.elapsedMicroseconds / 1000.0;
    _nFrames++;
    if (f.ageMs.isFinite) _ageSum += f.ageMs;
    if (f.inferMs.isFinite) _inferSum += f.inferMs;
    if (f.prepMs.isFinite) _prepSum += f.prepMs;
    _maskSum += f.maskMs;
    _droppedSum += f.dropped;
    _delegate = f.delegate;
    if (!_wall.isRunning) {
      _wall.start();
      _firstT = f.tMs;
    }
    // backlog: how much later than the camera clock the frames reach Dart (growing = events pile up)
    _lagMs = _wall.elapsedMilliseconds - (f.tMs - _firstT);
    final now = _wall.elapsedMilliseconds.toDouble();
    if (now - _lastReport >= 2000 && _nFrames > 0) {
      final dt = (now - _lastReport) / 1000.0;
      _fps = _nFrames / dt;
      final lastPass = timing.pipelineMs.isEmpty ? 0 : timing.pipelineMs.last;
      perfLine =
          '${_fps.toStringAsFixed(1)} fps ($_delegate, ${(_droppedSum / dt).toStringAsFixed(1)} dropped/s)'
          ' | ${f.width}x${f.height}'
          ' | camera->result ${(_ageSum / _nFrames).round()} ms (convert ${(_prepSum / _nFrames).round()},'
          ' MediaPipe ${(_inferSum / _nFrames).round()},'
          ' mask ${(_maskSum / _nFrames).round()}) | Dart ${(_handlerMsSum / _nFrames).toStringAsFixed(1)} ms/frame'
          ' | pass ${lastPass.round()} ms every $_passEvery fr | backlog ${_lagMs.round()} ms | buffer ${_t.length}';
      debugPrint('[kinex perf] $perfLine');
      _lastReport = now;
      _nFrames = 0;
      _handlerMsSum = _ageSum = _inferSum = _prepSum = _maskSum = 0;
      _droppedSum = 0;
      notifyListeners();
    }
    _notifyIfChanged();
  }

  /// Rebuild the screen only when something it shows has changed (the skeleton repaints on its own).
  void _notifyIfChanged() {
    final sig = Object.hash(
      phase,
      countdown.ceil(),
      repCount,
      liveAngle.isFinite ? liveAngle.round() : -999,
      verdicts.length,
      sideConflict,
      arm,
      painHold,
    );
    if (sig != _lastSig) {
      _lastSig = sig;
      notifyListeners();
    }
  }

  void _handle(PoseFrame f) {
    lastFrame = f;
    frame.value = f;
    if (f.inferMs.isFinite) timing.inferMs.add(f.inferMs);
    if (f.prepMs.isFinite) timing.prepMs.add(f.prepMs);
    switch (phase) {
      case SessionPhase.positioning:
        if (_inView(f)) _beginStill(f);
      case SessionPhase.stillCountdown:
        final p = _pose(f);
        final moved =
            p == null ||
            !_inView(f) ||
            List.generate(
                  p.length,
                  (i) => (p[i] - _stillRef![i]).abs(),
                ).reduce(math.max) >
                0.15;
        if (moved) {
          phase = SessionPhase.positioning;
          _clearBuffer();
          if (_inView(f)) _beginStill(f);
        } else {
          _record(f);
          countdown = math.max(
            0,
            stillSeconds - (f.tMs - _stillStartMs) / 1000.0,
          );
          if (countdown <= 0) {
            phase = SessionPhase.active;
            if (!_setClock.isRunning) _setClock.start();
          }
        }
      case SessionPhase.active:
        _record(f);
        liveAngle = _tracker!.add(f);
        if (!_busy && _t.length - _framesAtLastPass >= _passEvery) _scorePass();
      default:
        break; // paused / finishing / done: the camera keeps the preview, nothing is recorded or judged
    }
  }

  void _beginStill(PoseFrame f) {
    _clearBuffer();
    _stillRef = _pose(f);
    _stillStartMs = f.tMs;
    countdown = stillSeconds;
    phase = SessionPhase.stillCountdown;
    _record(f);
  }

  void _clearBuffer() {
    _t.clear();
    _lm.clear();
    _world.clear();
    _extras.clear();
    _framesAtLastPass = 0;
  }

  void _trimTail(double ms) {
    if (_t.isEmpty) return;
    final cut = _t.last - ms;
    while (_t.length > 1 && _t.last > cut) {
      _t.removeLast();
      _lm.removeLast();
      _world.removeLast();
      _extras.removeLast();
    }
  }

  void _record(PoseFrame f) {
    final sw = Stopwatch()..start();
    final ex = module.frameExtras(exercise, f);
    if (needsMask) timing.extrasMs.add(sw.elapsedMicroseconds / 1000.0);
    _t.add(f.tMs);
    _lm.add(f.lm);
    _world.add(f.world);
    _extras.add(ex);
    _frameSize = (f.width, f.height);
  }

  (int, int) _frameSize = (0, 0);

  /// The buffer of the current segment in the golden `input` format.
  PoseRecording recording() {
    final n = _t.length;
    final lm = Float32List(n * 165)..fillRange(0, n * 165, double.nan);
    final world = Float32List(n * 99)..fillRange(0, n * 99, double.nan);
    final k = module.extraNames?.length ?? 9;
    Float32List? sil;
    if (needsMask) {
      sil = Float32List(n * 2 * k)..fillRange(0, n * 2 * k, double.nan);
    }
    for (var i = 0; i < n; i++) {
      if (_lm[i] != null) lm.setAll(i * 165, _lm[i]!);
      if (_world[i] != null) world.setAll(i * 99, _world[i]!);
      if (sil != null && _extras[i] != null) sil.setAll(i * 2 * k, _extras[i]!);
    }
    return PoseRecording(
      tMs: Float64List.fromList(_t),
      lm: lm,
      world: world,
      sil: sil,
      silNames: sil != null ? module.extraNames : null,
      width: _frameSize.$1.toDouble(),
      height: _frameSize.$2.toDouble(),
    );
  }

  /// Runs one scoring pass now (tests).
  @visibleForTesting
  Future<void> scorePassForTest() => _scorePass();

  Future<void> _scorePass({bool finalPass = false}) async {
    _busy = true;
    _framesAtLastPass = _t.length;
    try {
      final segment = verdicts.sublist(_segmentStart);
      final up = await module.score(recording(), exercise, side, [
        for (final v in segment) v.tPeakS,
      ], finalPass: finalPass);
      timing.pipelineMs.add(up.pipelineMs);
      // next pass after at least 0.5 s, or after twice the time this pass took (keeps the scoring under ~1/3 of
      // a core, so MediaPipe is not slowed down as the set gets longer)
      _passEvery = math.max(15, (up.pipelineMs / 1000.0 * _fps * 2).ceil());
      repsFound = up.repsFound;
      arm = up.arm ?? arm;
      sideConflict = up.sideConflict;
      for (final v in up.newVerdicts) {
        final numbered = v.withRep(_segmentStart + v.rep);
        verdicts.add(numbered);
        latest = numbered;
        if (v.scored) timing.onnxMsPerRep.add(v.onnxMs);
      }
      if (up.newVerdicts.isNotEmpty) {
        debugPrint(
          '[kinex] pass on ${_t.length} frames: ${up.pipelineMs.toStringAsFixed(1)} ms, '
          '${up.newVerdicts.map((v) => '#${v.rep} ${v.label}').join(', ')}',
        );
      }
    } catch (e) {
      debugPrint('[kinex] scoring failed: $e');
    } finally {
      _busy = false;
    }
    notifyListeners();
    // enough good reps, or enough reps in total: end the set without touching the phone
    if (phase == SessionPhase.active &&
        (goodCount >= goodTarget || countedReps >= maxReps)) {
      finish(trimTail: false);
    }
  }

  /// Ends the set: last pass over the current segment (every remaining rep is final).
  /// [trimTail]: when the patient pressed Finish, the last 2 s (walking to the phone, reaching for the button)
  /// are not a rep: they are dropped before the last pass. Reps already judged are kept.
  /// Also the only way out of a pain hold.
  Future<void> finish({bool trimTail = true}) async {
    if (phase == SessionPhase.finishing || phase == SessionPhase.done) return;
    final wasActive = phase == SessionPhase.active;
    phase = SessionPhase.finishing;
    notifyListeners();
    await KinexPose.stop();
    await _sub?.cancel();
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (wasActive && trimTail) _trimTail(2000);
    if (wasActive && _t.length > 1) await _scorePass(finalPass: true);
    phase = SessionPhase.done;
    _setClock.stop();
    debugPrint('[kinex] timing ${timing.toJson()}');
    notifyListeners();
  }

  Future<void> cancel() async {
    await _sub?.cancel();
    await KinexPose.stop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    frame.dispose();
    super.dispose();
  }
}
