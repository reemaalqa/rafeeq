import 'package:equatable/equatable.dart';
import 'ayah.dart';

class Surah extends Equatable {
  final String id;
  final int number;
  final String arabicName;
  final String englishName;
  final String transliteration;
  final int verseCount;
  final List<Ayah> ayahs;

  const Surah({
    required this.id,
    required this.number,
    required this.arabicName,
    required this.englishName,
    required this.transliteration,
    required this.verseCount,
    required this.ayahs,
  });

  @override
  List<Object?> get props => [id, number, arabicName, englishName, transliteration, verseCount, ayahs];
}
