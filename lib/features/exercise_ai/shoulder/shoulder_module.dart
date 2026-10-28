/// The shoulder exercises (e1, e2, e3) for the live assistant: assets, live scoring on the buffer
/// (analyze_video in a background isolate + the ONNX head), the per-frame silhouette and the on-screen tracker.
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kinex_pose/kinex_pose.dart';

import '../core/exercise_module.dart';
import '../core/np_port.dart';
import '../core/pose_recording.dart';
import 'shoulder_config.dart';
import 'shoulder_ds.dart' show repWindow;
import 'shoulder_lib.dart';
import 'shoulder_model.dart';
import 'shoulder_pipeline.dart';
import 'side_check.dart';
import 'sil_features.dart';

const _bundle = 'shoulder_app_bundle';
const _configFiles = {
  'multitask': 'mt_final.json',
  'separate': 'separate.json',
};

/// Median rep amplitude of the count signal in the golden recordings (e1 lift, e2 elev_a deg, e3 rot):
/// the reference amplitude of the causal on-screen counter (sl.online_count).
/// A rep on screen = a rise and a fall of at least this share of the reference amplitude (display only).
/// 0.5 keeps every rep of the golden recordings and ignores small incidental movements (checked in
/// test/shoulder/counter_check_test.dart); 0.6 already misses reps of a patient with a small range.
const _counterFraction = 0.5;

const _refAmp = {'e1': 1.50, 'e2': 86.4, 'e3': 1.74};

class ShoulderModule implements ExerciseModule {
  FeedbackSpec? _fb;
  ModelConfig? _cfg;
  ShoulderHeadModel? _model;
  _ScoringWorker? _worker;
  String? _loaded;

  @override
  String get name => 'Shoulder';

  @override
  List<String> get modelVariants => const ['multitask', 'separate'];

  @override
  List<ExerciseInfo> get exercises => const [
    ExerciseInfo(
      'e1',
      'Forward elevation with a stick',
      'Hold a stick with both hands and lift it forward and up, then lower it all the way down.',
      'Which arm is injured?',
    ),
    ExerciseInfo(
      'e2',
      'Arm abduction',
      'Lift one straight arm out to the side, then bring it back down along your body.',
      'Which arm does the exercise?',
    ),
    ExerciseInfo(
      'e3',
      'Arm rotation, elbow at the side',
      'Keep the elbow against your body, bent at 90 deg, and rotate the forearm outward and back.',
      'Which arm does the exercise?',
    ),
  ];

  @override
  Future<void> load(String exercise, String variant) async {
    final key = '$exercise/$variant';
    if (_loaded == key) return;
    _model?.close();
    final spec =
        jsonDecode(await rootBundle.loadString('$_bundle/app_spec.json'))
            as Map<String, dynamic>;
    _fb = FeedbackSpec.fromJson(spec);
    final mt = ModelConfig.fromJson(
      jsonDecode(await rootBundle.loadString('$_bundle/models/mt_final.json')),
    );
    _cfg = variant == 'multitask'
        ? mt
        : ModelConfig.fromJson(
            jsonDecode(
              await rootBundle.loadString(
                '$_bundle/models/${_configFiles[variant]}',
              ),
            ),
            fallbackAnalyze: mt.analyze,
          );
    final head = _cfg!.heads[exercise]!;
    final bytes = await rootBundle.load('$_bundle/models/${head.onnxFile}');
    _model = ShoulderHeadModel(
      head,
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      threads: 2,
    );
    _loaded = key;
  }

  @override
  bool needsMask(String exercise) =>
      _cfg?.heads[exercise]?.needsSilhouette ?? exercise == 'e2';

  @override
  List<String>? get extraNames => silNames;

  /// Silhouette numbers of the frame (2 x 9), rounded to float16 like the training data; null if not needed.
  @override
  Float32List? frameExtras(String exercise, PoseFrame frame) {
    if (!needsMask(exercise)) return null;
    final bits = frame.maskBits;
    final lm = frame.lm;
    final out = Float32List(18)..fillRange(0, 18, double.nan);
    if (bits == null || lm == null) return out;
    final s = silFeatures(
      PersonMask(frame.maskWidth, frame.maskHeight, bits),
      lm,
    );
    for (var i = 0; i < 18; i++) {
      out[i] = f16(s[i]);
    }
    return out;
  }

  @override
  LiveTracker tracker(String exercise, String side) =>
      ShoulderTracker(exercise, side);

  @override
  Future<ScoringUpdate> score(
    PoseRecording rec,
    String exercise,
    String side,
    List<double> alreadyScored, {
    bool finalPass = false,
  }) async {
    final cfg = _cfg!, head = cfg.heads[exercise]!, fb = _fb!;
    // one long-lived background isolate (spawning one per pass costs time and memory on a slow phone)
    final worker = _worker ??= await _ScoringWorker.spawn();
    final r = await worker.run(
      _Job(rec, exercise, side, cfg.analyze, head, alreadyScored, finalPass),
    );
    if (r == null) return const ScoringUpdate([], 0, null, false, 0);
    final sw = Stopwatch()..start();
    final probs = r.x.isEmpty
        ? const <List<double>>[]
        : _model!.predict(r.x, r.f);
    final onnxMs = sw.elapsedMicroseconds / 1000.0;
    final perRep = r.x.isEmpty ? 0.0 : onnxMs / r.x.length;
    final out = <RepVerdict>[];
    var j = 0;
    for (final rp in r.reps) {
      if (rp.wrongSide) {
        // the other arm did this rep: not scored and not counted, however good it was
        out.add(
          RepVerdict(
            rep: rp.rep,
            tPeakS: rp.tPeakS,
            scored: false,
            label: 'wrong_side',
            status: 'wrong_side',
            message:
                'Wrong arm - switch to your $side arm: this rep does not count',
            confidence: double.nan,
            probs: const [],
            bufferFrames: rec.length,
            bufferEndMs: rec.tMs.isEmpty ? double.nan : rec.tMs.last,
            pipelineMs: r.pipelineMs,
            onnxMs: 0,
          ),
        );
      } else if (rp.usable) {
        final v = verdict(fb, head, probs[j++], side);
        out.add(
          RepVerdict(
            rep: rp.rep,
            tPeakS: rp.tPeakS,
            scored: true,
            label: v.label,
            status: v.status,
            message: v.message,
            confidence: v.confidence,
            probs: v.probs,
            bufferFrames: rec.length,
            bufferEndMs: rec.tMs.isEmpty ? double.nan : rec.tMs.last,
            pipelineMs: r.pipelineMs,
            onnxMs: perRep,
          ),
        );
      } else {
        out.add(
          RepVerdict(
            rep: rp.rep,
            tPeakS: rp.tPeakS,
            scored: false,
            label: 'not_scored',
            status: 'not_scored',
            message: rp.partial ? fb.partial : fb.unsure,
            confidence: double.nan,
            probs: const [],
            bufferFrames: rec.length,
            bufferEndMs: rec.tMs.isEmpty ? double.nan : rec.tMs.last,
            pipelineMs: r.pipelineMs,
            onnxMs: 0,
          ),
        );
      }
    }
    return ScoringUpdate(out, r.repsFound, r.arm, r.sideConflict, r.pipelineMs);
  }

  @override
  void dispose() {
    _model?.close();
    _model = null;
    _loaded = null;
    _worker?.close();
    _worker = null;
  }
}

/// One scoring job for the worker isolate (everything in it can be sent to an isolate).
class _Job {
  final PoseRecording rec;
  final String exercise, side;
  final AnalyzeConfig cfg;
  final HeadConfig head;
  final List<double> alreadyScored;
  final bool finalPass;
  const _Job(
    this.rec,
    this.exercise,
    this.side,
    this.cfg,
    this.head,
    this.alreadyScored,
    this.finalPass,
  );
}

/// A background isolate that stays alive for the whole set and runs [_analyzeForLive] for each pass, so the
/// camera / UI isolate never runs the pipeline and no isolate is spawned per pass.
class _ScoringWorker {
  final Isolate _isolate;
  final SendPort _jobs;
  _ScoringWorker._(this._isolate, this._jobs);

  static Future<_ScoringWorker> spawn() async {
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(
      _main,
      ready.sendPort,
      debugName: 'kinex-scoring',
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
          _analyzeForLive(
            job.rec,
            job.exercise,
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

  Future<_LiveResult?> run(_Job job) async {
    final reply = ReceivePort();
    _jobs.send((reply.sendPort, job));
    final r = await reply.first;
    reply.close();
    return r as _LiveResult?;
  }

  void close() => _isolate.kill(priority: Isolate.immediate);
}

class _LiveRep {
  final int rep;
  final double tPeakS;
  final bool usable, partial;

  /// Done with the arm other than the prescribed one (single-arm exercises): not scored, not counted.
  final bool wrongSide;
  const _LiveRep(
    this.rep,
    this.tPeakS,
    this.usable,
    this.partial, {
    this.wrongSide = false,
  });
}

class _LiveResult {
  final List<_LiveRep> reps; // the newly finished reps, in order
  final List<List<Float32List>> x; // inputs of the usable ones
  final List<Float32List> f;
  final int repsFound;
  final String arm;
  final bool sideConflict;
  final double pipelineMs;
  const _LiveResult(
    this.reps,
    this.x,
    this.f,
    this.repsFound,
    this.arm,
    this.sideConflict,
    this.pipelineMs,
  );
}

/// Runs in a background isolate: the whole pipeline on the buffer, then keeps the reps that are finished
/// (their end + 0.5 s is in the buffer and the count signal is back at rest, or the next rep has started)
/// and not scored yet (matched by peak time).
_LiveResult? _analyzeForLive(
  PoseRecording rec,
  String ex,
  String side,
  AnalyzeConfig cfg,
  HeadConfig head,
  List<double> alreadyScored,
  bool finalPass,
) {
  final sw = Stopwatch()..start();
  final a = analyzeVideo(rec, ex, side, cfg, head);
  if (a == null) return null;
  final n = a.r.n, m = pyRound(cfg.marginS * cfg.fs);
  final s = a.s;
  final t0 = a.r.t[0];
  final reps = <_LiveRep>[];
  final xs = <List<Float32List>>[], fs = <Float32List>[];
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
    if (singleArm[ex]! && !rp.partial) {
      final (w0, w1) = repWindow(rp, n, cfg.fs, cfg.marginS);
      if (wrongArmInWindow(a.r, w0, w1, side)) {
        reps.add(_LiveRep(row.rep, tPeak, false, rp.partial, wrongSide: true));
        continue;
      }
    }
    reps.add(_LiveRep(row.rep, tPeak, row.usable, rp.partial));
    if (row.usable) {
      final j = a.use.indexOf(k);
      xs.add(a.x[j]);
      fs.add(a.f[j]);
    }
  }
  return _LiveResult(
    reps,
    xs,
    fs,
    a.rows.length,
    a.arm,
    a.sideConflict,
    sw.elapsedMicroseconds / 1000.0,
  );
}

/// On-screen values while the set runs: the live arm angle (app_spec pipeline.angle_signal) and the causal
/// counter sl.online_count on the count signal, both from the current frame only (display, not scoring).
class ShoulderTracker implements LiveTracker {
  final String ex, side;
  final OnlineCounter _counter;
  double _lu = 0, _lf = 0;

  ShoulderTracker(this.ex, this.side)
    : _counter = OnlineCounter(
        30.0,
        _refAmp[ex]!,
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
    final a = armIds[side]!, o = armIds[otherSide[side]]!;
    final smx = 0.5 * (x(lSh) + x(rSh)), smy = 0.5 * (y(lSh) + y(rSh));
    final tl = math.sqrt(
      math.pow(smx - 0.5 * (x(lHip) + x(rHip)), 2) +
          math.pow(smy - 0.5 * (y(lHip) + y(rHip)), 2),
    );
    double count, angle;
    if (ex == 'e2') {
      angle = ang2(x(a.el) - x(a.sh), y(a.el) - y(a.sh), 0, 1);
      count = angle;
    } else if (ex == 'e1') {
      double est(ArmIds j) {
        final ua = math.sqrt(
          math.pow(x(j.el) - x(j.sh), 2) + math.pow(y(j.el) - y(j.sh), 2),
        );
        _lu = math.max(_lu, ua);
        return degrees(math.acos(clip((y(j.el) - y(j.sh)) / _lu, -1, 1)));
      }

      angle = 0.5 * (est(a) + est(o));
      count = 0.5 * ((smy - y(a.wr)) / tl + (smy - y(o.wr)) / tl);
    } else {
      final ua = math.sqrt(
        math.pow(x(a.el) - x(a.sh), 2) + math.pow(y(a.el) - y(a.sh), 2),
      );
      final fa = math.sqrt(
        math.pow(x(a.wr) - x(a.el), 2) + math.pow(y(a.wr) - y(a.el), 2),
      );
      _lu = math.max(_lu, ua);
      _lf = math.max(_lf, math.max(fa, 0.78 * _lu));
      final outSign = x(a.sh) - smx >= 0 ? 1.0 : -1.0;
      count = outSign * (x(a.wr) - x(a.el)) / _lf;
      angle = degrees(math.asin(clip(count, -1, 1)));
    }
    _counter.add(count);
    return angle;
  }
}

/// Debug log of the timings (Phase 4 adds the export).
void logTiming(String what) {
  if (kDebugMode || kProfileMode) debugPrint('[kinex timing] $what');
}
