import 'package:flutter/foundation.dart';

/// Severity levels for log entries.
enum LogLevel { debug, info, warning, error }

/// Lightweight centralised logger for TimeWise.
///
/// Usage:
///   AppLogger.info('TaskProvider', 'Task added: $id');
///   AppLogger.error('FirestoreService', 'Write failed', error, stackTrace);
///
/// In release builds only [error] and [warning] are printed to avoid leaking
/// sensitive information. In debug builds all levels are printed.
abstract final class AppLogger {
  static const _tag = 'TimeWise';

  static void debug(String module, String message) {
    if (kDebugMode) _log(LogLevel.debug, module, message);
  }

  static void info(String module, String message) {
    if (kDebugMode) _log(LogLevel.info, module, message);
  }

  static void warning(String module, String message, [Object? error]) {
    _log(LogLevel.warning, module, message, error);
  }

  static void error(
    String module,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.error, module, message, error, stackTrace);
  }

  static void _log(
    LogLevel level,
    String module,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final prefix = switch (level) {
      LogLevel.debug   => '🔍 DEBUG',
      LogLevel.info    => 'ℹ️  INFO ',
      LogLevel.warning => '⚠️  WARN ',
      LogLevel.error   => '🔴 ERROR',
    };
    final buf = StringBuffer()
      ..write('[$_tag][$prefix][$module] $message');
    if (error != null) buf.write(' | $error');
    debugPrint(buf.toString());
    if (stackTrace != null && kDebugMode) debugPrint(stackTrace.toString());
  }
}
