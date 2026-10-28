/// Speech in and out, behind two small interfaces so the assistant can be tested without a phone.
/// Implementations use the free plugins flutter_tts (Android TextToSpeech) and speech_to_text (Android
/// SpeechRecognizer). No paid service, no API key; this code sends no audio anywhere itself (the phone's own
/// recognition service may, unless VoiceConfig.onDeviceOnly is set).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'voice_config.dart';

/// Text to speech.
abstract class SpeechOutput {
  /// Prepares the engine for [languageTag] ('fr-FR'...). Returns false when that language is not available.
  Future<bool> init(String languageTag, double rate);

  /// Speaks [text]; completes when it has been said (or stopped).
  Future<void> speak(String text);

  Future<void> stop();
  Future<void> dispose();
}

enum SttAvailability { available, permissionDenied, unavailable }

/// Speech recognition: one short listening session at a time.
abstract class SpeechInput {
  /// Asks for the microphone permission the first time (call it only after a user action).
  Future<SttAvailability> init();

  /// The best recognition locale for an app language, or null (= the phone's default).
  Future<String?> localeFor(String language);

  /// Starts listening. [onFinal] gets the recognised text once; [onEnd] is called when listening stops for any
  /// reason (with an error text, or null).
  Future<bool> listen({
    String? localeId,
    required void Function(String text) onFinal,
    required void Function(String? error) onEnd,
    void Function(String partial)? onPartial,
  });

  Future<void> stop();
  Future<void> cancel();
}

class FlutterTtsOutput implements SpeechOutput {
  final FlutterTts _tts = FlutterTts();

  @override
  Future<bool> init(String languageTag, double rate) async {
    try {
      await _tts.awaitSpeakCompletion(true);
      final ok = await _tts.isLanguageAvailable(languageTag);
      if (ok != true) return false;
      await _tts.setLanguage(languageTag);
      await _tts.setSpeechRate(rate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      return true;
    } catch (e) {
      debugPrint('[kinex voice] TTS init failed: $e');
      return false;
    }
  }

  @override
  Future<void> speak(String text) async {
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[kinex voice] TTS speak failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() => stop();
}

class SpeechToTextInput implements SpeechInput {
  final VoiceConfig config;
  final SpeechToText _stt = SpeechToText();
  bool _initDone = false;
  void Function(String? error)? _onEnd;
  bool _gotFinal = false;

  SpeechToTextInput(this.config);

  @override
  Future<SttAvailability> init() async {
    if (_initDone) {
      return _stt.isAvailable
          ? SttAvailability.available
          : SttAvailability.unavailable;
    }
    try {
      final ok = await _stt.initialize(onError: _onError, onStatus: _onStatus);
      _initDone = true;
      if (ok) return SttAvailability.available;
      final perm = await _stt.hasPermission;
      return perm
          ? SttAvailability.unavailable
          : SttAvailability.permissionDenied;
    } catch (e) {
      debugPrint('[kinex voice] speech recognition init failed: $e');
      _initDone = true;
      return SttAvailability.unavailable;
    }
  }

  @override
  Future<String?> localeFor(String language) async {
    try {
      final ids = (await _stt.locales())
          .map((l) => l.localeId.replaceAll('-', '_'))
          .toList();
      for (final want in sttLocalesFor[language] ?? const <String>[]) {
        for (final id in ids) {
          if (id == want || (want.length == 2 && id.startsWith('${want}_'))) {
            return id;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _onError(SpeechRecognitionError e) {
    final end = _onEnd;
    _onEnd = null;
    end?.call(e.errorMsg);
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      final end = _onEnd;
      if (end != null && status == SpeechToText.doneStatus) {
        _onEnd = null;
        end(_gotFinal ? null : 'no_match');
      }
    }
  }

  @override
  Future<bool> listen({
    String? localeId,
    required void Function(String text) onFinal,
    required void Function(String? error) onEnd,
    void Function(String partial)? onPartial,
  }) async {
    if (!_stt.isAvailable || _stt.isListening) return false;
    _onEnd = onEnd;
    _gotFinal = false;
    try {
      await _stt.listen(
        onResult: (r) {
          if (r.finalResult) {
            _gotFinal = true;
            onFinal(r.recognizedWords);
          } else {
            onPartial?.call(r.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: config.listenFor,
          pauseFor: config.pauseFor,
          partialResults: true,
          onDevice: config.onDeviceOnly,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
      return true;
    } catch (e) {
      _onEnd = null;
      onEnd('$e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }

  @override
  Future<void> cancel() async {
    _onEnd = null;
    try {
      await _stt.cancel();
    } catch (_) {}
  }
}
