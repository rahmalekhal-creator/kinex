/// Every sentence the assistant says or shows about a rep, from the app's translations (lib/l10n): one place,
/// nothing hard-coded in widgets or controllers. Each line has a short text and, when useful, a simpler one for
/// "I don't understand".
library;

import 'package:reeducation/l10n/l10n.dart';

import '../core/exercise_module.dart';
import '../core/np_port.dart' show pyRound;
import '../core/tracked_exercises.dart';

enum VoicePriority { info, feedback, instruction, safety }

class VoiceLine {
  /// Identifies the line for duplicate suppression (the same key is not repeated within its cooldown).
  final String key;
  final String text;

  /// Simpler wording for "I don't understand" (null = same as [text]).
  final String? simple;
  final VoicePriority priority;

  /// Remembered as "the last instruction" for "repeat" / "I don't understand".
  final bool remember;

  const VoiceLine(
    this.key,
    this.text, {
    this.simple,
    this.priority = VoicePriority.info,
    this.remember = false,
  });
}

String armWord(AppLocalizations l, String side) =>
    side == 'left' ? l.armSideLeft : l.armSideRight;

/// Degrees as the spec messages show them (Python '{:.0f}': half to even); 0 when unknown.
int roundDeg(double d) => d.isFinite ? pyRound(d) : 0;

String legWord(AppLocalizations l, String side) =>
    side == 'left' ? l.legSideLeft : l.legSideRight;

/// The side of exercise [ex] in words: the arm, or the leg for a leg exercise (e4).
String sideWord(AppLocalizations l, String ex, String side) =>
    isLegExercise(ex) ? legWord(l, side) : armWord(l, side);

String bodyRegionLabel(AppLocalizations l, String? region) => switch (region) {
  'shoulder' => l.bodyRegionShoulder,
  'hip' => l.bodyRegionHip,
  _ => l.bodyRegionOther,
};

/// A short, readable name of a rep's result (label, or status for below_target / wrong_side / unsure).
String repLabelName(AppLocalizations l, String ex, RepVerdict v) {
  switch (v.status) {
    case 'below_target':
      return l.repLabelBelowTarget;
    case 'wrong_side':
      return l.repLabelWrongSide;
    case 'unsure':
    case 'not_scored':
      return l.repLabelUnsure;
    case 'good':
      return l.repLabelGood;
  }
  return switch (v.label) {
    'knee' => l.repLabelKnee,
    'leanin' => l.repLabelLeanin,
    'leanout' => l.repLabelLeanout,
    _ => feedbackText(l, ex, v, ''),
  };
}

String exerciseTitle(AppLocalizations l, String ex) => switch (ex) {
  'e1' => l.exE1Title,
  'e2' => l.exE2Title,
  'e4' => l.exE4Title,
  _ => l.exE3Title,
};

String exerciseDescription(AppLocalizations l, String ex) => switch (ex) {
  'e1' => l.exE1Desc,
  'e2' => l.exE2Desc,
  'e4' => l.exE4Desc,
  _ => l.exE3Desc,
};

String exerciseSimple(AppLocalizations l, String ex) => switch (ex) {
  'e1' => l.exE1Simple,
  'e2' => l.exE2Simple,
  'e4' => l.exE4Simple,
  _ => l.exE3Simple,
};

String trackedExerciseLabel(AppLocalizations l, String? id) => switch (id) {
  'e1' => l.trackedE1,
  'e2' => l.trackedE2,
  'e3' => l.trackedE3,
  'e4' => l.trackedE4,
  _ => l.trackedNone,
};

/// The verdict of a rep in the app language: the class message of app_spec.json (good / mistake), the "unsure"
/// message when the model's confidence was below the threshold, or the "not scored" message.
/// [simple]: the simpler wording.
String feedbackText(
  AppLocalizations l,
  String ex,
  RepVerdict v,
  String side, {
  bool simple = false,
}) {
  final leg = isLegExercise(ex);
  if (v.status == 'wrong_side') {
    final w = sideWord(l, ex, side);
    if (leg) return simple ? l.fbWrongLegSimple(w) : l.fbWrongLeg(w);
    return simple ? l.fbWrongArmSimple(w) : l.fbWrongArm(w);
  }
  if (v.status == 'not_scored') {
    if (v.message.contains('cut')) return l.fbPartial;
    return leg ? l.fbE4Unsure : l.fbUnsure;
  }
  if (v.status == 'unsure') {
    if (leg) return simple ? l.fbE4UnsureSimple : l.fbE4Unsure;
    return simple ? l.fbUnsureSimple : l.fbUnsure;
  }
  if (v.status == 'below_target') {
    return simple
        ? l.fbBelowTargetSimple
        : l.fbBelowTarget(roundDeg(v.targetDeg), roundDeg(v.peakDeg));
  }
  if (v.status == 'good') return l.fbGood;
  final arm = armWord(l, side);
  return switch ((ex, v.label)) {
    ('e1', 'elb') => simple ? l.fbE1ElbSimple : l.fbE1Elb,
    ('e1', 'rngdown') => simple ? l.fbE1RngdownSimple : l.fbE1Rngdown,
    ('e1', 'imb') => simple ? l.fbE1ImbSimple : l.fbE1Imb(arm),
    ('e2', 'elb') => simple ? l.fbE2ElbSimple : l.fbE2Elb,
    ('e2', 'rngdown') => simple ? l.fbE2RngdownSimple : l.fbE2Rngdown,
    ('e2', 'shld') => simple ? l.fbE2ShldSimple : l.fbE2Shld,
    ('e2', 'lean') => simple ? l.fbE2LeanSimple : l.fbE2Lean,
    ('e3', 'wrong') => simple ? l.fbE3WrongSimple : l.fbE3Wrong,
    ('e4', 'knee') => simple ? l.fbE4KneeSimple : l.fbE4Knee(legWord(l, side)),
    ('e4', 'leanin') => simple ? l.fbE4LeaninSimple : l.fbE4Leanin,
    ('e4', 'leanout') => simple ? l.fbE4LeanoutSimple : l.fbE4Leanout,
    _ =>
      v.message, // a class without a translation: the model's own (English) message
  };
}

/// The spoken lines of one set.
class VoiceLines {
  final AppLocalizations l;
  final String exercise, side;
  const VoiceLines(this.l, this.exercise, this.side);

  VoiceLine get stepBack => VoiceLine(
    'step_back',
    isLegExercise(exercise) ? l.voiceStepBackFeet : l.voiceStepBack,
    priority: VoicePriority.instruction,
    remember: true,
  );
  VoiceLine get standStill => VoiceLine(
    'stand_still',
    l.voiceStandStill,
    priority: VoicePriority.instruction,
    remember: true,
  );

  /// "You can start", remembered as the exercise instruction (repeat = how to do it, simpler = short steps).
  VoiceLine get start => VoiceLine(
    'start',
    l.voiceStart(exerciseTitle(l, exercise)),
    priority: VoicePriority.instruction,
  );
  VoiceLine get exerciseInstruction => VoiceLine(
    'exercise',
    exerciseDescription(l, exercise),
    simple: exerciseSimple(l, exercise),
    priority: VoicePriority.instruction,
    remember: true,
  );

  VoiceLine get paused =>
      VoiceLine('paused', l.voicePaused, priority: VoicePriority.instruction);
  VoiceLine get resumed =>
      VoiceLine('resumed', l.voiceResumed, priority: VoicePriority.instruction);
  VoiceLine get painResponse =>
      VoiceLine('pain', l.voicePainResponse, priority: VoicePriority.safety);
  VoiceLine get painHoldRefuse => VoiceLine(
    'pain_hold',
    l.voicePainHoldRefuse,
    priority: VoicePriority.safety,
  );
  VoiceLine get uncomfortable => VoiceLine(
    'discomfort',
    l.voiceUncomfortable,
    priority: VoicePriority.safety,
  );
  VoiceLine get painClarify => VoiceLine(
    'pain_clarify',
    l.voicePainClarify,
    priority: VoicePriority.safety,
  );
  VoiceLine get help =>
      VoiceLine('help', l.voiceHelp, priority: VoicePriority.instruction);
  VoiceLine get notUnderstood => VoiceLine(
    'not_understood',
    l.voiceNotUnderstood,
    priority: VoicePriority.instruction,
  );
  VoiceLine get nothingToRepeat => VoiceLine(
    'nothing_to_repeat',
    l.voiceNothingToRepeat,
    priority: VoicePriority.instruction,
  );
  VoiceLine get alreadyRunning => VoiceLine(
    'running',
    l.voiceAlreadyRunning,
    priority: VoicePriority.instruction,
  );

  /// The first good rep of the set.
  VoiceLine get firstGoodRep =>
      VoiceLine('good_1', l.fbGood, priority: VoicePriority.feedback);

  /// The count of good reps, said after each good rep from the second one ("2", "3"...).
  VoiceLine goodCount(int n) =>
      VoiceLine('good_$n', '$n', priority: VoicePriority.feedback);

  /// The verdict of one rep: only what the model produced (good / one of its mistake classes), or "not sure"
  /// when its confidence was below the threshold (never a mistake stated as a fact). Null = nothing to say.
  VoiceLine? forVerdict(RepVerdict v) {
    switch (v.status) {
      case 'mistake':
        return VoiceLine(
          'fb_${v.label}',
          feedbackText(l, exercise, v, side),
          simple: feedbackText(l, exercise, v, side, simple: true),
          priority: VoicePriority.feedback,
          remember: true,
        );
      case 'unsure':
        return VoiceLine(
          'fb_unsure',
          feedbackText(l, exercise, v, side),
          simple: feedbackText(l, exercise, v, side, simple: true),
          priority: VoicePriority.feedback,
          remember: true,
        );
      case 'below_target':
        return VoiceLine(
          'fb_below_target',
          feedbackText(l, exercise, v, side),
          simple: feedbackText(l, exercise, v, side, simple: true),
          priority: VoicePriority.feedback,
          remember: true,
        );
      case 'wrong_side':
        // an instruction, not a form remark: the rep does not count until the patient switches
        return VoiceLine(
          'fb_wrong_side',
          feedbackText(l, exercise, v, side),
          simple: feedbackText(l, exercise, v, side, simple: true),
          priority: VoicePriority.instruction,
          remember: true,
        );
      case 'good':
        return VoiceLine('fb_good', l.fbGood, priority: VoicePriority.feedback);
      default:
        return null; // not scored (cut by the start/end): nothing worth saying during the set
    }
  }
}
