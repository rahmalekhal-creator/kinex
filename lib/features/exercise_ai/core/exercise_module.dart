/// What the generic live screen needs from an exercise family (shoulder now; hip etc. later the same way).
library;

import 'dart:typed_data';

import 'package:kinex_pose/kinex_pose.dart';

import 'pose_recording.dart';

class ExerciseInfo {
  final String id, title, description;

  /// Side question for this exercise ('Which arm does the exercise?' / 'Which arm is injured?').
  final String sideQuestion;
  const ExerciseInfo(this.id, this.title, this.description, this.sideQuestion);
}

/// A rep the module has judged.
class RepVerdict {
  final int rep; // 1-based number in the set
  final double
  tPeakS; // time of the peak (s, from the first frame of the recording)
  final bool scored;
  final String label; // class name, or 'not_scored'
  final String
  status; // good / mistake / unsure / not_scored / below_target (e4) / wrong_side
  final String message;
  final double confidence;
  final List<double> probs;

  /// Frames in the buffer when this rep was scored (reproduce with the reference: cut the recording there).
  final int bufferFrames;
  final double bufferEndMs;
  final double pipelineMs, onnxMs;

  /// e4: the leg angle at the top of the rep and the range target it was judged against (deg); NaN otherwise.
  final double peakDeg, targetDeg;

  const RepVerdict({
    required this.rep,
    required this.tPeakS,
    required this.scored,
    required this.label,
    required this.status,
    required this.message,
    required this.confidence,
    required this.probs,
    required this.bufferFrames,
    required this.bufferEndMs,
    required this.pipelineMs,
    required this.onnxMs,
    this.peakDeg = double.nan,
    this.targetDeg = double.nan,
  });

  /// The same verdict with another rep number (reps of a set resumed after a pause continue the numbering).
  RepVerdict withRep(int n) => RepVerdict(
    rep: n,
    tPeakS: tPeakS,
    scored: scored,
    label: label,
    status: status,
    message: message,
    confidence: confidence,
    probs: probs,
    bufferFrames: bufferFrames,
    bufferEndMs: bufferEndMs,
    pipelineMs: pipelineMs,
    onnxMs: onnxMs,
    peakDeg: peakDeg,
    targetDeg: targetDeg,
  );

  Map<String, dynamic> toJson() => {
    'rep': rep,
    't_peak_s': tPeakS,
    'scored': scored,
    'label': label,
    'status': status,
    'message': message,
    'confidence': confidence,
    'probs': probs,
    'buffer_frames': bufferFrames,
    'buffer_end_ms': bufferEndMs,
    'pipeline_ms': pipelineMs,
    'onnx_ms': onnxMs,
    if (peakDeg.isFinite) 'peak_deg': peakDeg,
    if (targetDeg.isFinite) 'target_deg': targetDeg,
  };
}

/// Result of one scoring pass over the buffer.
class ScoringUpdate {
  final List<RepVerdict> newVerdicts;
  final int
  repsFound; // reps found by the offline segmentation (partial ones included)
  final String? arm; // arm the pipeline uses
  final bool sideConflict;
  final double pipelineMs;
  const ScoringUpdate(
    this.newVerdicts,
    this.repsFound,
    this.arm,
    this.sideConflict,
    this.pipelineMs,
  );
}

/// Live, per-frame values for the screen (display only; the scored reps come from the offline pipeline).
abstract class LiveTracker {
  /// Feeds one frame; returns the angle to show (deg) or NaN.
  double add(PoseFrame frame);
  int get count;
}

abstract class ExerciseModule {
  String get name;
  List<ExerciseInfo> get exercises;

  /// The available model variants (e.g. multitask / separate); the first is the default.
  List<String> get modelVariants;

  Future<void> load(String exercise, String variant);
  bool needsMask(String exercise);

  /// Per-frame extra numbers stored with the frame (e.g. silhouette), or null.
  Float32List? frameExtras(String exercise, PoseFrame frame);
  List<String>? get extraNames;

  LiveTracker tracker(String exercise, String side);

  /// Scores the reps of [rec] that are finished and not in [alreadyScored] (their peak times, s).
  /// [finalPass]: the set is over, every finished rep counts as final.
  Future<ScoringUpdate> score(
    PoseRecording rec,
    String exercise,
    String side,
    List<double> alreadyScored, {
    bool finalPass = false,
  });

  void dispose();
}
