/// Grams → spoons conversion for displaying food quantities to elderly users.
///
/// Mirrors backend/app/utils/unit_converter.py. Used when the app receives
/// food data with gram quantities and wants to show a friendlier unit
/// alongside them (e.g. "50 جرام ≈ 3 ملاعق"). Keep grams visible — some
/// users need accuracy for diabetes / medical reasons.
library;

/// Grams per tablespoon, indexed by FoodItem.category string.
const Map<String, double> _tbspGrams = {
  'sugar': 12.0,
  'flour': 8.0,
  'oil': 14.0,
  'butter': 14.0,
  'honey': 21.0,
  'rice': 15.0,
  'salt': 18.0,
  'yogurt': 15.0,
  'sauce': 15.0,
};

const double _defaultTbspGrams = 15.0;
const double _tspPerTbsp = 3.0;

class SpoonReading {
  final double count;
  final String unitAr; // "ملعقة كبيرة" | "ملعقة صغيرة"
  const SpoonReading(this.count, this.unitAr);

  /// Renders as e.g. "3 ملعقة كبيرة" or "½ ملعقة صغيرة".
  String get display {
    final n = count == count.roundToDouble()
        ? count.toInt().toString()
        : count.toStringAsFixed(1);
    return '$n $unitAr';
  }
}

/// Returns a spoon reading for [grams] of the given [category].
/// Null if grams is null or non-positive.
SpoonReading? gramsToSpoons(double? grams, {String? category}) {
  if (grams == null || grams <= 0) return null;
  final perTbsp = _tbspGrams[(category ?? '').toLowerCase()] ?? _defaultTbspGrams;
  final tbsp = grams / perTbsp;
  if (tbsp >= 1.0) {
    final rounded = (tbsp * 2).round() / 2;
    return SpoonReading(rounded, 'ملعقة كبيرة');
  }
  final tsp = tbsp * _tspPerTbsp;
  final rounded = (tsp * 2).round() / 2;
  return SpoonReading(rounded < 0.5 ? 0.5 : rounded, 'ملعقة صغيرة');
}

/// Convenience: "50 جرام (≈ 3 ملعقة كبيرة)" — what diet screens should show.
String formatGramsWithSpoons(double? grams, {String? category}) {
  if (grams == null || grams <= 0) return '';
  final gramsText = grams == grams.roundToDouble()
      ? '${grams.toInt()} جرام'
      : '${grams.toStringAsFixed(1)} جرام';
  final spoons = gramsToSpoons(grams, category: category);
  if (spoons == null) return gramsText;
  return '$gramsText (≈ ${spoons.display})';
}
