// Firebase configuration for Delivery Management.
//
// SAME project as DeliveryFlow (deliveryflow-fbe9f) — no new
// backend, no data migration. Real console values, registered
// 2026-10-29: Android app com.valor.deliverymanagement added to
// project deliveryflow-fbe9f (owner account); values below copied
// from that app's downloaded google-services.json.
// No Firestore rules change is needed: the rules already grant
// manager accounts (role == manager) read/write over the same
// collections this app uses.

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'AIzaSyDGmiN3IEP7UMaSoNtll-Xrs-p3zshPVKg',
    appId: '1:577744614135:android:81cdcd20ca3c00cfbcd9f2',
    messagingSenderId: '577744614135',
    projectId: 'deliveryflow-fbe9f',
    storageBucket: 'deliveryflow-fbe9f.firebasestorage.app',
  );

  /// True once real console values have replaced the placeholders.
  static bool get isConfigured =>
      !currentPlatform.apiKey.startsWith('PASTE_') &&
      !currentPlatform.appId.startsWith('PASTE_');
}
