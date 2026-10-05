/// Errors whose message is already written for the user.
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// The AI schedule assistant cannot run because no API key was supplied.
class AIConfigException extends AppException {
  const AIConfigException(super.message);
}

/// The AI request failed (network, quota, model unavailable, unusable reply).
class AIServiceException extends AppException {
  final int? statusCode;
  const AIServiceException(super.message, {this.statusCode});
}

/// A new or edited schedule item overlaps an existing one.
class ScheduleConflictException extends AppException {
  const ScheduleConflictException(super.message);
}
