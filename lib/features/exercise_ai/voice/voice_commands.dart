/// Spoken command -> what the patient asked for. Pure, deterministic and conservative: an utterance only becomes a
/// command when it clearly is one; anything about pain that is not a clear report is "painAmbiguous" (the assistant
/// then pauses and asks), never ignored. English, French and Arabic (incl. common Algerian forms) are understood
/// whatever the app language, because patients mix languages.
library;

enum VoiceCommandType {
  /// "It hurts", "J'ai mal", "أشعر بألم": pain hold.
  painReport,

  /// Mentions pain but is not a clear present report (question, negation, the past, the word alone): pause + ask.
  painAmbiguous,

  /// "I'm uncomfortable": pause + ask whether it hurts.
  uncomfortable,
  pause,
  resume,
  repeat,
  explainSimpler,
  help,
  unknown,
}

class VoiceCommand {
  final VoiceCommandType type;
  final String normalized;
  const VoiceCommand(this.type, this.normalized);

  @override
  String toString() => '$type("$normalized")';
}

const _latin = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'á': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'í': 'i',
  'ô': 'o',
  'ö': 'o',
  'ó': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ú': 'u',
  'ç': 'c',
  'œ': 'oe',
  'æ': 'ae',
  'ÿ': 'y',
};

/// Lower case, no accents, Arabic letter variants unified, punctuation removed, single spaces.
String normalizeUtterance(String text) {
  var t = text.toLowerCase().replaceAll(RegExp('[’`´‘]'), "'");
  t = t.split('').map((c) => _latin[c] ?? c).join();
  // Arabic: harakat and tatweel out; alef / ya / ta marbuta / hamza carriers unified
  t = t.replaceAll(RegExp('[ً-ْـ]'), '');
  t = t
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
  t = t.replaceAll(RegExp(r"[^\p{L}\p{N}' ]", unicode: true), ' ');
  t = t.replaceAll(RegExp(r"\s*'\s*"), "'");
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

RegExp _w(String pattern) => RegExp('(^| )(?:$pattern)(\$| )', unicode: true);

bool _any(List<RegExp> res, String t) => res.any((r) => r.hasMatch(t));

// ---------------------------------------------------------------------------------------------------- pain
/// Words that mean the utterance is about pain at all.
final _painWords = [
  _w(r"pain|painful|hurts?|hurting|hurt|ouch|ow|aches?|aching|sore"),
  // "mal" alone, not "mal compris" (misunderstood) nor "mal à l'aise" (uncomfortable, handled separately)
  _w(
    r"mal(?! (?:compris|entendu|lu|vu|a l'aise))|douleurs?|douloureu(?:x|se)|aie",
  ),
  _w(r"الم|الالم|وجع|الوجع|يوجع\S*|توجع\S*|يولم\S*|تولم\S*|اوجاع"),
];

/// Clear first-person, present reports.
final _painClear = [
  // English
  _w(
    r"(?:it|this|that|my \S+(?: \S+)?) (?:really |still |so |kind of )?(?:hurts|is hurting|is painful|aches|is sore)",
  ),
  _w(
    r"i(?:'m| am| m|m) (?:in|having|feeling) (?:some |a lot of |so much |a little )?pain",
  ),
  _w(
    r"i (?:feel|have|got|am feeling|'m feeling) (?:some |a lot of |so much |a little |a )?pain",
  ),
  _w(r"i(?:'m| am| m|m) hurting"),
  _w(r"(?:ouch|ow)"),
  _w(r"(?:it|that|this) hurts"),
  // French (j'ai mal / ça fait mal / je sens une douleur) - "j'ai mal compris" is not pain
  _w(
    r"j ?'?ai (?:tres |un peu |trop |vraiment |encore )?mal(?! (?:compris|entendu|lu|fait|vu))",
  ),
  _w(r"(?:ca|cela) (?:me )?fait (?:tres |trop |vraiment |un peu )?mal"),
  _w(
    r"je (?:ressens|sens) (?:une |de la |un peu de |beaucoup de |des )?douleurs?",
  ),
  _w(r"j ?'?ai (?:une |de la |des )douleurs?"),
  _w(r"aie"),
  // Arabic (MSA + Algerian)
  _w(r"اشعر ب(?:ال)?الم"),
  _w(r"عندي (?:ال)?(?:الم|وجع)"),
  _w(r"(?:يولمني|تولمني|يوجعني|توجعني|راهو يوجعني|راها توجعني)"),
  _w(r"(?:راني )?نحس ب(?:ال)?(?:وجع|الم)"),
  _w(r"فيا (?:ال)?وجع"),
];

final _questionStart = _w(
  r"does|do|did|is|are|was|will|would|should|can|could|why|what|how|when|whether|"
  r"est ce|est-ce|pourquoi|comment|quand|est il|"
  r"هل|لماذا|كيف|متي|واش|علاش|كيفاش",
);

final _negation = [
  _w(
    r"no|not|don't|dont|doesn't|doesnt|didn't|didnt|isn't|isnt|never|without|no longer|any more|anymore",
  ),
  _w(r"pas|plus|jamais|aucune?|sans"),
  _w(r"لا|ليس|ما|مش|ماشي|بلا|ماكانش|مكانش|ماعنديش|ما عنديش|مانحسش|ما نحسش"),
];

final _otherTime = _w(
  r"yesterday|last time|before|earlier|tomorrow|later|hier|avant|la derniere fois|demain|tout a l'heure|"
  r"البارح|امس|البارحه|قبل|غدوه|غدا",
);

// ---------------------------------------------------------------------------------------------------- others
final _uncomfortable = [
  _w(
    r"uncomfortable|not comfortable|discomfort|doesn't feel right|feels? weird|feels? strange",
  ),
  _w(
    r"mal a l'aise|pas a l'aise|inconfortable|gene|genee|ca me gene|je suis gene",
  ),
  _w(r"غير مرتاح|مش مرتاح|ماشي مرتاح|مو مرتاح|ما راحتش|مضايق"),
];

/// Short command phrases. Matched only in short utterances (see [_short]) and never when negated.
final _pause = [
  _w(
    r"pause|stop|stop exercise|stop the exercise|pause the exercise|wait|hold on",
  ),
  _w(r"pause|stop|arrete|arreter|arretez|arrete l'exercice|attends|attendez"),
  _w(r"توقف|وقف|ايقاف|استراحه|اوقف|حبس|بركا"),
];
final _resume = [
  _w(r"continue|resume|keep going|go on|start again"),
  _w(r"continuer|continue|reprendre|reprends|reprenez|on continue|on reprend"),
  _w(r"استمر|واصل|كمل|نكمل|استئناف|استيناف|زيد"),
];
final _repeat = [
  _w(r"repeat|repeat that|repeat please|say again|say that again|again"),
  _w(
    r"repete|repeter|repetez|redis|redites|encore une fois|tu peux repeter|vous pouvez repeter",
  ),
  _w(r"اعد|اعيد|كرر|عاود|عاودها|مره اخري|مره اخرى"),
];
final _simpler = [
  _w(
    r"i don't understand|i dont understand|i do not understand|i didn't understand|i didnt understand|"
    r"didn't get it|didnt get it|explain again|explain|what do you mean|what does that mean",
  ),
  _w(
    r"je ne comprends pas|je comprends pas|j'ai pas compris|jai pas compris|je n'ai pas compris|"
    r"j'ai mal compris|explique|expliquez|explique encore|reexplique|c'est a dire",
  ),
  _w(r"لم افهم|ما فهمت|ما فهمتش|مافهمتش|ما فهمتكش|اشرح|اشرحلي|وضح"),
];
final _help = [
  _w(r"help|what can i say|commands"),
  _w(r"aide|aidez moi|aide moi|que puis je dire|qu'est ce que je peux dire"),
  _w(r"مساعده|ساعدني|عاوني"),
];

const _maxCommandWords = 7;

bool _short(String t) => t.split(' ').length <= _maxCommandWords;

class VoiceCommandParser {
  const VoiceCommandParser();

  VoiceCommand parse(String text) {
    final raw = text.trim();
    final t = normalizeUtterance(raw);
    if (t.isEmpty) return VoiceCommand(VoiceCommandType.unknown, t);

    // 1. pain first: never ignored. A clear present first-person report -> pain hold; anything else about pain
    //    (a question, a negation, another time, the word alone) -> pause and ask.
    final mentionsPain = _any(_painWords, t) || _any(_painClear, t);
    if (mentionsPain) {
      final clear = _any(_painClear, t);
      final question =
          raw.contains('?') ||
          raw.contains('؟') ||
          _questionStart.hasMatch(t.split(' ').first);
      final negated = _any(_negation, t);
      final otherTime = _otherTime.hasMatch(t);
      if (clear && !question && !negated && !otherTime) {
        return VoiceCommand(VoiceCommandType.painReport, t);
      }
      // "mal à l'aise" (uncomfortable) contains "mal": handled as discomfort, which also pauses and asks
      if (_any(_uncomfortable, t)) {
        return VoiceCommand(VoiceCommandType.uncomfortable, t);
      }
      return VoiceCommand(VoiceCommandType.painAmbiguous, t);
    }
    // 2. discomfort: pause and ask (not assumed safe)
    if (_any(_uncomfortable, t)) {
      return VoiceCommand(VoiceCommandType.uncomfortable, t);
    }

    // 3. short commands, only in short utterances; a negated one ("don't stop") is not obeyed
    if (!_short(t)) return VoiceCommand(VoiceCommandType.unknown, t);
    // "I don't understand" contains a negation by nature: check it before the negation rule
    if (_any(_simpler, t)) {
      return VoiceCommand(VoiceCommandType.explainSimpler, t);
    }
    final negated = _any(_negation, t);
    if (negated) return VoiceCommand(VoiceCommandType.unknown, t);
    if (_any(_pause, t)) return VoiceCommand(VoiceCommandType.pause, t);
    if (_any(_resume, t)) return VoiceCommand(VoiceCommandType.resume, t);
    if (_any(_repeat, t)) return VoiceCommand(VoiceCommandType.repeat, t);
    if (_any(_help, t)) return VoiceCommand(VoiceCommandType.help, t);
    return VoiceCommand(VoiceCommandType.unknown, t);
  }
}
