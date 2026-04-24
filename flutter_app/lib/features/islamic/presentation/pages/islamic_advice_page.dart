import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/datasources/islamic_local_datasource.dart';
import '../../domain/entities/islamic_advice.dart';
import '../cubit/islamic_cubit.dart';
import '../cubit/islamic_state.dart';
import '../widgets/advice_card.dart';

class IslamicAdvicePage extends StatefulWidget {
  const IslamicAdvicePage({super.key});

  @override
  State<IslamicAdvicePage> createState() => _IslamicAdvicePageState();
}

class _IslamicAdvicePageState extends State<IslamicAdvicePage> {
  late PageController _pageController;
  // Load advice directly from datasource for this page
  final List<IslamicAdvice> _adviceList = IslamicLocalDatasourceImpl().getAdviceList();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Start at today's daily advice
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    _currentIndex = dayOfYear % _adviceList.length;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.instance<IslamicCubit>(),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: IconButton(icon: const Icon(Icons.arrow_back, size: 32), onPressed: () => Navigator.pop(context)),
            title: Text(AppLocalizations.of(context)!.islamicAdvice),
            backgroundColor: AppTheme.islamicColor,
            foregroundColor: Colors.white,
          ),
          body: Column(
            children: [
              // Page indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_adviceList.length, (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentIndex == i ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == i ? AppTheme.islamicColor : AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _adviceList.length,
                  onPageChanged: (index) => setState(() => _currentIndex = index),
                  itemBuilder: (context, index) {
                    final advice = _adviceList[index];
                    return SingleChildScrollView(
                      child: AdviceCard(
                        advice: advice,
                        onListen: () => context.read<IslamicCubit>().speakAdvice(advice.arabicText),
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                child: Text(
                  AppLocalizations.of(context)!.swipeForMore,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
