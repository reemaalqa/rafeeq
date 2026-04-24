class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException({
    this.message = 'Server error occurred',
    this.statusCode,
  });

  @override
  String toString() => 'ServerException: $message (Status: $statusCode)';
}

class NetworkException implements Exception {
  final String message;

  const NetworkException({this.message = 'No internet connection'});

  @override
  String toString() => 'NetworkException: $message';
}

class CacheException implements Exception {
  final String message;

  const CacheException({this.message = 'Cache error occurred'});

  @override
  String toString() => 'CacheException: $message';
}

class ValidationException implements Exception {
  final String message;
  final Map<String, String>? errors;

  const ValidationException({
    this.message = 'Validation error',
    this.errors,
  });

  @override
  String toString() => 'ValidationException: $message';
}

class AuthenticationException implements Exception {
  final String message;

  const AuthenticationException({this.message = 'Authentication failed'});

  @override
  String toString() => 'AuthenticationException: $message';
}

class PermissionException implements Exception {
  final String message;

  const PermissionException({this.message = 'Permission denied'});

  @override
  String toString() => 'PermissionException: $message';
}

class LocationException implements Exception {
  final String message;

  const LocationException({this.message = 'Location error'});

  @override
  String toString() => 'LocationException: $message';
}

class VoiceException implements Exception {
  final String message;

  const VoiceException({this.message = 'Voice recognition error'});

  @override
  String toString() => 'VoiceException: $message';
}
