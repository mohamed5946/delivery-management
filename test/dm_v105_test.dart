// v1.0.5 tests — drivers map + order destination:
//   * destination parser: geo: intents, Google Maps URLs, plain
//     "address @ lat,lng", bare pairs, address-only, invalid pairs
//     (out of range / 0,0 placeholder) never yield coordinates
//   * driver location fields parse from the profile doc; out-of-
//     range or 0,0 locations count as "no location"
//   * drivers map tab: drivers with no location show "مفيش موقع
//     لسه" + the honest note; a located driver shows its coords
//   * order detail: parsed destination (address + coordinates +
//     map) and order amount = day order price + manual bonus;
//     customer is identified by phone ONLY — no name is invented

import 'package:deliverymanagement/core/destination.dart';
import 'package:deliverymanagement/core/week_utils.dart';
import 'package:deliverymanagement/data/backend.dart';
import 'package:deliverymanagement/data/models.dart';
import 'package:deliverymanagement/features/map/drivers_map_screen.dart';
import 'package:deliverymanagement/features/team/team_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDestination', () {
    test('geo:lat,lng', () {
      final d = parseDestination('geo:30.0444,31.2357');
      expect(d.hasCoords, isTrue);
      expect(d.lat, closeTo(30.0444, 0.00001));
      expect(d.lng, closeTo(31.2357, 0.00001));
      expect(d.address, isEmpty);
    });

    test('geo:lat,lng?q=address keeps the address', () {
      final d = parseDestination('geo:30.0444,31.2357?q=شارع النيل');
      expect(d.hasCoords, isTrue);
      expect(d.address, 'شارع النيل');
    });

    test('geo:0,0?q=address is address-only, never 0,0 coords', () {
      final d = parseDestination('geo:0,0?q=شارع النيل، المعادي');
      expect(d.hasCoords, isFalse);
      expect(d.address, 'شارع النيل، المعادي');
    });

    test('Google Maps ?q=lat,lng', () {
      final d = parseDestination(
        'https://maps.google.com/?q=30.0444,31.2357',
      );
      expect(d.hasCoords, isTrue);
      expect(d.lat, closeTo(30.0444, 0.00001));
    });

    test('Google Maps /@lat,lng path', () {
      final d = parseDestination(
        'https://www.google.com/maps/place/Cairo/@30.0444,31.2357,17z',
      );
      expect(d.hasCoords, isTrue);
      expect(d.lng, closeTo(31.2357, 0.00001));
    });

    test('Google Maps ?q=address is address-only', () {
      final d = parseDestination(
        'https://maps.google.com/?q=%D8%B4%D8%A7%D8%B1%D8%B9%20%D8%A7%D9%84%D9%86%D9%8A%D9%84',
      );
      expect(d.hasCoords, isFalse);
      expect(d.address, 'شارع النيل');
    });

    test('plain "address @ lat,lng" (Flex share form)', () {
      final d = parseDestination('شارع النيل، المعادي @ 30.04440,31.23570');
      expect(d.hasCoords, isTrue);
      expect(d.address, 'شارع النيل، المعادي');
      expect(d.coordsLabel, '30.04440, 31.23570');
    });

    test('bare lat,lng', () {
      final d = parseDestination('30.0444, 31.2357');
      expect(d.hasCoords, isTrue);
      expect(d.address, isEmpty);
    });

    test('plain address only has no coordinates', () {
      final d = parseDestination('شارع النيل، المعادي');
      expect(d.hasCoords, isFalse);
      expect(d.address, 'شارع النيل، المعادي');
    });

    test('out-of-range pair is not coordinates', () {
      final d = parseDestination('بعض العنوان @ 999.0, 999.0');
      expect(d.hasCoords, isFalse);
    });

    test('empty text parses to nothing', () {
      final d = parseDestination('   ');
      expect(d.hasCoords, isFalse);
      expect(d.address, isEmpty);
    });
  });

  group('driver location fields', () {
    test('fromJson reads lastLat/lastLng/lastLocationAtMillis', () {
      final a = ManagerAccount.fromJson('d1', {
        'email': 'omar@test.com',
        'username': 'omar',
        'lastLat': 30.05,
        'lastLng': 31.24,
        'lastLocationAtMillis': 1700000000000,
      });
      expect(a.hasLocation, isTrue);
      expect(a.lastLat, 30.05);
      expect(a.lastLocationAtMillis, 1700000000000);
    });

    test('missing location fields mean no location, never a guess', () {
      final a = ManagerAccount.fromJson('d1', {
        'email': 'omar@test.com',
        'username': 'omar',
      });
      expect(a.hasLocation, isFalse);
      expect(a.lastLat, isNull);
    });

    test('0,0 and out-of-range locations count as no location', () {
      final zero = ManagerAccount.fromJson('d1', {
        'username': 'omar',
        'lastLat': 0,
        'lastLng': 0,
      });
      expect(zero.hasLocation, isFalse);
      final wild = ManagerAccount.fromJson('d1', {
        'username': 'omar',
        'lastLat': 95.0,
        'lastLng': 31.0,
      });
      expect(wild.hasLocation, isFalse);
    });

    test('copyWith keeps the location (role/block edits)', () {
      const a = ManagerAccount(
        uid: 'd1',
        email: 'omar@test.com',
        username: 'omar',
        lastLat: 30.05,
        lastLng: 31.24,
        lastLocationAtMillis: 1700000000000,
      );
      final blocked = a.copyWith(blocked: true);
      expect(blocked.hasLocation, isTrue);
      expect(blocked.lastLat, 30.05);
    });
  });

  FakeManagerBackend seededBackend() {
    final now = DateTime.now();
    final today = dateKey(now);
    final base =
        DateTime(now.year, now.month, now.day, 12).millisecondsSinceEpoch;
    final order = OrderEntry(
      id: 'ord-123456',
      dateKey: today,
      timestampMillis: base,
      kmOut: 5.5,
      kmBack: 4.2,
      notes: 'شارع النيل، المعادي @ 30.04440,31.23570',
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
        ),
        ManagerAccount(
          uid: 'd2',
          email: 'ali@test.com',
          username: 'ali',
          phone: '01000000003',
          lastLat: 30.05,
          lastLng: 31.24,
          lastLocationAtMillis: base,
        ),
      ],
      passwordsByEmail: const {'manager@test.com': 'manager123'},
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

  Future<void> pumpMap(WidgetTester tester, FakeManagerBackend backend) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        home: Scaffold(
          body: DriversMapScreen(
            backend: backend,
            managerUid: 'm1',
            entryGeneration: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('drivers map: no-location drivers show "مفيش موقع لسه"',
      (tester) async {
    final backend = seededBackend();
    await backend.signInWithEmail('manager@test.com', 'manager123');
    await pumpMap(tester, backend);
    expect(find.text('خريطة السواقين'), findsOneWidget);
    // omar has no location; ali does.
    expect(find.text('مفيش موقع لسه'), findsOneWidget);
    expect(find.textContaining('30.05000'), findsOneWidget);
    // Honest note: no locations exist yet is NOT shown when one
    // driver does have a location.
    expect(find.textContaining('لسه مفيش موقع لأي سواق'), findsNothing);
  });

  testWidgets('drivers map: nobody located shows the honest note',
      (tester) async {
    final backend = FakeManagerBackend(
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
      ],
      passwordsByEmail: const {'manager@test.com': 'manager123'},
    );
    await backend.signInWithEmail('manager@test.com', 'manager123');
    await pumpMap(tester, backend);
    expect(find.text('مفيش موقع لسه'), findsOneWidget);
    expect(find.textContaining('لسه مفيش موقع لأي سواق'), findsOneWidget);
  });

  testWidgets(
      'order detail: destination card + order amount, phone only',
      (tester) async {
    final backend = seededBackend();
    await backend.signInWithEmail('manager@test.com', 'manager123');
    final account = (await backend.listUsers())
        .firstWhere((a) => a.uid == 'd1');
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
    await tester.ensureVisible(find.text('شارع النيل، المعادي @ 30.04440,31.23570'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.tap(find.text('شارع النيل، المعادي @ 30.04440,31.23570'));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    // Destination: parsed address + exact coordinates.
    expect(find.text('وجهة الأوردر'), findsOneWidget);
    expect(find.text('شارع النيل، المعادي'), findsOneWidget);
    expect(find.text('30.04440, 31.23570'), findsOneWidget);
    // Order amount = day order price (9) + manual bonus (10).
    expect(find.text('قيمة الأوردر: 19 ج.م'), findsOneWidget);
    // Customer identifier is the phone number only — no name.
    expect(find.text('01000000009'), findsWidgets);
  });
}
