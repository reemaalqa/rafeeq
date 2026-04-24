import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/islamic_cubit.dart';
import '../cubit/islamic_state.dart';
import '../widgets/surah_tile.dart';

class QuranPage extends StatelessWidget {
  const QuranPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.instance<IslamicCubit>()..loadSurahs(),
      child: const _QuranView(),
    );
  }
}

class _QuranView extends StatelessWidget {
  const _QuranView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 32), onPressed: () => Navigator.pop(context)),
        title: Text(l10n.quran),
        backgroundColor: AppTheme.islamicColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(top: false, child: BlocBuilder<IslamicCubit, IslamicState>(
        builder: (context, state) {
          if (state.status == IslamicStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == IslamicStatus.error) {
            return Center(child: Text(state.errorMessage ?? l10n.errorLoadingQuran));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            itemCount: state.surahs.length,
            itemBuilder: (context, index) {
              final surah = state.surahs[index];
              return SurahTile(
                surah: surah,
                onTap: () {
                  context.read<IslamicCubit>().selectSurah(surah);
                  Navigator.pushNamed(context, '/surah-detail', arguments: surah.id);
                },
              );
            },
          );
        },
      )), // SafeArea + BlocBuilder
    );
  }
}
