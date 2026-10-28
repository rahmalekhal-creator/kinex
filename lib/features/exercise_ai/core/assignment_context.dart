/// Which assignment a live set belongs to, so its result can be saved for the physiotherapist.
library;

class AssignmentContext {
  /// The patient's account id (as used by every API call).
  final int accountId;

  /// patientexercise.id of the assignment.
  final int patientExerciseId;

  /// Reps asked per set by the physiotherapist (0 = unknown): the set ends by itself when they are done.
  final int targetReps;

  /// e4: the physiotherapist's target lift angle (deg), null = not set.
  final double? targetDeg;

  /// e4: the patient's usual lift (median peak angle of their good-form reps so far, deg), null = not known yet.
  final double? usualLiftDeg;

  const AssignmentContext({
    required this.accountId,
    required this.patientExerciseId,
    this.targetReps = 0,
    this.targetDeg,
    this.usualLiftDeg,
  });
}
