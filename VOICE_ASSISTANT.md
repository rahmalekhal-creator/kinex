# Voice assistant (live exercise screen)

The voice assistant speaks instructions and the model's corrections, and understands short spoken commands. It is free:
it uses Android's own text-to-speech and speech-recognition services through the free Flutter packages
`flutter_tts` and `speech_to_text`. There is no AI service, no paid API and no API key. The commands are recognised by
fixed rules, not by a language model.

## Where the code is

| File | What it does |
|---|---|
| `lib/features/exercise_ai/core/session_controls.dart` | The session states (`SessionPhase`, incl. `paused`), `PauseReason`, `SessionEvent`, and the small interface the assistant and the buttons use (`VoiceSessionControls`) |
| `lib/features/exercise_ai/core/live_session.dart` | The real session controller: `pause`, `resume`, `reportPain`, pain hold, event log |
| `lib/features/exercise_ai/voice/voice_config.dart` | All settings: speech rate, cooldowns, listening times, languages |
| `lib/features/exercise_ai/voice/voice_commands.dart` | Spoken text → command (pure Dart, English / French / Arabic) |
| `lib/features/exercise_ai/voice/voice_lines.dart` | Every spoken sentence, from the app translations (`lib/l10n/app_*.arb`) |
| `lib/features/exercise_ai/voice/speech_io.dart` | Text-to-speech and speech recognition behind two interfaces (the real plugins, or fakes in tests) |
| `lib/features/exercise_ai/voice/voice_assistant.dart` | The assistant: speech queue, what to say when, the commands |
| `lib/features/exercise_ai/widgets/live_controls.dart` | Pause / Resume / I feel pain / Finish buttons and the microphone button |
| `test/voice/` | Command parser and assistant tests |

## Session states

The session phase and the assistant's state are separate: `SessionPhase` is
`positioning → stillCountdown → active ⇄ paused → finishing → done`, with a pain hold flag on top. `AssistantState` is
idle / listening / processing / speaking / unavailable / permission denied / error.

| From | To | When |
|---|---|---|
| ready (positioning, still) | active | after 2 s standing still |
| running | paused | Pause button, "pause", "I'm uncomfortable", an unclear sentence about pain |
| running or paused | paused + **pain hold** | "it hurts" / "I feel pain" / "I'm in pain"..., or the **I feel pain** button |
| paused (no pain hold) | positioning → active | Resume button or "continue"; a new 2-second stand-still first |
| paused + pain hold | (stays) | "continue", Resume and `resume()` are refused |
| active or paused | finishing → done | Finish the set (also the only way out of the pain hold), or automatically after **n good reps or 2n reps in total**, n being the reps the physiotherapist set for the exercise (10 if none) (`goodTarget` / `maxReps` of `LiveSession`) |

- **While paused:** nothing is recorded or judged. A rep cut by the pause is not counted.
- **After resume:** analysis restarts on a new segment, so the paused gap never becomes part of a movement.
- **Repeated pauses or pain reports:** they do nothing and add no duplicate event.

## Spoken feedback

The assistant follows the session (its phase and its new verdicts). It never looks at camera frames, and every speech
call is asynchronous, so it cannot slow the pose pipeline.

- **What it says:** only what the model produced.
  - A rep judged as a mistake: the class message of `app_spec.json`, translated.
  - A good rep: "Good rep" for the first one, then only the count of good reps ("2", "3"...).
  - A rep whose confidence was under 0.5 (status `unsure`): "Not sure about this rep - check that your whole body is
    in view". It never states a mistake as a fact.
- **Duplicate suppression:**
  - The same correction is not repeated within 8 s.
  - "Not sure" is not repeated within 20 s, and instructions within 6 s. The good-rep count is never suppressed.
  - When several reps are judged in one pass, only the newest one is spoken.
- **Priorities:** safety > instruction > feedback > info. A higher priority line interrupts a lower one. During a pause
  no feedback is spoken; during the pain hold only safety lines are spoken.
- **Stopping:** leaving the screen or finishing the set stops speech and cancels listening.

## Voice commands

The microphone listens only after a tap on the microphone button (one short session, about 8 s, ending after 3 s of
silence). Matching is conservative and works in English, French and Arabic (incl. common Algerian forms) whatever the
app language.

| The patient says (examples) | What happens |
|---|---|
| "repeat", "répète", "كرر" | the last instruction again |
| "I don't understand", "explain again", "je ne comprends pas", "لم أفهم" | a simpler version of the last instruction |
| "pause", "stop exercise", "arrête", "توقف" | the set is paused (same as the Pause button) |
| "continue", "resume", "on reprend", "استمر" | resumes after an ordinary pause; **refused during the pain hold** |
| "help", "aide", "مساعدة" | lists the commands |
| "it hurts", "I feel pain", "I'm in pain", "j'ai mal", "ça fait mal", "أشعر بألم", "يوجعني" | **pain workflow** |
| "I'm uncomfortable", "je suis mal à l'aise", "غير مرتاح" | pause, and ask whether it hurts |
| a sentence about pain that is not a clear report: a question ("does it hurt if...?"), a negation ("no pain"), another time ("I had pain yesterday"), the word alone | pause, and ask whether it hurts now; no pain event is recorded |
| a negated command ("don't stop"), a long unrelated sentence | nothing (and "Sorry, I did not understand") |

When several commands arrive together, they run one after the other, so two session operations never overlap.

## Pain workflow

1. **Pause and hold:** the session pauses through its own pause and sets the **pain hold**. Ordinary coaching is
   dropped and speech recognition stops.
2. **Spoken response:** "I heard that you are in pain. The exercise is paused. Please follow your physiotherapist's
   guidance before continuing."
3. **Screen:** a red card says the same, adds that this is what the patient reported and not a medical diagnosis,
   and only **Finish the set** remains.
4. **Recorded event:** one `pain_report` event is recorded, with the source (voice or button) and what was heard.
   Its time appears in the report sent to the physiotherapist (progress notes and AI feedback): "Patient-reported pain
   at m:ss (by voice) - reported by the patient, not a medical finding". The summary page also asks for a pain level
   from 0 to 10.
5. **No resume:** nothing resumes the set. Not the end of the speech, not "continue", not `resume()`. The project has
   no clinician-approved resume procedure, so the hold stays until the set is ended.
6. **Without the voice:** the **I feel pain** button does the same, and works even when speech recognition is
   unavailable.

The assistant never tells the patient to continue, never names a cause, and never recommends a treatment.

## Languages

- **Which language:** the voice follows the app language (English, French, Arabic: `ttsLanguageFor` /
  `sttLocalesFor` in `voice_config.dart`).
- **No voice for the language:** if the phone has no TTS voice for it, the assistant speaks English and the screen
  says so.
- **Recognition:** the best locale the phone offers is used (for Arabic: ar_DZ, ar_MA, ar_TN, ar_SA, ar_EG...).
- **Not every phone:** what works depends on the phone's installed engines. **French and Arabic have not been tested
  on a phone yet.** To install a voice: Settings → System → Languages → Text-to-speech output (Google
  Speech Services) → install voice data.
- **Speech rate:** set by the patient on the setup screen (Voice assistant → Speaking speed).

## Privacy and offline

- **No uploads by the app:** it never sends camera frames, audio or video anywhere.
- **Recognition may go online:** speech recognition is done by the phone's recognition service (usually Google's).
  Depending on the phone and language it may work offline or send audio to that service.
  `VoiceConfig.onDeviceOnly = true` forces on-device recognition, but it then fails on phones without an offline model
  for the language.
- **Text-to-speech:** usually works offline once the voice is installed.

## Android setup

- **Permissions:** `RECORD_AUDIO` and `INTERNET` were already declared.
- **Added to `<queries>`:** `android.speech.RecognitionService` and `android.intent.action.TTS_SERVICE`. Android 11+
  needs them to find the services.
- **Microphone permission:** asked only when the patient first taps the microphone. If it is refused, the microphone
  button explains it and the app does not ask again by itself.

## Testing on a phone

1. Build and install: `powershell -ExecutionPolicy Bypass -File tool\phone.ps1`.
2. Log in as a patient, open an exercise with live tracking, then Start Exercise. Leave **Voice assistant** on.
3. **TTS:** during the "stand still" step you should hear "Stand still for two seconds", then "You can start", then a
   correction or "Good rep" after the reps.
4. **Microphone:** tap it (allow the permission the first time) and say "repeat", "help", "pause", then "continue".
5. **Pain:** say "it hurts". The set pauses, the red card appears, "continue" is refused, and only Finish is left. On
   the summary the pain report is shown and sent to the physiotherapist.
6. **Without a microphone:** refuse the permission. Pause and I feel pain must still work.
7. **Other languages:** switch the app language to French or Arabic and repeat steps 3-5.

## Tests

`flutter test test/voice/` (no phone, no microphone: TTS and recognition are faked; pausing uses the real
`LiveSession`).

- **`command_parser_test.dart`:** clear pain, ambiguous pain (questions, negations, other times), discomfort, every
  command, no false triggers, normalisation (EN / FR / AR).
- **`voice_assistant_test.dart`:**
  - a correction is spoken;
  - low confidence is not stated as a mistake;
  - no repeated correction within the cooldown;
  - "repeat";
  - "I don't understand" (simpler text);
  - "pause" calls the real pause;
  - a pain report pauses, holds and records one event (voice and button);
  - the hold is not bypassed by "continue" / `resume()`;
  - ambiguous pain pauses and asks without a pain event;
  - recognition unavailable or permission refused: the manual Pause and I feel pain buttons still work;
  - ending the session stops speech and releases the plugins;
  - simultaneous commands don't conflict;
  - speech never blocks the session;
  - feedback is silenced during the pain hold;
  - language fallback.
- **`set_progress_test.dart`:** good reps counted aloud ("Good rep", then "2", "3"), the set ends after n good reps
  or 2n reps in total, the battery colours one cell per rep.
