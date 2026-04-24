import 'package:equatable/equatable.dart';

enum AdviceCategory { dhikr, hadith, dua, quranVerse }

class IslamicAdvice extends Equatable {
  final String id;
  final AdviceCategory category;
  final String arabicText;
  final String transliteration;
  final String englishText;
  final String source;

  const IslamicAdvice({
    required this.id,
    required this.category,
    required this.arabicText,
    required this.transliteration,
    required this.englishText,
    required this.source,
  });

  @override
  List<Object?> get props => [id, category, arabicText, transliteration, englishText, source];
}
