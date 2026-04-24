import 'dart:convert';
import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter/services.dart' show rootBundle;
import '../../domain/entities/surah.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/islamic_advice.dart';
import '../../domain/entities/prayer_times.dart';

abstract class IslamicLocalDatasource {
  Future<List<Surah>> getSurahs();
  List<IslamicAdvice> getAdviceList();
  PrayerTimes calculatePrayerTimes({required double lat, required double lng, required DateTime date, String location = ''});
}

class IslamicLocalDatasourceImpl implements IslamicLocalDatasource {
  List<Surah>? _cachedSurahs;

  @override
  Future<List<Surah>> getSurahs() async {
    if (_cachedSurahs != null) return _cachedSurahs!;

    final jsonStr = await rootBundle.loadString('assets/data/quran.json');
    final List<dynamic> jsonList = json.decode(jsonStr);

    _cachedSurahs = jsonList.map((surahJson) {
      final id = surahJson['id'] as int;
      final verses = (surahJson['verses'] as List<dynamic>)
          .map((v) => Ayah(
                number: v['id'] as int,
                arabicText: v['text'] as String,
                transliteration: '',
                translation: '',
              ))
          .toList();

      return Surah(
        id: id.toString(),
        number: id,
        arabicName: surahJson['name'] as String,
        englishName: surahJson['transliteration'] as String,
        transliteration: surahJson['transliteration'] as String,
        verseCount: surahJson['total_verses'] as int,
        ayahs: verses,
      );
    }).toList();

    return _cachedSurahs!;
  }

  @override
  List<IslamicAdvice> getAdviceList() => _kAdviceList;

  /// Accurate prayer times via the adhan library (Jean Meeus solar algorithm,
  /// Umm al-Qura method: Fajr 18.5°, Isha 90 min after Maghrib).
  @override
  PrayerTimes calculatePrayerTimes({
    required double lat,
    required double lng,
    required DateTime date,
    String location = '',
  }) {
    final coordinates = adhan.Coordinates(lat, lng);
    final params = adhan.CalculationMethod.umm_al_qura.getParameters();
    final dateComponents = adhan.DateComponents.from(date);
    final times = adhan.PrayerTimes(coordinates, dateComponents, params);

    return PrayerTimes(
      fajr:    times.fajr.toLocal(),
      dhuhr:   times.dhuhr.toLocal(),
      asr:     times.asr.toLocal(),
      maghrib: times.maghrib.toLocal(),
      isha:    times.isha.toLocal(),
      date:    date,
      location: location,
    );
  }
}

// ─── Static Islamic Advice Data ───────────────────────────────────────────────
// Expanded Adhkar, Hadiths, Dua and Quran excerpts so the daily-advice feature
// rotates through enough variety that an elderly user hears something fresh
// each day for a few weeks.

const List<IslamicAdvice> _kAdviceList = [
  // ── Dhikr (أذكار) ───────────────────────────────────────────────────────────
  IslamicAdvice(
    id: '1',
    category: AdviceCategory.dhikr,
    arabicText: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
    transliteration: 'Subhana llahi wa-bi-hamdih, Subhana llahi l-ʿazim',
    englishText: 'Glory be to Allah and praise be to Him, Glory be to Allah the Almighty',
    source: 'صحيح البخاري',
  ),
  IslamicAdvice(
    id: '2',
    category: AdviceCategory.dhikr,
    arabicText: 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
    transliteration: 'La ilaha illa llahu wahdahu la sharika lah',
    englishText: 'There is no god but Allah alone, without partner.',
    source: 'صحيح البخاري',
  ),
  IslamicAdvice(
    id: '3',
    category: AdviceCategory.dhikr,
    arabicText: 'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيَّ الْقَيُّومَ وَأَتُوبُ إِلَيْهِ',
    transliteration: 'Astaghfiru llah al-ʿazim',
    englishText: 'I seek forgiveness from Allah the Almighty, and I turn to Him in repentance.',
    source: 'سنن أبي داود',
  ),
  IslamicAdvice(
    id: '4',
    category: AdviceCategory.dhikr,
    arabicText: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، إِنَّكَ حَمِيدٌ مَجِيدٌ',
    transliteration: 'Allahumma salli ʿala Muhammad',
    englishText: 'O Allah, send blessings upon Muhammad and the family of Muhammad.',
    source: 'صحيح البخاري',
  ),
  IslamicAdvice(
    id: '5',
    category: AdviceCategory.dhikr,
    arabicText: 'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
    transliteration: 'Hasbiya llahu la ilaha illa huwa',
    englishText: 'Allah is sufficient for me; there is no god but Him.',
    source: 'سنن أبي داود',
  ),
  IslamicAdvice(
    id: '6',
    category: AdviceCategory.dhikr,
    arabicText: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
    transliteration: 'La hawla wa-la quwwata illa billah',
    englishText: 'There is no power and no strength except with Allah.',
    source: 'صحيح البخاري',
  ),
  IslamicAdvice(
    id: '7',
    category: AdviceCategory.dhikr,
    arabicText: 'سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَلَا إِلَهَ إِلَّا اللَّهُ وَاللَّهُ أَكْبَرُ',
    transliteration: 'Subhana llah, wa-l-hamdu lillah, wa-la ilaha illa llah, wa-llahu akbar',
    englishText: 'Glory to Allah, praise to Allah, no god but Allah, Allah is greatest.',
    source: 'صحيح مسلم',
  ),
  IslamicAdvice(
    id: '8',
    category: AdviceCategory.dhikr,
    arabicText: 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
    transliteration: 'Bismi llahi lladhi la yadurru maʿa smihi shay\'',
    englishText: 'In the name of Allah, with whose name nothing can cause harm.',
    source: 'سنن الترمذي',
  ),

  // ── Adhkar of morning & evening (أذكار الصباح والمساء) ────────────────────
  IslamicAdvice(
    id: '9',
    category: AdviceCategory.dhikr,
    arabicText: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ',
    transliteration: 'Asbahna wa-asbaha l-mulku lillah',
    englishText: 'We have entered the morning and the dominion belongs to Allah.',
    source: 'صحيح مسلم — أذكار الصباح',
  ),
  IslamicAdvice(
    id: '10',
    category: AdviceCategory.dhikr,
    arabicText: 'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ',
    transliteration: 'Allahumma bika asbahna',
    englishText: 'O Allah, by You we enter the morning and the evening.',
    source: 'سنن الترمذي — أذكار الصباح',
  ),
  IslamicAdvice(
    id: '11',
    category: AdviceCategory.dhikr,
    arabicText: 'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا',
    transliteration: 'Radhitu billahi rabba',
    englishText: 'I am pleased with Allah as my Lord, Islam as my religion, and Muhammad as my Prophet.',
    source: 'سنن أبي داود',
  ),

  // ── Hadith (أحاديث نبوية) ──────────────────────────────────────────────────
  IslamicAdvice(
    id: '12',
    category: AdviceCategory.hadith,
    arabicText: 'الدِّينُ النَّصِيحَةُ',
    transliteration: 'Ad-dinu n-nasiha',
    englishText: 'The religion is sincere counsel.',
    source: 'صحيح مسلم',
  ),
  IslamicAdvice(
    id: '13',
    category: AdviceCategory.hadith,
    arabicText: 'خَيْرُ النَّاسِ أَنْفَعُهُمْ لِلنَّاسِ',
    transliteration: 'Khayru n-nasi anfaʿuhum li-n-nas',
    englishText: 'The best of people are those who bring the most benefit to others.',
    source: 'الدارقطني',
  ),
  IslamicAdvice(
    id: '14',
    category: AdviceCategory.hadith,
    arabicText: 'مَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الْآخِرِ فَلْيَقُلْ خَيْرًا أَوْ لِيَصْمُتْ',
    transliteration: 'Man kana yu\'minu billah',
    englishText: 'Whoever believes in Allah and the Last Day should speak good or remain silent.',
    source: 'متفق عليه',
  ),
  IslamicAdvice(
    id: '15',
    category: AdviceCategory.hadith,
    arabicText: 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى',
    transliteration: 'Innama l-aʿmalu bi-n-niyyat',
    englishText: 'Actions are but by intentions, and every person shall have only what he intended.',
    source: 'صحيح البخاري',
  ),
  IslamicAdvice(
    id: '16',
    category: AdviceCategory.hadith,
    arabicText: 'ابْتَسَامَتُكَ فِي وَجْهِ أَخِيكَ صَدَقَةٌ',
    transliteration: 'Ibtisamatuka fi wajhi akhik sadaqa',
    englishText: 'Your smile for your brother is a charity.',
    source: 'سنن الترمذي',
  ),
  IslamicAdvice(
    id: '17',
    category: AdviceCategory.hadith,
    arabicText: 'لَا يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ',
    transliteration: 'La yu\'minu ahadukum hatta yuhibba li-akhih',
    englishText: 'None of you truly believes until he loves for his brother what he loves for himself.',
    source: 'متفق عليه',
  ),
  IslamicAdvice(
    id: '18',
    category: AdviceCategory.hadith,
    arabicText: 'الْمُسْلِمُ مَنْ سَلِمَ الْمُسْلِمُونَ مِنْ لِسَانِهِ وَيَدِهِ',
    transliteration: 'Al-muslimu man salima l-muslimun min lisanih',
    englishText: 'A Muslim is one from whose tongue and hand the Muslims are safe.',
    source: 'صحيح البخاري',
  ),
  IslamicAdvice(
    id: '19',
    category: AdviceCategory.hadith,
    arabicText: 'الرَّاحِمُونَ يَرْحَمُهُمُ الرَّحْمَنُ، ارْحَمُوا مَنْ فِي الْأَرْضِ يَرْحَمْكُمْ مَنْ فِي السَّمَاءِ',
    transliteration: 'Ar-rahimuna yarhamuhumu r-rahman',
    englishText: 'The merciful are shown mercy by the Most Merciful. Have mercy on those on earth, and the One above the heavens will have mercy on you.',
    source: 'سنن الترمذي',
  ),

  // ── Dua (أدعية) ───────────────────────────────────────────────────────────
  IslamicAdvice(
    id: '20',
    category: AdviceCategory.dua,
    arabicText: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
    transliteration: 'Rabbana atina fi d-dunya hasana',
    englishText: 'Our Lord, grant us good in this world and in the Hereafter, and protect us from the punishment of the Fire.',
    source: 'القرآن 2:201',
  ),
  IslamicAdvice(
    id: '21',
    category: AdviceCategory.dua,
    arabicText: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ',
    transliteration: 'Allahumma inni as\'aluka l-ʿafwa wa-l-ʿafiyah',
    englishText: 'O Allah, I ask You for forgiveness and well-being in this world and the Hereafter.',
    source: 'سنن ابن ماجه',
  ),
  IslamicAdvice(
    id: '22',
    category: AdviceCategory.dua,
    arabicText: 'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ',
    transliteration: 'Allahumma aʿinni ʿala dhikrika wa-shukrik',
    englishText: 'O Allah, help me to remember You, thank You, and worship You in the best manner.',
    source: 'سنن أبي داود',
  ),
  IslamicAdvice(
    id: '23',
    category: AdviceCategory.dua,
    arabicText: 'اللَّهُمَّ اشْفِ، أَنْتَ الشَّافِي، لَا شِفَاءَ إِلَّا شِفَاؤُكَ، شِفَاءً لَا يُغَادِرُ سَقَمًا',
    transliteration: 'Allahumma shfi, anta sh-shafi',
    englishText: 'O Allah, cure. You are the Curer, there is no cure except Your cure.',
    source: 'صحيح البخاري',
  ),
  IslamicAdvice(
    id: '24',
    category: AdviceCategory.dua,
    arabicText: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَأَعُوذُ بِكَ مِنَ الْعَجْزِ وَالْكَسَلِ',
    transliteration: 'Allahumma inni aʿudhu bika mina l-hammi wa-l-hazan',
    englishText: 'O Allah, I seek refuge in You from worry and grief, from weakness and laziness.',
    source: 'صحيح البخاري',
  ),
  IslamicAdvice(
    id: '25',
    category: AdviceCategory.dua,
    arabicText: 'اللَّهُمَّ اغْفِرْ لِي، وَارْحَمْنِي، وَاهْدِنِي، وَعَافِنِي، وَارْزُقْنِي',
    transliteration: 'Allahumma ghfir li wa-rhamni',
    englishText: 'O Allah, forgive me, have mercy on me, guide me, pardon me, and grant me provision.',
    source: 'صحيح مسلم',
  ),
  IslamicAdvice(
    id: '26',
    category: AdviceCategory.dua,
    arabicText: 'رَبِّ اشْرَحْ لِي صَدْرِي، وَيَسِّرْ لِي أَمْرِي، وَاحْلُلْ عُقْدَةً مِنْ لِسَانِي، يَفْقَهُوا قَوْلِي',
    transliteration: 'Rabbi shrah li sadri',
    englishText: 'My Lord, expand for me my breast, ease my task, and untie the knot from my tongue so they may understand my speech.',
    source: 'القرآن 20:25-28',
  ),
  IslamicAdvice(
    id: '27',
    category: AdviceCategory.dua,
    arabicText: 'رَبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا',
    transliteration: 'Rabbi irhamhuma kama rabbayani saghira',
    englishText: 'My Lord, have mercy on them as they brought me up when I was small.',
    source: 'القرآن 17:24',
  ),

  // ── Quranic verses (آيات) ──────────────────────────────────────────────────
  IslamicAdvice(
    id: '28',
    category: AdviceCategory.quranVerse,
    arabicText: 'وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ',
    transliteration: 'Wa-man yatawakkal ʿala llahi fa-huwa hasbuh',
    englishText: 'And whoever relies upon Allah — then He is sufficient for him.',
    source: 'القرآن 65:3',
  ),
  IslamicAdvice(
    id: '29',
    category: AdviceCategory.quranVerse,
    arabicText: 'إِنَّ مَعَ الْعُسْرِ يُسْرًا',
    transliteration: 'Inna maʿa l-ʿusri yusra',
    englishText: 'Verily, with hardship comes ease.',
    source: 'القرآن 94:6',
  ),
  IslamicAdvice(
    id: '30',
    category: AdviceCategory.quranVerse,
    arabicText: 'وَاذْكُر رَّبَّكَ إِذَا نَسِيتَ',
    transliteration: 'Wa-dhkur rabbaka idha nasit',
    englishText: 'And remember your Lord when you forget.',
    source: 'القرآن 18:24',
  ),
  IslamicAdvice(
    id: '31',
    category: AdviceCategory.quranVerse,
    arabicText: 'فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ',
    transliteration: 'Fa-dhkuruni adhkurkum',
    englishText: 'So remember Me; I will remember you. And be grateful to Me and do not deny Me.',
    source: 'القرآن 2:152',
  ),
  IslamicAdvice(
    id: '32',
    category: AdviceCategory.quranVerse,
    arabicText: 'وَبَشِّرِ الصَّابِرِينَ الَّذِينَ إِذَا أَصَابَتْهُم مُّصِيبَةٌ قَالُوا إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ',
    transliteration: 'Wa-bashshiri s-sabirin',
    englishText: 'And give glad tidings to the patient — those who, when struck by calamity, say: "Indeed we belong to Allah and to Him we shall return."',
    source: 'القرآن 2:155-156',
  ),
  IslamicAdvice(
    id: '33',
    category: AdviceCategory.quranVerse,
    arabicText: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
    transliteration: 'Ala bi-dhikri llahi tatma\'innu l-qulub',
    englishText: 'Verily, in the remembrance of Allah do hearts find rest.',
    source: 'القرآن 13:28',
  ),
  IslamicAdvice(
    id: '34',
    category: AdviceCategory.quranVerse,
    arabicText: 'وَقُل رَّبِّ زِدْنِي عِلْمًا',
    transliteration: 'Wa-qul rabbi zidni ʿilma',
    englishText: 'And say: "My Lord, increase me in knowledge."',
    source: 'القرآن 20:114',
  ),
  IslamicAdvice(
    id: '35',
    category: AdviceCategory.quranVerse,
    arabicText: 'وَاللَّهُ خَيْرٌ حَافِظًا وَهُوَ أَرْحَمُ الرَّاحِمِينَ',
    transliteration: 'Wa-llahu khayrun hafiza',
    englishText: 'But Allah is the best Protector, and He is the Most Merciful of the merciful.',
    source: 'القرآن 12:64',
  ),
];
