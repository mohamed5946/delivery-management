// Egyptian phone normalization + lookup keys.
//
// Identical to DeliveryFlow's login_identifier rules so both apps
// resolve the same identifier to the same account:
//   * contains '@'            → email, used directly;
//   * looks like a phone      → normalized, SHA-256 hashed, looked
//                                up in the phones collection;
//   * anything else           → lowercased username, looked up in
//                                the usernames collection.
// The raw phone number is NEVER a Firestore doc id.

import 'package:crypto/crypto.dart';

/// Canonical 10-digit Egyptian national number, or a shorter digit
/// string when the input cannot be normalized.
String normalizeEgyptPhone(String input) {
  var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('0020')) digits = digits.substring(4);
  if (digits.startsWith('20') && digits.length == 12) {
    digits = digits.substring(2);
  }
  if (digits.startsWith('0') && digits.length == 11) {
    digits = digits.substring(1);
  }
  return digits;
}

/// True for a plausible Egyptian mobile: 10 digits starting with '1'.
bool isValidEgyptPhone(String input) {
  final digits = normalizeEgyptPhone(input);
  return digits.length == 10 && digits.startsWith('1');
}

/// Looks like a phone number rather than a username or email.
bool looksLikePhone(String input) {
  final trimmed = input.trim();
  if (trimmed.contains('@')) return false;
  if (trimmed.isEmpty) return false;
  return RegExp(r'^[+0-9][0-9 ()\-]*$').hasMatch(trimmed);
}

/// Lookup key for the phones collection: SHA-256 hex of the
/// normalized phone. Never the raw phone number.
String phoneLookupKey(String input) {
  final digits = normalizeEgyptPhone(input);
  return sha256.convert(digits.codeUnits).toString();
}

/// Lookup key for the usernames collection: lowercased username.
String usernameLookupKey(String username) => username.trim().toLowerCase();

/// Lookup key for the email-username collection: SHA-256 hex of the
/// lowercased, trimmed email.
String emailLookupKey(String email) {
  return sha256.convert(email.trim().toLowerCase().codeUnits).toString();
}
