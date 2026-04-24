/// Build-time environment configuration.
///
/// Values are injected via `--dart-define=KEY=VALUE` at build time and are
/// never embedded in source code.  This keeps secrets out of the repository
/// and enables per-environment builds without touching a single Dart file.
///
/// Example:
/// ```sh
/// flutter run --dart-define=MAPS_API_KEY=your_key_here
/// flutter build apk --dart-define=MAPS_API_KEY=your_key_here
/// ```
abstract class EnvConfig {
  EnvConfig._();

  /// Google Maps Android / iOS API key.
  ///
  /// Configured at build time via `--dart-define=MAPS_API_KEY=...`.
  /// The key itself must also be added to AndroidManifest.xml and
  /// AppDelegate.swift/Info.plist for the native Maps SDK to function.
  /// This Dart constant is kept for reference and any runtime SDK
  /// initialisation that may require it.
  static const String mapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: '',
  );
}
