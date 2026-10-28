/// Settings of the voice assistant (one place; no locale or timing values scattered in the code).
library;

class VoiceConfig {
  /// Speak instructions and corrections.
  final bool spokenFeedback;

  /// Android TTS speech rate (0.0-1.0; 0.5 is the engine's normal pace). Slower is easier during exercise.
  final double speechRate;

  /// The same correction is not repeated within this time (a patient making the same mistake every rep would
  /// otherwise hear it every 3 seconds).
  final Duration feedbackCooldown;
  final Duration instructionCooldown;
  final Duration unsureCooldown;

  /// One listening session after a tap on the microphone: stops after [listenFor] or [pauseFor] of silence.
  final Duration listenFor;
  final Duration pauseFor;

  /// Ask Android for on-device recognition only (no audio leaves the phone). Off by default because many phones
  /// have no on-device model for every language; then recognition would simply fail.
  final bool onDeviceOnly;

  const VoiceConfig({
    this.spokenFeedback = true,
    this.speechRate = 0.45,
    this.feedbackCooldown = const Duration(seconds: 8),
    this.instructionCooldown = const Duration(seconds: 6),
    this.unsureCooldown = const Duration(seconds: 20),
    this.listenFor = const Duration(seconds: 8),
    this.pauseFor = const Duration(seconds: 3),
    this.onDeviceOnly = false,
  });

  VoiceConfig copyWith({bool? spokenFeedback, double? speechRate}) =>
      VoiceConfig(
        spokenFeedback: spokenFeedback ?? this.spokenFeedback,
        speechRate: speechRate ?? this.speechRate,
        feedbackCooldown: feedbackCooldown,
        instructionCooldown: instructionCooldown,
        unsureCooldown: unsureCooldown,
        listenFor: listenFor,
        pauseFor: pauseFor,
        onDeviceOnly: onDeviceOnly,
      );
}

/// Text-to-speech voice for each app language (Android TTS language tags), and the preferred speech-recognition
/// locales (the first one the phone offers is used). What really works depends on the phone's installed engines.
const ttsLanguageFor = {'en': 'en-US', 'fr': 'fr-FR', 'ar': 'ar'};
const sttLocalesFor = {
  'en': ['en_US', 'en_GB', 'en'],
  'fr': ['fr_FR', 'fr_CA', 'fr'],
  'ar': ['ar_DZ', 'ar_MA', 'ar_TN', 'ar_SA', 'ar_EG', 'ar'],
};
