/// Exercise 4 (standing hip abduction) for the live assistant: assets, live scoring on the buffer (analyzeVideoE4 in
/// a background isolate + the ONNX head), the range rule and the on-screen tracker. Same flow as the shoulder module;
/// no segmentation mask.
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:kinex_pose/kinex_pose.dart';

import '../core/exercise_module.dart';
import '../core/np_port.dart';
import '../core/pose_recording.dart';
import '../shoulder/shoulder_config.dart';
import '../shoulder/shoulder_ds.dart' show repWindow;
import '../shoulder/shoulder_lib.dart' show OnlineCounter;
import '../shoulder/shoulder_model.dart';
import 'hip_pipeline.dart';
import 'leg_ds.dart';

const _bundle = 'e4_app_bundle';

HipSpec? _specCache;

/// app_spec_e4.json (feedback and range rule), loaded once (e.g. for the physiotherapist's prescription form).
Future<HipSpec> loadHipSpec() async => _specCache ??= HipSpec.fromJson(
  jsonDecode(await rootBundle.loadString('$_bundle/app_spec_e4.json'))
      as Map<String, dynamic>,
);

/// Median rep amplitude of the count signal (abd_leg_a, deg) in the golden recordings without the shallow one:
/// the reference amplitude of the causal on-screen counter. Lifts differ a lot between people (about 15-75 deg),
/// so a rep on screen = a rise and a fall of 0.25 x this (about 12 deg): it keeps the reps of the shallow recording
/// (checked in test/hip/hip_live_test.dart). Display only: the scored reps come from the offline segmentation.
const _refAmp = 47.5;
const _counterFraction = 0.25;

class HipModule implements ExerciseModule {
  /// The physiotherapist's target angle for this patient (deg), if set.
  final double? targetDeg;

  /// The patient's usual lift (median peak angle of their good reps, deg), if known.
  final double? usualLiftDeg;

  HipModule({this.targetDeg, this.usualLiftDeg});

  HipSpec? _spec;
  ModelConfig? _cfg;
  ShoulderHeadModel? _model;
  _ScoringWorker? _worker;
  bool _loaded = false;

  HipSpec? get spec => _spec;

  /// The range target of this set (after [load]).
  RangeTarget get target =>
      rangeTarget(_spec!, therapistDeg: targetDeg, usualLiftDeg: usualLiftDeg);

  @override
  String get name => 'Hip';

  @override
  List<String> get modelVariants => const ['multitask'];

  @override
  List<ExerciseInfo> get exercises => const [
    ExerciseInfo(
      'e4',
      'Standing hip abduction (chair support)',
      'Hold the chair, keep your trunk upright and lift the straight leg out to the side, then lower it with control.',
      'Which leg will you lift?',
    ),
  ];

  /// The range baseline of the current set (calibrated on its first good-form reps).
  SessionRange? _session;

  @override
  Future<void> load(String exercise, String variant) async {
    _session?.reset(); // load = a new set: calibrate again
    if (_loaded) return;
    _spec = await loadHipSpec();
    _session = SessionRange(_spec!.relativeFraction);
    _cfg = hipModelConfig(
      jsonDecode(await rootBundle.loadString('$_bundle/models/e4_head.json'))
          as Map<String, dynamic>,
    );
    final head = _cfg!.heads[e4]!;
    final bytes = await rootBundle.load('$_bundle/models/${head.onnxFile}');
    _model = ShoulderHeadModel(
      head,
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      threads: 2,
    );
    _loaded = true;
  }

  @override
  bool needsMask(String exercise) => false;

  @override
  List<String>? get extraNames => null;

  @override
  Float32List? frameExtras(String exercise, PoseFrame frame) => null;

  @override
  LiveTracker tracker(String exercise, String side) => HipTracker(side);

  @override
  Future<ScoringUpdate> score(
    PoseRecording rec,
    String exercise,
    String side,
    List<double> alreadyScored, {
    bool finalPass = false,
  }) async {
    final cfg = _cfg!, head = cfg.heads[e4]!, spec = _spec!;
    final worker = _worker ??= await _ScoringWorker.spawn();
    final r = await worker.run(
      _Job(rec, side, cfg.analyze, head, alreadyScored, finalPass),
    );
    if (r == null) return const ScoringUpdate([], 0, null, false, 0);
    final sw = Stopwatch()..start();
    final probs = r.x.isEmpty
        ? const <List<double>>[]
        : _model!.predict(r.x, r.f);
    final onnxMs = sw.elapsedMicroseconds / 1000.0;
    final perRep = r.x.isEmpty ? 0.0 : onnxMs / r.x.length;
    final prescription = target;
    final session = _session!;
    final out = <RepVerdict>[];
    var j = 0;
    RepVerdict make(
      HipLiveRep rp, {
      required bool scored,
      required String label,
      required String status,
      required String message,
      double confidence = double.nan,
      List<double> p = const [],
      double onnx = 0,
      double peak = double.nan,
      double targetDeg = double.nan,
    }) => RepVerdict(
      rep: rp.rep,
      tPeakS: rp.tPeakS,
      scored: scored,
      label: label,
      status: status,
      message: message,
      confidence: confidence,
      probs: p,
      bufferFrames: rec.length,
      bufferEndMs: rec.tMs.isEmpty ? double.nan : rec.tMs.last,
      pipelineMs: r.pipelineMs,
      onnxMs: onnx,
      peakDeg: peak,
      targetDeg: targetDeg,
    );
    for (final rp in r.reps) {
      if (rp.wrongSide) {
        out.add(
          make(
            rp,
            scored: false,
            label: 'wrong_side',
            status: 'wrong_side',
            message:
                'Wrong leg - switch to your $side leg: this rep does not count',
          ),
        );
      } else if (rp.usable) {
        final peak = r.peaks[j];
        // the first good-form reps of the set calibrate its range (not judged); then only a clear drop is flagged
        final tgt = session.target(prescription);
        final v = verdictE4(spec, head, probs[j++], side, peak, tgt);
        session.add(v, peak);
        out.add(
          make(
            rp,
            scored: true,
            label: v.label,
            status: v.status,
            message: v.message,
            confidence: v.confidence,
            p: v.probs,
            onnx: perRep,
            peak: peak,
            targetDeg: tgt?.deg ?? double.nan,
          ),
        );
      } else {
        out.add(
          make(
            rp,
            scored: false,
            label: 'not_scored',
            status: 'not_scored',
            message: rp.partial ? spec.partial : spec.unsure,
          ),
        );
      }
    }
    return ScoringUpdate(out, r.repsFound, r.leg, r.sideConflict, r.pipelineMs);
  }

  @override
  void dispose() {
    _model?.close();
    _model = null;
    _loaded = false;
    _worker?.close();
    _worker = null;
  }
}

class _Job {
  final PoseRecording rec;
  final String side;
  final AnalyzeConfig cfg;
  final HeadConfig head;
  final List<double> alreadyScored;
  final bool finalPass;
  const _Job(
    this.rec,
    this.side,
    this.cfg,
    this.head,
    this.alreadyScored,
    this.finalPass,
  );
}

/// A background isolate that stays alive for the whole set and runs [analyzeForLiveE4] for each pass.
class _ScoringWorker {
  final Isolate _isolate;
  final SendPort _jobs;
  _ScoringWorker._(this._isolate, this._jobs);

  static Future<_ScoringWorker> spawn() async {
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(
      _main,
      ready.sendPort,
      debugName: 'kinex-scoring-hip',
    );
    final jobs = await ready.first as SendPort;
    return _ScoringWorker._(isolate, jobs);
  }

  static void _main(SendPort ready) {
    final inbox = ReceivePort();
    ready.send(inbox.sendPort);
    inbox.listen((msg) {
      final (SendPort reply, _Job job) = msg as (SendPort, _Job);
      try {
        reply.send(
          analyzeForLiveE4(
            job.rec,
            job.side,
            job.cfg,
            job.head,
            job.alreadyScored,
            job.finalPass,
          ),
        );
      } catch (e) {
        reply.send(null);
      }
    });
  }

  Future<HipLiveResult?> run(_Job job) async {
    final reply = ReceivePort();
    _jobs.send((reply.sendPort, job));
    final r = await reply.first;
    reply.close();
    return r as HipLiveResult?;
  }

  void close() => _isolate.kill(priority: Isolate.immediate);
}

class HipLiveRep {
  final int rep;
  final double tPeakS;
  final bool usable, partial, wrongSide;
  const HipLiveRep(
    this.rep,
    this.tPeakS,
    this.usable,
    this.partial, {
    this.wrongSide = false,
  });
}

/// The newly finished reps of one pass, with the model inputs of the usable ones.
class HipLiveResult {
  final List<HipLiveRep> reps;
  final List<List<Float32List>> x;
  final List<Float32List> f;
  final List<double> peaks;
  final int repsFound;
  final String leg;
  final bool sideConflict;
  final double pipelineMs;
  const HipLiveResult(
    this.reps,
    this.x,
    this.f,
    this.peaks,
    this.repsFound,
    this.leg,
    this.sideConflict,
    this.pipelineMs,
  );

  /// (rep number, wrong side, usable) of the finished reps (tests).
  List<(int, bool, bool)> get repSummary => [
    for (final r in reps) (r.rep, r.wrongSide, r.usable),
  ];
}

/// The whole e4 pipeline on the buffer, then the reps that are finished (their end + 0.5 s is in the buffer and the
/// leg is back at rest, or the next rep has started) and not scored yet (matched by peak time). A rep done with the
/// other leg is reported as wrongSide and not sent to the model.
HipLiveResult? analyzeForLiveE4(
  PoseRecording rec,
  String side,
  AnalyzeConfig cfg,
  HeadConfig head,
  List<double> alreadyScored,
  bool finalPass,
) {
  final sw = Stopwatch()..start();
  final a = analyzeVideoE4(rec, side, cfg, head);
  if (a == null) return null;
  final n = a.r.n, m = pyRound(cfg.marginS * cfg.fs);
  final s = a.s;
  final t0 = a.r.t[0];
  final reps = <HipLiveRep>[];
  final xs = <List<Float32List>>[], fs = <Float32List>[], peaks = <double>[];
  for (var k = 0; k < a.rows.length; k++) {
    final row = a.rows[k], rp = row.seg;
    final tPeak = row.tPeak - t0;
    if (alreadyScored.any((t) => (t - tPeak).abs() < 0.4)) continue;
    var finished = finalPass;
    if (!finished && !rp.partial && rp.iEnd + m <= n - 1) {
      final nextStarted = k < a.rows.length - 1;
      var atRest = s != null;
      if (s != null) {
        final lim = s[rp.iEnd] + 0.1 * rp.amp;
        for (var i = n - m; i < n; i++) {
          if (s[i] > lim) atRest = false;
        }
      }
      finished = nextStarted || atRest;
    }
    if (!finished) continue;
    if (!rp.partial) {
      final (w0, w1) = repWindow(rp, n, cfg.fs, cfg.marginS);
      if (wrongLegInWindow(a.r, w0, w1, side)) {
        reps.add(
          HipLiveRep(row.rep, tPeak, false, rp.partial, wrongSide: true),
        );
        continue;
      }
    }
    reps.add(HipLiveRep(row.rep, tPeak, row.usable, rp.partial));
    if (row.usable) {
      final j = a.use.indexOf(k);
      xs.add(a.x[j]);
      fs.add(a.f[j]);
      peaks.add(a.peakDeg[j]);
    }
  }
  return HipLiveResult(
    reps,
    xs,
    fs,
    peaks,
    a.rows.length,
    a.leg,
    a.sideConflict,
    sw.elapsedMicroseconds / 1000.0,
  );
}

/// On-screen values while the set runs: the live leg angle (abd_leg_a of the current frame, deg) and the causal
/// counter on it (display, not scoring).
class HipTracker implements LiveTracker {
  final String side;
  final OnlineCounter _counter;

  HipTracker(this.side)
    : _counter = OnlineCounter(
        30.0,
        _refAmp,
        up: _counterFraction,
        drop: _counterFraction,
      );

  @override
  int get count => _counter.count;

  @override
  double add(PoseFrame frame) {
    final lm = frame.lm;
    if (lm == null) {
      _counter.add(double.nan);
      return double.nan;
    }
    final w = frame.width.toDouble(), h = frame.height.toDouble();
    double x(int j) => lm[j * 5] * w;
    double y(int j) => lm[j * 5 + 1] * h;
    final a = legIds[side]!;
    final hmx = 0.5 * (x(23) + x(24)), hmy = 0.5 * (y(23) + y(24));
    final tx = 0.5 * (x(11) + x(12)) - hmx, ty = 0.5 * (y(11) + y(12)) - hmy;
    final tn = math.sqrt(tx * tx + ty * ty);
    if (!(tn > 1e-9)) {
      _counter.add(double.nan);
      return double.nan;
    }
    final ux = tx / tn, uy = ty / tn;
    final outSign = x(a.hip) - hmx >= 0 ? 1.0 : -1.0;
    final lx = outSign * -uy,
        ly = outSign * ux; // sideways, toward the lifted leg
    final vx = x(a.ank) - x(a.hip), vy = y(a.ank) - y(a.hip);
    final angle = degrees(math.atan2(vx * lx + vy * ly, -(vx * ux + vy * uy)));
    _counter.add(angle);
    return angle;
  }
}
