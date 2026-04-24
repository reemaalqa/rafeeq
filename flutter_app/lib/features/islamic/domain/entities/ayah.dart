import 'package:equatable/equatable.dart';

class Ayah extends Equatable {
  final int number;
  final String arabicText;
  final String transliteration;
  final String translation;

  const Ayah({
    required this.number,
    required this.arabicText,
    required this.transliteration,
    required this.translation,
  });

  @override
  List<Object?> get props => [number, arabicText, transliteration, translation];
}
