import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get_it/get_it.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../../core/config/theme_config.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/place.dart';
import '../cubit/locations_cubit.dart';
import '../cubit/locations_state.dart';
import '../widgets/category_filter_bar.dart';
import '../widgets/place_list_sheet.dart';

/// The Locations feature page.
///
/// Provides:
///  - A category filter bar ([CategoryFilterBar]) for switching between
///    [PlaceCategory] types.
///  - A [FlutterMap] panel (250 dp high) powered by OpenStreetMap tiles —
///    completely free, no API key required.
///  - A scrollable [PlaceListSheet] listing the places with directions support.
///
/// All business logic lives in [LocationsCubit] — this widget is purely
/// presentational.
///
/// Pass [initialCategory] to open directly on a specific filter
/// (e.g. from voice: "مستوصف" → PlaceCategory.clinic).
class LocationsPage extends StatelessWidget {
  final PlaceCategory? initialCategory;

  const LocationsPage({super.key, this.initialCategory});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LocationsCubit>(
      create: (_) =>
          GetIt.instance<LocationsCubit>()..init(initialCategory: initialCategory),
      child: const _LocationsView(),
    );
  }
}

// ── Private view ──────────────────────────────────────────────────────────────

class _LocationsView extends StatefulWidget {
  const _LocationsView();

  @override
  State<_LocationsView> createState() => _LocationsViewState();
}

class _LocationsViewState extends State<_LocationsView> {
  final MapController _mapController = MapController();
  Place? _selectedPlace;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _moveToPosition(Position position) {
    _mapController.move(
      LatLng(position.latitude, position.longitude),
      13.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: AppLocalizations.of(context)!.back,
        ),
        title: Text(AppLocalizations.of(context)!.nearbyPlaces),
      ),
      body: SafeArea(top: false, child: BlocConsumer<LocationsCubit, LocationsState>(
        // Move the camera the first time the device position resolves.
        listenWhen: (prev, curr) =>
            prev.currentPosition == null && curr.currentPosition != null,
        listener: (_, state) {
          if (state.currentPosition != null) {
            // Defer until after the current frame so FlutterMap has mounted
            // and initialised its internal MapController before we call move().
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _moveToPosition(state.currentPosition!);
            });
          }
        },
        builder: (context, state) {
          // Global loading — before location is resolved.
          if (state.status == LocationsStatus.loading &&
              state.currentPosition == null &&
              state.places.isEmpty) {
            return const _LoadingBody();
          }

          // Location permission denied.
          if (state.status == LocationsStatus.noPermission) {
            return const _NoPermissionBody();
          }

          return Column(
            children: [
              // ── Category filter ───────────────────────────────────────────
              const CategoryFilterBar(),

              // ── OpenStreetMap panel ───────────────────────────────────────
              _MapPanel(
                mapController: _mapController,
                currentPosition: state.currentPosition,
                places: state.places,
                selectedPlace: _selectedPlace,
                onMarkerTap: (place) =>
                    setState(() => _selectedPlace = place),
              ),

              // ── Tapped-marker info card ───────────────────────────────────
              if (_selectedPlace != null)
                _SelectedPlaceCard(
                  place: _selectedPlace!,
                  onDismiss: () => setState(() => _selectedPlace = null),
                ),

              // ── Place list ────────────────────────────────────────────────
              Expanded(
                child: state.status == LocationsStatus.loading
                    ? const _LoadingBody()
                    : state.status == LocationsStatus.error
                        ? _ErrorBody(message: state.errorMessage)
                        : PlaceListSheet(places: state.places),
              ),
            ],
          );
        },
      )), // SafeArea + BlocConsumer
    );
  }
}

// ── Map panel ─────────────────────────────────────────────────────────────────

class _MapPanel extends StatelessWidget {
  final MapController mapController;
  final Position? currentPosition;
  final List<Place> places;
  final Place? selectedPlace;
  final void Function(Place) onMarkerTap;

  const _MapPanel({
    required this.mapController,
    required this.currentPosition,
    required this.places,
    required this.selectedPlace,
    required this.onMarkerTap,
  });

  // Default to Riyadh city centre when the user's position is unavailable.
  static const LatLng _defaultCenter = LatLng(24.7136, 46.6753);

  @override
  Widget build(BuildContext context) {
    final center = currentPosition != null
        ? LatLng(currentPosition!.latitude, currentPosition!.longitude)
        : _defaultCenter;

    return SizedBox(
      height: 250,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusMedium),
          bottomRight: Radius.circular(AppTheme.radiusMedium),
        ),
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.5,
          ),
          children: [
            // ── OpenStreetMap raster tiles (free, no API key) ──────────────
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.rafeeq.app',
            ),

            // ── Place markers ───────────────────────────────────────────────
            MarkerLayer(
              markers: places.map((place) {
                final isSelected = selectedPlace?.id == place.id;
                return Marker(
                  point: LatLng(place.latitude, place.longitude),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => onMarkerTap(place),
                    child: Icon(
                      Icons.location_pin,
                      size: 40,
                      color: isSelected
                          ? AppTheme.warningColor
                          : AppTheme.primaryColor,
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Current location blue dot ───────────────────────────────────
            if (currentPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.35),
                            blurRadius: 8,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

            // ── OSM attribution (required by OSM tile usage policy) ─────────
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Selected place info card ──────────────────────────────────────────────────

class _SelectedPlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback onDismiss;

  const _SelectedPlaceCard({required this.place, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceXS,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  place.address,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onDismiss,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}

// ── State bodies ──────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        strokeWidth: 3,
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String? message;

  const _ErrorBody({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppTheme.errorColor),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              message ?? AppLocalizations.of(context)!.somethingWentWrong,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceLG),
            ElevatedButton.icon(
              onPressed: () => context.read<LocationsCubit>().loadCategory(
                    context.read<LocationsCubit>().state.selectedCategory,
                  ),
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPermissionBody extends StatelessWidget {
  const _NoPermissionBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceXL,
          vertical: AppTheme.spaceLG,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 72, color: AppTheme.warningColor),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              AppLocalizations.of(context)!.locationPermissionRequired,
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              AppLocalizations.of(context)!.locationPermissionMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceXL),
            ElevatedButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings_outlined, size: 24),
              label: Text(AppLocalizations.of(context)!.openAppSettings),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                textStyle: const TextStyle(
                  fontSize: AppTheme.fontButton,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            TextButton(
              onPressed: () => context.read<LocationsCubit>().init(),
              child: Text(
                AppLocalizations.of(context)!.tryAgain,
                style: TextStyle(
                  fontSize: AppTheme.fontBody2,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
