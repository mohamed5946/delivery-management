// v1.0.3 tests:
//   * language switch changes locale and persists (SettingsController
//     + DmStrings.forLocale), and the whole UI follows it
//   * pushed detail routes use the light theme (DmPage paints the
//     aurora behind the page itself — the v1.0.2 black-detail bug)
//   * dashboard entrance uses slide-up on every entry (generation
//     bump replays), keeps count-up + rising bars, and the
//     self-descriptive caption text is gone
//   * payroll + dashboard aggregates exclude manager accounts
//     (Team roster still lists everyone — covered by widget tests)

import 'package:deliverymanagement/core/strings.dart';
import 'package:deliverymanagement/core/week_utils.dart';
import 'package:deliverymanagement/data/backend.dart';
import 'package:deliverymanagement/data/models.dart';
import 'package:deliverymanagement/features/dashboard/dashboard_screen.dart';
import 'package:deliverymanagement/features/payroll/payroll_screen.dart';
import 'package:deliverymanagement/features/session.dart';
import 'package:deliverymanagement/features/settings.dart';
import 'package:deliverymanagement/theme/dm_theme.dart';
import 'package:deliverymanagement/widgets/entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seeded backend: one manager WITH summaries (the stray admin copy)
/// and one driver. Driver week: today 7 orders / 31.4 km / 803 EGP
/// + two 5-order days at 750 EGP = base 2303, +100 −50 = 2353 net.
/// Manager week (must be EXCLUDED): today 10 orders / 9999 EGP.
FakeManagerBackend seededBackend() {
  final now = DateTime.now();
  final today = dateKey(now);
  final weekKeys = weekDateKeys(now);
  final weekKey = weekKeys.first;
  final otherDays = weekKeys.where((k) => k != today).take(2).toList();
  final driverSummaries = <DaySummary>[
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
  final managerSummaries = <DaySummary>[
    buildDaySummary(
      uid: 'm1',
      dateKey: today,
      ordersCount: 10,
      totalKm: 100,
      orderPrice: 9,
      dailyFixedPay: 9909,
      distanceBonus: 0,
      manualBonus: 0,
      flatBonus: 0,
    ),
  ];
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
    ],
    passwordsByEmail: {
      'manager@test.com': 'manager123',
      'omar@test.com': 'omar123',
    },
    summaries: {'d1': driverSummaries, 'm1': managerSummaries},
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
          createdAtMillis:
              DateTime(now.year, now.month, now.day, 12)
                  .millisecondsSinceEpoch,
        ),
        Adjustment(
          id: 'a2',
          uid: 'd1',
          type: AdjustmentType.deduction,
          amount: 50,
          reason: 'تأخير',
          weekKey: weekKey,
          createdBy: 'm1',
          createdAtMillis:
              DateTime(now.year, now.month, now.day, 12)
                  .millisecondsSinceEpoch,
        ),
      ],
    },
  );
}

Future<void> pumpAr(
  WidgetTester tester,
  Widget home,
) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      home: home,
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  test('language switch changes locale and persists', () async {
    SharedPreferences.setMockInitialValues({'dm_locale': 'en'});
    final settings = SettingsController();
    await settings.load();
    expect(settings.locale, const Locale('en'));
    // English strings across the whole UI surface.
    expect(DmStrings.forLocale(settings.locale).payrollTitle,
        'Weekly payroll');
    expect(DmStrings.forLocale(settings.locale).teamTitle, 'Team');
    expect(DmStrings.forLocale(settings.locale).blockTitle, 'Blocked');
    expect(DmStrings.forLocale(settings.locale).signOut, 'Sign out');
    expect(DmStrings.forLocale(settings.locale).money(3280), 'EGP 3280');
    // Switch back to Arabic: persisted, and Arabic strings return.
    await settings.setLocale(const Locale('ar'));
    expect(settings.locale, const Locale('ar'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('dm_locale'), 'ar');
    expect(DmStrings.forLocale(settings.locale).payrollTitle,
        'الأجور الأسبوعية');
    expect(DmStrings.forLocale(settings.locale).money(3280), '3280 ج.م');
  });

  testWidgets('DmPage paints the aurora behind pushed pages (light theme fix)',
      (tester) async {
    // DmPage is what every pushed detail screen uses now: the
    // aurora sits behind a transparent Scaffold, so a pushed route
    // can never render black the way v1.0.2 payout detail did.
    await pumpAr(
      tester,
      DmPage(
        appBar: AppBar(title: const Text('detail')),
        body: const Text('body'),
      ),
    );
    expect(find.byType(DmAuroraBackground), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.transparent);
  });

  testWidgets('dashboard entrance: slide-up, count-up + bars kept, '
      'caption gone', (tester) async {
    // Stagger contract (DeliveryFlow params): 80ms steps, capped
    // at index 7 — long lists never wait seconds.
    expect(SlideUpItem.delayFor(0), Duration.zero);
    expect(SlideUpItem.delayFor(1), const Duration(milliseconds: 80));
    expect(SlideUpItem.delayFor(7), const Duration(milliseconds: 560));
    expect(SlideUpItem.delayFor(20), const Duration(milliseconds: 560));

    final backend = seededBackend();
    final session = SessionController(backend);
    await session.signIn('admin', 'manager123');
    await pumpAr(
      tester,
      DashboardScreen(backend: backend, session: session),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
    // Slide-up entrance present on the dashboard body.
    expect(find.byType(SlideUpItem), findsWidgets);
    // The user's original "alive" spec stands: count-up KPIs and
    // rising bars are still there.
    expect(find.byType(CountUpNumber), findsWidgets);
    expect(find.byType(RisingBar), findsWidgets);
    // The self-descriptive caption is deleted — nowhere in the app.
    expect(
      find.text('الأعمدة بتطلع من تحت لفوق، والأرقام بتتعد من صفر — '
          'البرنامج حي معاك.'),
      findsNothing,
    );
    // Driver week net (2353) renders; the manager's stray 9999+
    // copy must NOT inflate it.
    expect(find.text('2353'), findsOneWidget);
  });

  testWidgets('payroll excludes manager accounts', (tester) async {
    final backend = seededBackend();
    // Payroll streams require a signed-in manager (fake backend
    // gates watchUsers on the session, same as the real rules).
    final session = SessionController(backend);
    await session.signIn('admin', 'manager123');
    await pumpAr(
      tester,
      PayrollScreen(backend: backend, managerUid: 'm1'),
    );
    // Bounded pumps (not pumpAndSettle: the loading skeleton's
    // shimmer repeats forever, so settle would never return).
    for (var i = 0; i < 30 && find.text('omar').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Driver row present with his net; manager row absent.
    expect(find.text('omar'), findsOneWidget);
    expect(find.text('2353 ج.م'), findsOneWidget);
    expect(find.text('admin'), findsNothing);
  });

  testWidgets('dashboard aggregates exclude manager summaries',
      (tester) async {
    final backend = seededBackend();
    final session = SessionController(backend);
    await session.signIn('admin', 'manager123');
    await pumpAr(
      tester,
      DashboardScreen(backend: backend, session: session),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
    // Team count KPI = drivers only (1), not 2.
    expect(find.text('1'), findsWidgets);
    // Manager's 10 today-orders must not appear in the week total:
    // driver week orders = 7 + 5 + 5 = 17.
    expect(find.text('17'), findsWidgets);
    // Driver week net still 2353 (manager 9999+ excluded).
    expect(find.text('2353'), findsOneWidget);
  });
}
