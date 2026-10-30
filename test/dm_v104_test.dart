// v1.0.4 tests — manager-initiated password reset for a driver:
//   * backend sends the reset to the driver's email on file
//   * guards: never self, never another manager, never no-email
//     (and no-email sends nothing)
//   * UI: confirmation dialog gates the send; dismissing sends
//     nothing; confirming sends and shows the sent confirmation
//   * failure surfaces the exact reason loudly (dialog, not silent)
//   * the action is hidden for manager rows and for the self row
//   * AR/EN strings exist for the whole flow
//   * HARD RULE: no password is ever displayed, stored, logged or
//     transmitted — the reset-link email is the entire feature
//     (these tests assert the send path only ever carries an email)

import 'package:deliverymanagement/core/diagnostics.dart';
import 'package:deliverymanagement/core/strings.dart';
import 'package:deliverymanagement/data/backend.dart';
import 'package:deliverymanagement/data/models.dart';
import 'package:deliverymanagement/features/team/team_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FakeManagerBackend seededBackend() {
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
      ),
      const ManagerAccount(
        uid: 'd2',
        email: '',
        username: 'noemail',
        phone: '01000000003',
      ),
      const ManagerAccount(
        uid: 'm2',
        email: 'other-manager@test.com',
        username: 'boss2',
        role: ManagerRole.manager,
        phone: '01000000004',
      ),
    ],
  );
}

Future<void> pumpDetail(
  WidgetTester tester,
  FakeManagerBackend backend,
  ManagerAccount account,
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
      home: DriverDetailScreen(
        backend: backend,
        managerUid: 'm1',
        account: account,
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

Future<void> tapReset(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('driverPasswordReset'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle(const Duration(seconds: 1));
  await tester.tap(button);
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

void main() {
  test('backend: reset sends to the driver email on file', () async {
    final backend = seededBackend();
    await backend.sendDriverPasswordReset('d1', 'm1');
    expect(backend.resetEmailsSent, ['omar@test.com']);
  });

  test('backend guards: never self, never manager, never no-email',
      () async {
    final backend = seededBackend();
    expect(
      () => backend.sendDriverPasswordReset('m1', 'm1'),
      throwsA(isA<BackendDenied>()),
    );
    expect(
      () => backend.sendDriverPasswordReset('m2', 'm1'),
      throwsA(isA<BackendDenied>()),
    );
    expect(
      () => backend.sendDriverPasswordReset('d2', 'm1'),
      throwsA(isA<BackendDenied>()),
    );
    expect(backend.resetEmailsSent, isEmpty);
  });

  test('backend: failure seam throws the exact error', () async {
    final backend = seededBackend();
    backend.sendResetError = const BackendDenied('خطأ تجريبي.');
    expect(
      () => backend.sendDriverPasswordReset('d1', 'm1'),
      throwsA(
        isA<BackendDenied>().having(
          (e) => e.message,
          'message',
          'خطأ تجريبي.',
        ),
      ),
    );
    expect(backend.resetEmailsSent, isEmpty);
  });

  testWidgets('confirmation dialog gates the send; dismiss sends nothing',
      (tester) async {
    final backend = seededBackend();
    const driver = ManagerAccount(
      uid: 'd1',
      email: 'omar@test.com',
      username: 'omar',
      phone: '01000000002',
    );
    await pumpDetail(tester, backend, driver);
    expect(find.byKey(const ValueKey('driverPasswordReset')), findsOneWidget);
    await tapReset(tester);
    // The dialog explains the flow before anything is sent.
    expect(find.text(DmStrings.arabic.sendResetQ), findsOneWidget);
    expect(
      find.text(DmStrings.arabic.sendResetBody('omar')),
      findsOneWidget,
    );
    expect(backend.resetEmailsSent, isEmpty);
    // Dismiss: nothing sent.
    await tester.tap(find.text(DmStrings.arabic.cancel));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(backend.resetEmailsSent, isEmpty);
  });

  testWidgets('confirming sends and shows the sent confirmation',
      (tester) async {
    diagnosticsLog.clear();
    final backend = seededBackend();
    const driver = ManagerAccount(
      uid: 'd1',
      email: 'omar@test.com',
      username: 'omar',
      phone: '01000000002',
    );
    await pumpDetail(tester, backend, driver);
    await tapReset(tester);
    // ConfirmButton: first tap arms, second confirms.
    final confirmKey = ValueKey(
      'confirmButton-${DmStrings.arabic.sendResetAction}',
    );
    await tester.tap(find.byKey(confirmKey));
    await tester.pump();
    await tester.tap(find.byKey(confirmKey));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(backend.resetEmailsSent, ['omar@test.com']);
    expect(find.text(DmStrings.arabic.sendResetSent), findsOneWidget);
    expect(
      diagnosticsLog.entries
          .any((e) => e.message.contains('password reset email sent')),
      isTrue,
    );
    // The log never carries an email, link, or code.
    expect(
      diagnosticsLog.entries
          .any((e) => e.message.contains('omar@test.com')),
      isFalse,
    );
  });

  testWidgets('no-email driver: plain message, nothing sent',
      (tester) async {
    final backend = seededBackend();
    const driver = ManagerAccount(
      uid: 'd2',
      email: '',
      username: 'noemail',
      phone: '01000000003',
    );
    await pumpDetail(tester, backend, driver);
    await tapReset(tester);
    expect(find.text(DmStrings.arabic.sendResetNoEmail), findsOneWidget);
    expect(backend.resetEmailsSent, isEmpty);
  });

  testWidgets('failure surfaces the exact reason loudly', (tester) async {
    diagnosticsLog.clear();
    final backend = seededBackend();
    backend.sendResetError = const BackendDenied('خطأ تجريبي.');
    const driver = ManagerAccount(
      uid: 'd1',
      email: 'omar@test.com',
      username: 'omar',
      phone: '01000000002',
    );
    await pumpDetail(tester, backend, driver);
    await tapReset(tester);
    final confirmKey = ValueKey(
      'confirmButton-${DmStrings.arabic.sendResetAction}',
    );
    await tester.tap(find.byKey(confirmKey));
    await tester.pump();
    await tester.tap(find.byKey(confirmKey));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text(DmStrings.arabic.sendResetFailedTitle), findsOneWidget);
    expect(find.text('فشل: خطأ تجريبي.'), findsOneWidget);
    expect(backend.resetEmailsSent, isEmpty);
    expect(
      diagnosticsLog.entries
          .any((e) => e.message.contains('password reset email failed')),
      isTrue,
    );
  });

  testWidgets('action hidden for manager rows and for the self row',
      (tester) async {
    final backend = seededBackend();
    const otherManager = ManagerAccount(
      uid: 'm2',
      email: 'other-manager@test.com',
      username: 'boss2',
      role: ManagerRole.manager,
      phone: '01000000004',
    );
    await pumpDetail(tester, backend, otherManager);
    expect(find.byKey(const ValueKey('driverPasswordReset')), findsNothing);
    const self = ManagerAccount(
      uid: 'm1',
      email: 'manager@test.com',
      username: 'admin',
      role: ManagerRole.manager,
      phone: '01000000001',
    );
    await pumpDetail(tester, backend, self);
    expect(find.byKey(const ValueKey('driverPasswordReset')), findsNothing);
  });

  test('reset strings exist in both languages', () {
    for (final s in [DmStrings.arabic, DmStrings.english]) {
      expect(s.sendResetAction, isNotEmpty);
      expect(s.sendResetQ, isNotEmpty);
      expect(s.sendResetBody('omar'), contains('omar'));
      expect(s.sendResetNoEmail, isNotEmpty);
      expect(s.sendResetSent, isNotEmpty);
      expect(s.sendResetFailedTitle, isNotEmpty);
    }
    expect(DmStrings.arabic.sendResetAction, 'إرسال إعادة تعيين كلمة السر');
    expect(DmStrings.english.sendResetAction, 'Send password reset');
  });
}
