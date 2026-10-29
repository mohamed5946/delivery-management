// Widget tests for Delivery Management, driven through the real
// UI against a seeded FakeManagerBackend:
//   * manager login (username + phone) reaches the 4-tab shell
//   * driver login is refused, blocked login is refused
//   * payroll row and detail nets agree
//   * Application → فريق العمل → driver detail → order detail
//   * Block tab → detail → Unblock restores the member
//   * dashboard motion widgets render (count-up + rising bars)

import 'package:deliverymanagement/core/week_utils.dart';
import 'package:deliverymanagement/data/backend.dart';
import 'package:deliverymanagement/data/models.dart';
import 'package:deliverymanagement/features/block/block_screen.dart';
import 'package:deliverymanagement/features/dashboard/dashboard_screen.dart';
import 'package:deliverymanagement/features/session.dart';
import 'package:deliverymanagement/features/settings.dart';
import 'package:deliverymanagement/features/team/team_screen.dart';
import 'package:deliverymanagement/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

FakeManagerBackend seededBackend() {
  final now = DateTime.now();
  final today = dateKey(now);
  final weekKeys = weekDateKeys(now);
  final weekKey = weekKeys.first;
  // Two other days of the same week for week totals.
  final otherDays = weekKeys.where((k) => k != today).take(2).toList();
  final summaries = <DaySummary>[
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
    for (final k in otherDays)
      buildDaySummary(
        uid: 'd1',
        dateKey: k,
        ordersCount: 5,
        totalKm: 20,
        orderPrice: 9,
        dailyFixedPay: 705,
        distanceBonus: 0,
        manualBonus: 0,
        flatBonus: 0,
      ),
  ];
  final base = DateTime(now.year, now.month, now.day, 12).millisecondsSinceEpoch;
  final order = OrderEntry(
    id: 'ord-123456',
    dateKey: today,
    timestampMillis: base,
    kmOut: 5.5,
    kmBack: 4.2,
    notes: 'شارع النيل، المعادي',
    status: 3,
    pickupTimeMillis: base - 3600000,
    deliveredTimeMillis: base - 1800000,
    martArrivedTimeMillis: base,
    gpsKmOut: 5.5,
    gpsKmBack: 0,
    outgoingDurationSec: 600,
    returnDurationSec: 480,
    phone: '01000000009',
    manualBonusEgp: 10,
    createdAtMillis: base - 7200000,
  );
  return FakeManagerBackend(
    accounts: [
      const ManagerAccount(
        uid: 'm1',
        email: 'manager@test.com',
        username: 'admin',
        role: ManagerRole.manager,
        phone: '01000000001',
      ),
      const ManagerAccount(
        uid: 'd1',
        email: 'omar@test.com',
        username: 'omar',
        phone: '01000000002',
        payoutMethod: PayoutMethod.instapay,
        payoutNumber: '01000000002',
        payoutName: 'Omar Wallet',
      ),
      ManagerAccount(
        uid: 'b1',
        email: 'blocked@test.com',
        username: 'blocked1',
        phone: '01000000003',
        blocked: true,
        blockedAt: base,
      ),
    ],
    passwordsByEmail: {
      'manager@test.com': 'manager123',
      'omar@test.com': 'omar123',
      'blocked@test.com': 'blocked123',
    },
    summaries: {'d1': summaries},
    adjustments: {
      'd1': [
        Adjustment(
          id: 'a1',
          uid: 'd1',
          type: AdjustmentType.bonus,
          amount: 100,
          reason: 'بونص يدوي',
          weekKey: weekKey,
          createdBy: 'm1',
          createdAtMillis: base,
        ),
        Adjustment(
          id: 'a2',
          uid: 'd1',
          type: AdjustmentType.deduction,
          amount: 50,
          reason: 'تأخير',
          weekKey: weekKey,
          createdBy: 'm1',
          createdAtMillis: base,
        ),
      ],
    },
    orderRecords: {
      'd1': {
        today: DayOrderRecord(
          dateKey: today,
          completedOrders: 7,
          totalKm: 31.4,
          entries: [order],
        ),
      },
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
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  await tester.pumpWidget(
    DeliveryManagementApp(
      backend: backend,
      settings: SettingsController(),
      session: SessionController(backend),
    ),
  );
  // Let the post-frame session restore run, then settle.
  await tester.pump();
  await tester.pump();
}

Future<void> loginAs(
  WidgetTester tester, {
  required String identifier,
  required String password,
}) async {
  await tester.enterText(find.byKey(const ValueKey('loginIdentifier')), identifier);
  await tester.enterText(find.byKey(const ValueKey('loginPassword')), password);
  await tester.tap(find.byKey(const ValueKey('loginSubmit')));
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

void main() {
  testWidgets('manager login by username reaches the 4-tab shell',
      (tester) async {
    await pumpApp(tester, seededBackend());
    await loginAs(tester, identifier: 'admin', password: 'manager123');
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('الأجور الأسبوعية'), findsOneWidget);
    expect(find.text('Application'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
    expect(find.text('لوحة التحكم'), findsOneWidget);
  });

  testWidgets('manager login by phone reaches the shell', (tester) async {
    await pumpApp(tester, seededBackend());
    await loginAs(
      tester,
      identifier: '01000000001',
      password: 'manager123',
    );
    expect(find.text('لوحة التحكم'), findsOneWidget);
  });

  testWidgets('driver login is refused with managers-only message',
      (tester) async {
    await pumpApp(tester, seededBackend());
    await loginAs(tester, identifier: 'omar', password: 'omar123');
    expect(find.text('هذا التطبيق للمديرين فقط.'), findsOneWidget);
    expect(find.text('لوحة التحكم'), findsNothing);
  });

  testWidgets('blocked login is refused', (tester) async {
    await pumpApp(tester, seededBackend());
    await loginAs(tester, identifier: 'blocked1', password: 'blocked123');
    expect(find.text('هذا الحساب محظور. تواصل مع مدير آخر.'), findsOneWidget);
  });

  testWidgets('payroll row and detail nets agree', (tester) async {
    await pumpApp(tester, seededBackend());
    await loginAs(tester, identifier: 'admin', password: 'manager123');
    await tester.tap(find.text('الأجور الأسبوعية'));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    // Base 803 + 750 + 750 = 2303; +100 −50 = 2353.
    expect(find.text('2353 ج.م'), findsOneWidget);
    await tester.tap(find.text('omar'));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('2353 ج.م'), findsOneWidget);
    expect(find.text('بونص (تعديلات): +100 ج.م'), findsOneWidget);
    expect(find.text('خصومات (تعديلات): −50 ج.م'), findsOneWidget);
  });

  testWidgets(
      'Application → team → driver detail → order detail depth',
      (tester) async {
    await pumpApp(tester, seededBackend());
    await loginAs(tester, identifier: 'admin', password: 'manager123');
    await tester.tap(find.text('Application'));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('فريق العمل'), findsOneWidget);
    expect(find.text('1.0.0+1'), findsOneWidget);
    await tester.tap(find.text('فريق العمل'));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('omar'), findsOneWidget);
    await tester.tap(find.text('omar'));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    // Detail depth: phone, email, payout prefs.
    expect(find.text('01000000002'), findsWidgets);
    expect(find.text('omar@test.com'), findsOneWidget);
    expect(find.text('Omar Wallet'), findsOneWidget);
    // The seeded order entry is listed (below the fold — scroll to it).
    await tester.ensureVisible(find.text('شارع النيل، المعادي'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('شارع النيل، المعادي'), findsOneWidget);
    await tester.tap(find.text('شارع النيل، المعادي'));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    // Full order detail, field-for-field (status rides in the title line).
    expect(find.textContaining('مكتمل'), findsWidgets);
    expect(find.text('01000000009'), findsOneWidget);
    expect(find.textContaining('يدوي'), findsWidgets);
  });

  testWidgets('Block tab → detail → Unblock restores the member',
      (tester) async {
    await pumpApp(tester, seededBackend());
    await loginAs(tester, identifier: 'admin', password: 'manager123');
    await tester.tap(find.text('Block'));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('blocked1'), findsOneWidget);
    await tester.tap(find.text('blocked1'));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.tap(find.byKey(const ValueKey('blockedUnblock')));
    await tester.pump();
    // ConfirmButton: first tap arms, second confirms.
    await tester.tap(find.byKey(const ValueKey('confirmButton-فك الحظر')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirmButton-فك الحظر')));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('مفيش حد محظور حاليًا.'), findsOneWidget);
  });

  test('backend guards: no self role change, no self block, no self adjustment',
      () async {
    final backend = seededBackend();
    await backend.signInWithEmail('manager@test.com', 'manager123');
    expect(
      () => backend.setRole('m1', ManagerRole.driver, 'm1'),
      throwsA(isA<BackendDenied>()),
    );
    expect(
      () => backend.setBlocked('m1', true, 'm1'),
      throwsA(isA<BackendDenied>()),
    );
    expect(
      () => backend.addAdjustment(
        const Adjustment(
          id: '',
          uid: 'm1',
          type: AdjustmentType.bonus,
          amount: 10,
          reason: 'self',
          weekKey: '2026-10-25',
          createdBy: 'm1',
          createdAtMillis: 0,
        ),
        'm1',
      ),
      throwsA(isA<BackendDenied>()),
    );
  });

  testWidgets('LIVE: blocking a driver removes him from the team list instantly',
      (tester) async {
    final backend = seededBackend();
    await backend.signInWithEmail('manager@test.com', 'manager123');
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: TeamScreen(backend: backend, managerUid: 'm1'),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('omar'), findsOneWidget);
    // Block from "elsewhere" (as if another manager did it).
    await backend.setBlocked('d1', true, 'm1');
    await tester.pump();
    await tester.pump();
    expect(find.text('omar'), findsNothing);
    // The manager himself stays in the list — only omar leaves.
    expect(find.text('admin'), findsOneWidget);
    // Unblock restores him live.
    await backend.setBlocked('d1', false, 'm1');
    await tester.pump();
    await tester.pump();
    expect(find.text('omar'), findsOneWidget);
  });

  testWidgets('LIVE: a new bonus lands on the dashboard week salary instantly',
      (tester) async {
    final backend = seededBackend();
    final session = SessionController(backend);
    await session.signIn('admin', 'manager123');
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(backend: backend, session: session),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    // Base 2303 + 100 − 50 = 2353 (number and unit are separate
    // widgets on the dashboard card).
    expect(find.text('2353'), findsOneWidget);
    final weekKey = weekDateKeys(DateTime.now()).first;
    await backend.addAdjustment(
      Adjustment(
        id: '',
        uid: 'd1',
        type: AdjustmentType.bonus,
        amount: 200,
        reason: 'بونص إضافي',
        weekKey: weekKey,
        createdBy: 'm1',
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
      'm1',
    );
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('2553'), findsOneWidget);
  });

  testWidgets('LIVE: unblocking restores the Block tab to empty instantly',
      (tester) async {
    final backend = seededBackend();
    await backend.signInWithEmail('manager@test.com', 'manager123');
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: BlockScreen(backend: backend, managerUid: 'm1'),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('blocked1'), findsOneWidget);
    await backend.setBlocked('b1', false, 'm1');
    await tester.pump();
    await tester.pump();
    expect(find.text('مفيش حد محظور حاليًا.'), findsOneWidget);
  });
}
