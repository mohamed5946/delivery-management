// Regression tests for the v1.0.0 launch freeze.
//
// v1.0.0 froze on the Android launch splash on a real phone: main()
// constructed FirestoreManagerBackend() — whose constructor reads
// FirebaseAuth.instance — before runApp while Firebase was
// unconfigured (initializeApp skipped), so the constructor threw
// before any Flutter frame ever rendered. The fix: the real backend
// is constructed ONLY after a successful initializeApp, and the
// unconfigured path runs on UnconfiguredBackend, which must reach
// a readable login screen — never throw pre-frame.

import 'package:deliverymanagement/data/backend.dart';
import 'package:deliverymanagement/features/session.dart';
import 'package:deliverymanagement/features/settings.dart';
import 'package:deliverymanagement/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpUnconfiguredApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'Delivery Management',
    packageName: 'com.valor.deliverymanagement',
    version: '1.0.1',
    buildNumber: '2',
    buildSignature: '',
  );
  const backend = UnconfiguredBackend();
  await tester.pumpWidget(
    DeliveryManagementApp(
      backend: backend,
      settings: SettingsController(),
      session: SessionController(backend),
      firebaseReady: false,
    ),
  );
  // Let the post-frame session restore run (uid is null → signed out).
  await tester.pump();
  await tester.pump();
}

void main() {
  test('UnconfiguredBackend never touches Firebase', () async {
    const backend = UnconfiguredBackend();
    expect(backend.currentUid, isNull);
    await expectLater(
      backend.resolveEmail('admin'),
      throwsA(isA<BackendNotConfigured>()),
    );
    await expectLater(
      backend.listUsers(),
      throwsA(isA<BackendNotConfigured>()),
    );
    await expectLater(
      backend.watchUsers().toList(),
      throwsA(isA<BackendNotConfigured>()),
    );
    await expectLater(
      backend.loadAccount('uid'),
      throwsA(isA<BackendNotConfigured>()),
    );
  });

  testWidgets('unconfigured app reaches a readable login screen',
      (tester) async {
    // Pumping itself proves a frame renders: the v1.0.0 bug threw
    // before the first frame and nothing would render at all.
    await pumpUnconfiguredApp(tester);
    expect(find.byKey(const ValueKey('loginIdentifier')), findsOneWidget);
    expect(find.byKey(const ValueKey('loginPassword')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('firebaseNotConfiguredBanner')),
      findsOneWidget,
    );
  });

  testWidgets('unconfigured sign-in attempt surfaces a plain message',
      (tester) async {
    await pumpUnconfiguredApp(tester);
    await tester.enterText(
      find.byKey(const ValueKey('loginIdentifier')),
      'admin',
    );
    await tester.enterText(
      find.byKey(const ValueKey('loginPassword')),
      'whatever',
    );
    await tester.tap(find.byKey(const ValueKey('loginSubmit')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('loginError')), findsOneWidget);
  });
}
