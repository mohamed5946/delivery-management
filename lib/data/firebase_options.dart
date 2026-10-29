// Firebase configuration for Delivery Management.
//
// SAME project as DeliveryFlow (deliveryflow-fbe9f) — no new
// backend, no data migration. The values below are PLACEHOLDERS on
// purpose: no API key or app id is ever committed to this repo.
//
// Console steps (project owner only, once):
//   1. Firebase console → project deliveryflow-fbe9f → Project
//      settings → "Your apps" → Add app → Android.
//   2. Android package name: com.valor.deliverymanagement
//      (no SHA-1 needed for v1: email/password Auth only, no
//      Google sign-in).
//   3. Download google-services.json, open it, and copy its values
//      into [DefaultFirebaseOptions] below (apiKey, appId,
//      messagingSenderId, projectId). The app shows a clear
//      "Firebase not configured" message on the login screen until
//      then — it never fails silently.
// No Firestore rules change is needed: the rules already grant
// manager accounts (role == manager) read/write over the same
// collections this app uses.

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'PASTE_YOUR_API_KEY',
    appId: 'PASTE_YOUR_APP_ID',
    messagingSenderId: 'PASTE_YOUR_SENDER_ID',
    projectId: 'deliveryflow-fbe9f',
    storageBucket: 'deliveryflow-fbe9f.firebasestorage.app',
  );

  /// True once real console values have replaced the placeholders.
  static bool get isConfigured =>
      !currentPlatform.apiKey.startsWith('PASTE_') &&
      !currentPlatform.appId.startsWith('PASTE_');
}
