/// Centralised form-field validators.
///
/// Each method returns a [String?] compatible with [TextFormField.validator].
/// Pass the BuildContext only when you need localised messages; the fallback
/// English strings are used otherwise so validators work in non-widget tests.
class AppValidators {
  AppValidators._();

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final re = RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$');
    if (!re.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? validateRequired(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  /// Full name — 2 to 100 characters, letters and spaces only.
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    if (value.trim().length > 100) return 'Name must be under 100 characters';
    return null;
  }

  /// Age — suitable for elderly users (40–120).
  static String? validateAge(String? value) {
    if (value == null || value.trim().isEmpty) return 'Age is required';
    final n = int.tryParse(value.trim());
    if (n == null) return 'Age must be a number';
    if (n < 1 || n > 120) return 'Enter a valid age (1–120)';
    return null;
  }

  /// Phone — digits, spaces, dashes, plus sign; 7–15 digits total.
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    final re = RegExp(r'^\+?[\d\s\-().]{7,20}$');
    if (!re.hasMatch(value.trim())) return 'Enter a valid phone number';
    return null;
  }

  /// Height in centimetres (50–250 cm), optional field.
  static String? validateHeight(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final n = double.tryParse(value.trim());
    if (n == null) return 'Height must be a number';
    if (n < 50 || n > 250) return 'Enter height between 50 and 250 cm';
    return null;
  }

  /// Weight in kilograms (20–300 kg), optional field.
  static String? validateWeight(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final n = double.tryParse(value.trim());
    if (n == null) return 'Weight must be a number';
    if (n < 20 || n > 300) return 'Enter weight between 20 and 300 kg';
    return null;
  }

  /// OTP — exactly 6 digits.
  static String? validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) return 'Verification code is required';
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) return 'Code must be 6 digits';
    return null;
  }

  /// Reminder title — required, 3–100 characters.
  static String? validateReminderTitle(String? value) {
    if (value == null || value.trim().isEmpty) return 'Title is required';
    if (value.trim().length < 3) return 'Title must be at least 3 characters';
    if (value.trim().length > 100) return 'Title must be under 100 characters';
    return null;
  }
}
