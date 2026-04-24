import 'package:url_launcher/url_launcher.dart';
import '../entities/place.dart';

/// Opens the device's default maps application with navigation to [place].
///
/// Launch order:
///  1. `geo:` URI  — opens any maps app (Google Maps, OsmAnd, HERE…)
///  2. Google Maps web URL — universal fallback if no maps app is installed
///  3. OpenStreetMap web URL — last resort
class LaunchDirections {
  const LaunchDirections();

  Future<void> call(Place place) async {
    final lat = place.latitude;
    final lng = place.longitude;
    final label = Uri.encodeComponent(place.name);

    // ── 1. geo: intent — opens native maps app ──────────────────────────────
    // Format: geo:lat,lng?q=lat,lng(label)
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');
    if (await _tryLaunch(geoUri)) return;

    // ── 2. Google Maps directions URL ────────────────────────────────────────
    final googleMapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await _tryLaunch(googleMapsUri)) return;

    // ── 3. OpenStreetMap web fallback ────────────────────────────────────────
    final osmUri = Uri.parse(
      'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng&zoom=16',
    );
    await _tryLaunch(osmUri);
  }

  /// Tries to launch [uri] and returns true if successful.
  Future<bool> _tryLaunch(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return launched;
    } catch (_) {
      return false;
    }
  }
}
