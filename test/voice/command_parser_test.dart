// The spoken-command parser: clear commands, conservative pain handling, no false triggers. EN / FR / AR.
import 'package:flutter_test/flutter_test.dart';
import 'package:reeducation/features/exercise_ai/voice/voice_commands.dart';

void main() {
  const p = VoiceCommandParser();
  VoiceCommandType t(String s) => p.parse(s).type;

  void expectAll(VoiceCommandType type, List<String> phrases) {
    for (final s in phrases) {
      expect(t(s), type, reason: '"$s"');
    }
  }

  test('clear pain reports -> painReport', () {
    expectAll(VoiceCommandType.painReport, [
      'It hurts',
      'it hurts!',
      'I feel pain',
      "I'm in pain",
      'im in pain',
      'I am in pain',
      'my shoulder hurts',
      'My shoulder really hurts.',
      'ouch',
      "J'ai mal",
      'j ai mal',
      'Ça fait mal',
      "j'ai très mal à l'épaule",
      'je ressens une douleur',
      'Aïe',
      'أشعر بألم',
      'اشعر بالالم',
      'عندي ألم',
      'يوجعني',
      'راني نحس بالوجع',
    ]);
  });

  test(
    'pain words that are not a clear present report -> painAmbiguous (pause and ask, never ignored)',
    () {
      expectAll(VoiceCommandType.painAmbiguous, [
        'does it hurt if I lift higher?', // a question
        'is it normal to feel pain', // a question
        'no pain', // negation: not ignored, the assistant asks
        "it doesn't hurt",
        'I had pain yesterday', // another time
        'pain', // the word alone
        "est-ce que ça fait mal ?",
        "je n'ai pas mal",
        'هل هذا الألم عادي؟',
        'لا أشعر بألم',
      ]);
    },
  );

  test('discomfort -> uncomfortable', () {
    expectAll(VoiceCommandType.uncomfortable, [
      "I'm uncomfortable",
      'this is uncomfortable',
      "je suis mal à l'aise",
      'غير مرتاح',
    ]);
  });

  test('pause / resume / repeat / simpler / help', () {
    expectAll(VoiceCommandType.pause, [
      'Pause',
      'pause please',
      'Stop exercise',
      'stop the exercise',
      'arrête',
      'توقف',
    ]);
    expectAll(VoiceCommandType.resume, [
      'continue',
      'Resume',
      'on reprend',
      'استمر',
    ]);
    expectAll(VoiceCommandType.repeat, [
      'Repeat',
      'say that again',
      'répète',
      'كرر',
    ]);
    expectAll(VoiceCommandType.explainSimpler, [
      "I don't understand",
      'I do not understand',
      'Explain again',
      'je ne comprends pas',
      "j'ai mal compris", // "mal" here is not pain
      'لم أفهم',
    ]);
    expectAll(VoiceCommandType.help, [
      'Help',
      'what can I say',
      'aide',
      'مساعدة',
    ]);
  });

  test('no command from unrelated or negated speech', () {
    expectAll(VoiceCommandType.unknown, [
      'the weather is nice today',
      "don't stop", // negated command is not obeyed
      'I was talking to my brother about how we should stop by the shop later today', // long sentence
      '',
    ]);
  });

  test('normalisation: punctuation, case, accents, Arabic letter variants', () {
    expect(normalizeUtterance('  ÇA   fait   MAL !!! '), 'ca fait mal');
    expect(normalizeUtterance("I’m  in PAIN."), "i'm in pain");
    expect(
      normalizeUtterance('أَشْعُرُ بِأَلَمٍ'),
      normalizeUtterance('اشعر بالم'),
    );
  });
}
