// v1.0.2 resilience tests: the dashboard (and payroll) no longer use
// a collectionGroup('summaries') query — it is denied with
// PERMISSION_DENIED for a manager under the published rules
// (field-proven 2026-10-29) — so they attach one summaries listener
// per visible user and fall back to a one-time fetch when a listener
// errors, showing the REAL reason on the error card.

import 'package:deliverymanagement/core/week_utils.dart';
import 'package:deliverymanagement/data/backend.dart';
import 'package:deliverymanagement/data/models.dart';
import 'package:deliverymanagement/features/session.dart';
import 'package:deliverymanagement/features/settings.dart';
import 'package:deliverymanagement/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

FakeManagerBackend seededBackend() {
  final now = DateTime.now();
  final today = dateKey(now);
  return FakeManagerBackend(
    accounts: const [
      ManagerAccount(
        uid: 'm1',
        email: 'manager@test.com',
        username: 'admin',
        role: ManagerRole.manager,
        phone: '01000000001',
      ),
      ManagerAccount(
        uid: 'd1',
        email: 'omar@test.com',
        username: 'omar',
        phone: '01000000002',
      ),
      ManagerAccount(
        uid: 'd2',
        email: 'mona@test.com',
        username: 'mona',
        phone: '01000000003',
      ),
    ],
    passwordsByEmail: const {
      'manager@test.com': 'manager123',
      'omar@test.com': 'omar123',
      'mona@test.com': 'mona123',
    },
    summaries: {
      'd1': [
        buildDaySummary(
          uid: 'd1',
          dateKey: today,
          ordersCount: 7,
          totalKm: 31.4,
          orderPrice: 9,
          dailyFixedPay: 705,
          distanceBonus: 0,
          manualBonus: 0,
          flatBonus: 35,
        ),
      ],
      'd2': [
        buildDaySummary(
          uid: 'd2',
          dateKey: today,
          ordersCount: 5,
          totalKm: 20.0,
          orderPrice: 9,
          dailyFixedPay: 705,
          distanceBonus: 0,
          manualBonus: 0,
          flatBonus: 0,
        ),
      ],
    },
  );
}

Future<void> pumpApp(
  WidgetTester tester,
  FakeManagerBackend backend,
) async {
  SharedPreferences.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'Delivery Management',
    packageName: 'com.valor.deliverymanagement',
    version: '1.0.2',
    buildNumber: '3',
    buildSignature: '',
  );
  await tester.pumpWidget(
    DeliveryManagementApp(
      backend: backend,
      settings: SettingsController(),
      session: SessionController(backend),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> loginAsManager(WidgetTester tester) async {
  await tester.enterText(
      find.byKey(const ValueKey('loginIdentifier')), 'admin');
  await tester.enterText(
      find.byKey(const ValueKey('loginPassword')), 'manager123');
  await tester.tap(find.byKey(const ValueKey('loginSubmit')));
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

void main() {
  testWidgets(
    'per-user summaries listeners aggregate across users',
    (tester) async {
      final backend = seededBackend();
      await pumpApp(tester, backend);
      await loginAsManager(tester);
      // Both drivers' today summaries arrived through their own
      // listeners: synced rows with orders + km (not "غير متزامن").
      expect(find.text('7 أوردر • 31.4 كم'), findsOneWidget);
      expect(find.text('5 أوردر • 20.0 كم'), findsOneWidget);
    },
  );

  testWidgets(
    'summaries listener error falls back to one-time fetch and shows '
    'the real reason',
    (tester) async {
      final backend = seededBackend();
      backend.summariesStreamError = 'permission-denied-test';
      await pumpApp(tester, backend);
      await loginAsManager(tester);
      // The REAL reason is on the card — not a generic line.
      expect(
        find.text(
          'الاتصال المباشر وقف (summaries): permission-denied-test',
        ),
        findsOneWidget,
      );
      // The fallback note is visible…
      expect(
        find.text(
          'البيانات المعروضة من جلب لمرة واحدة — '
          'اضغط إعادة الاتصال لاستعادة المباشر.',
        ),
        findsOneWidget,
      );
      // …and the fallback data still renders (no empty skeletons).
      expect(find.text('7 أوردر • 31.4 كم'), findsOneWidget);
      expect(find.text('5 أوردر • 20.0 كم'), findsOneWidget);
      expect(find.text('إعادة الاتصال'), findsOneWidget);
    },
  );

  test('settings default theme is light (DeliveryFlow default)', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    expect(settings.themeMode, ThemeMode.light);
    await settings.load();
    expect(settings.themeMode, ThemeMode.light);
  });

  test('settings honors a stored system choice', () async {
    SharedPreferences.setMockInitialValues({'dm_theme_mode': 'system'});
    final settings = SettingsController();
    await settings.load();
    expect(settings.themeMode, ThemeMode.system);
  });
}
