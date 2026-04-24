import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/config/theme_config.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/place.dart';
import '../cubit/locations_cubit.dart';
import '../cubit/locations_state.dart';

/// Horizontal scrollable bar of [FilterChip]s — one per [PlaceCategory].
///
/// Tapping a chip calls [LocationsCubit.loadCategory] with the corresponding
/// category.  The currently selected chip is visually highlighted.
class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationsCubit, LocationsState>(
      buildWhen: (prev, curr) =>
          prev.selectedCategory != curr.selectedCategory ||
          prev.status != curr.status,
      builder: (context, state) {
        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceSM,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PlaceCategory.values.map((category) {
                final isSelected = state.selectedCategory == category;
                final isLoading =
                    isSelected && state.status == LocationsStatus.loading;

                return Padding(
                  padding: const EdgeInsets.only(right: AppTheme.spaceSM),
                  child: FilterChip(
                    selected: isSelected,
                    onSelected: isLoading
                        ? null
                        : (_) => context
                            .read<LocationsCubit>()
                            .loadCategory(category),
                    avatar: Icon(
                      _iconFor(category),
                      size: 18,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.primaryColor,
                    ),
                    label: Text(
                      _labelFor(context, category),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                    ),
                    selectedColor: AppTheme.primaryColor,
                    backgroundColor:
                        Theme.of(context).colorScheme.surface,
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.dividerColor,
                      width: 1.5,
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSM,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  IconData _iconFor(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.mosque:
        return Icons.mosque;
      case PlaceCategory.hospital:
        return Icons.local_hospital;
      case PlaceCategory.clinic:
        return Icons.medical_services;
      case PlaceCategory.pharmacy:
        return Icons.local_pharmacy;
      case PlaceCategory.park:
        return Icons.park;
      case PlaceCategory.restaurant:
        return Icons.restaurant;
    }
  }

  String _labelFor(BuildContext context, PlaceCategory category) {
    final l10n = AppLocalizations.of(context)!;
    switch (category) {
      case PlaceCategory.mosque:
        return l10n.mosque;
      case PlaceCategory.hospital:
        return l10n.hospital;
      case PlaceCategory.clinic:
        return l10n.clinic;
      case PlaceCategory.pharmacy:
        return l10n.pharmacy;
      case PlaceCategory.park:
        return l10n.park;
      case PlaceCategory.restaurant:
        return l10n.restaurant;
    }
  }
}
