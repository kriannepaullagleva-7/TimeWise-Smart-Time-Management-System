import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_exceptions.dart';
import 'app_logger.dart';

/// Turns any error into a short sentence a student can act on. Technical
/// details go to [AppLogger], never to the screen.
String friendlyError(Object error) {
  if (error is AppException) return error.message;
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return "You don't have permission to do that. Try signing out and in again.";
      case 'unavailable':
      case 'network-request-failed':
        return 'No connection to the server. Changes will sync when you are back online.';
      case 'deadline-exceeded':
        return 'The server took too long to answer. Please try again.';
      case 'not-found':
        return 'That item no longer exists.';
      case 'failed-precondition':
        return 'The database is still being prepared. Try again in a moment.';
      default:
        return 'Could not complete that action. Please try again.';
    }
  }
  if (error is SocketException || error is TimeoutException || error is http.ClientException) {
    return 'No internet connection. Check your network and try again.';
  }
  return 'Something went wrong. Please try again.';
}

/// Shows a floating message at the bottom of the screen.
void showMessage(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Runs [action]; on failure logs the error and shows a friendly message.
/// Returns true when the action completed.
Future<bool> guarded(
  BuildContext context,
  Future<void> Function() action, {
  String? successMessage,
}) async {
  try {
    await action();
    if (successMessage != null && context.mounted) showMessage(context, successMessage);
    return true;
  } catch (e, st) {
    AppLogger.error('UI', 'action failed', e, st);
    if (context.mounted) showMessage(context, friendlyError(e), error: true);
    return false;
  }
}
