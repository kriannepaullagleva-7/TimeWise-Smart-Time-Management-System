/// Form checks shared by Login, Sign-up and Create-account. They only catch
/// typing mistakes early; Firebase Auth remains the authority.
class Validators {
  Validators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  static bool isValidEmail(String value) => _email.hasMatch(value.trim());

  /// Error text for a name field, or null when valid.
  static String? name(String value) {
    if (value.trim().isEmpty) return 'Enter your name.';
    if (value.trim().length > 50) return 'Use 50 characters or fewer.';
    return null;
  }

  /// Error text for an email field, or null when valid.
  static String? email(String value) {
    if (value.trim().isEmpty) return 'Enter your email address.';
    if (!isValidEmail(value)) return 'Enter a valid email, like you@example.com.';
    return null;
  }

  /// Error text for a new password (Firebase requires at least 6 characters).
  static String? newPassword(String value) {
    if (value.isEmpty) return 'Enter a password.';
    if (value.length < 6) return 'Use at least 6 characters.';
    return null;
  }

  /// Existing passwords are only checked for presence.
  static String? existingPassword(String value) => value.isEmpty ? 'Enter your password.' : null;
}
