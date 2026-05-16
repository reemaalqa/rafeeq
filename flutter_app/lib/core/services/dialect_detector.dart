import 'dart:developer' as developer;

/// Detects which Saudi Arabic sub-dialect a user is speaking from free-form
/// transcribed speech, using weighted suffix and lexical pattern matching.
///
/// Detection signal:
/// At least [_kMinSignal] weighted hits are required before the detector
/// commits to any label — below that threshold it returns null so the
/// caller keeps whatever dialect the user set manually.
class DialectDetector {
  const DialectDetector();

  /// Minimum weighted score required to return a result.
  static const double _kMinSignal = 1.5;

  /// Minimum posterior probability for the winning class.
  static const double _kMinConfidence = 0.45;

  // ── Najdi: Central (Riyadh / Qassim) ─────────────────────────────────────
  // confirmation "ايه", greeting "ابشر".
  static final _rNajdiEnclitic =
      RegExp(r'(?<=[كهم])س(?=\s|$|[،.؟!])');
  static final _rNajdiLex =
      RegExp(r'\b(ابشر|ابشري|ايه(?!\s*والله)|شعليتس|عساكم?|وش|ها\b)\b');

  double _scoreNajdi(String t) {
    double s = 0;
    s += _rNajdiEnclitic.allMatches(t).length * 3.0;
    s += _rNajdiLex.allMatches(t).length * 1.5;
    return s;
  }

  // ── Janoubi: Southern (Abha / Jizan / Najran) ────────────────────────────
  // Characteristic: "ش" enclitics (وينش، كيفش، عليش),
  // and bare "ش" confirmation suffix.
  static final _rJanoubiEnclitic =
      RegExp(r'(?<=[كهم])ش(?=\s|$|[،.؟!])');
  static final _rJanoubiLex =
      RegExp(r'\b(وينش|كيفش|شخبارش|شبيش|ليش|عليش|ايش)\b');

  double _scoreJanoubi(String t) {
    double s = 0;
    s += _rJanoubiEnclitic.allMatches(t).length * 3.0;
    s += _rJanoubiLex.allMatches(t).length * 1.5;
    return s;
  }

  // ── Hijazi: Western region (Jeddah / Makkah / Madinah) ─────────────────
  // Characteristic: common Hijazi words such as "ايش", "دحين",
  // "أبغى/تبغى", "كمان", and "مرة".
  static final _rHijaziLex =
    RegExp(r'\b(ايش|دحين|اشبك|ابغى|ابغا|تبغى|تبغا|كمان|مره|مرة)\b');
  
  double _scoreHijazi(String t) {
    double s = 0;
    s += _rHijaziLex.allMatches(t).length * 1.5;
    return s;
  }
  
  // ── Sharqawi: Eastern (Dammam / Ahsa / Qatif) ───────────────────────────
  // Characteristic: common Eastern Saudi expressions such as "شلونك",
  // "وش أخبارك", "اي والله", "عاد", and "هلا والله".
  static final _rSharqawiLex =
    RegExp(r'\b(عاد\b|اي\s+والله|إي\s+والله|وش\s+اخبارك|وش\s+أخبارك|شلونك|هلا\s+والله)\b');
  
  double _scoreSharqawi(String t) {
    double s = 0;
    s += _rSharqawiLex.allMatches(t).length * 1.5;
    return s;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Analyses [text] (may be a single utterance or accumulated conversation
  /// text) and returns the best-matching dialect, or null if the signal is
  /// too weak to make a confident call.
  DialectResult? detect(String text) {
    if (text.trim().isEmpty) return null;

    final n = _normalize(text);

    final scores = <String, double>{
      'najdi':    _scoreNajdi(n),
      'janoubi':  _scoreJanoubi(n),
      'hijazi':  _scoreHizaji(n),
      'sharqawi': _scoreSharqawi(n),
    };

    final best =
        scores.entries.reduce((a, b) => a.value > b.value ? a : b);

    if (best.value < _kMinSignal) {
      developer.log(
        'dialect: no strong signal (best=${best.key} score=${best.value.toStringAsFixed(1)})',
        name: 'DialectDetector',
      );
      return null;
    }

    final total = scores.values.fold(0.0, (a, b) => a + b);
    final confidence = total > 0 ? best.value / total : 0.5;

    if (confidence < _kMinConfidence) {
      developer.log(
        'dialect: low confidence ${(confidence * 100).toStringAsFixed(0)}% for ${best.key} — skipping',
        name: 'DialectDetector',
      );
      return null;
    }

    developer.log(
      'dialect detected: ${best.key} '
      '(confidence=${(confidence * 100).toStringAsFixed(0)}%, '
      'scores=$scores)',
      name: 'DialectDetector',
    );
    return DialectResult(dialect: best.key, confidence: confidence);
  }

  // ── Normalisation ──────────────────────────────────────────────────────────

  static String _normalize(String text) {
    var s = text.trim().toLowerCase();
    // Strip diacritics / tatweel
    s = s.replaceAll(RegExp(r'[ًٌٍَُِّْٓٔ]'), '').replaceAll('ـ', '');
    // Unify alef family
    s = s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
    // Collapse whitespace
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

// ── Result type ──────────────────────────────────────────────────────────────

class DialectResult {
  /// One of: `'najdi'` | `'janoubi'` | `'hijazi'` | `'sharqawi'`.
  final String dialect;

  /// Posterior probability of the winning class (0.0 – 1.0).
  final double confidence;

  const DialectResult({required this.dialect, required this.confidence});

  @override
  String toString() =>
      'DialectResult(dialect=$dialect, confidence=${(confidence * 100).toStringAsFixed(0)}%)';
}
