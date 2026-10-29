// Pure-logic tests for Delivery Management: phone normalization,
// week math, salary math, payout math, the manager gate, and the
// order-record parsing (including the honest count-only cloud shape).

import 'package:deliverymanagement/core/phone_utils.dart';
import 'package:deliverymanagement/core/week_utils.dart';
import 'package:deliverymanagement/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('phone normalization', () {
    test('all written forms of one number normalize the same', () {
      expect(normalizeEgyptPhone('01000000002'), '1000000002');
      expect(normalizeEgyptPhone('+201000000002'), '1000000002');
      expect(normalizeEgyptPhone('00201000000002'), '1000000002');
      expect(normalizeEgyptPhone('0100 000 0002'), '1000000002');
    });

    test('validation accepts Egyptian mobiles only', () {
      expect(isValidEgyptPhone('01000000002'), isTrue);
      expect(isValidEgyptPhone('01512345678'), isTrue);
      expect(isValidEgyptPhone('12345'), isFalse);
      expect(isValidEgyptPhone('omar'), isFalse);
    });

    test('lookup keys are stable across written forms', () {
      expect(
        phoneLookupKey('01000000002'),
        phoneLookupKey('+201000000002'),
      );
      expect(usernameLookupKey('  Omar '), 'omar');
    });

    test('looksLikePhone distinguishes identifiers', () {
      expect(looksLikePhone('01000000002'), isTrue);
      expect(looksLikePhone('omar'), isFalse);
      expect(looksLikePhone('omar@test.com'), isFalse);
    });
  });

  group('week math', () {
    test('Thursday 2026-10-29 belongs to the week of Sunday 2026-10-25',
        () {
      final thursday = DateTime(2026, 10, 29);
      expect(weekKeyOf(thursday), '2026-10-25');
      final keys = weekDateKeys(thursday);
      expect(keys.length, 7);
      expect(keys.first, '2026-10-25');
      expect(keys.last, '2026-10-31');
    });

    test('Sunday is its own week start', () {
      expect(weekKeyOf(DateTime(2026, 10, 25)), '2026-10-25');
    });

    test('dateKey round-trips', () {
      expect(dateKey(parseDateKey('2026-10-29')), '2026-10-29');
    });
  });

  group('day salary', () {
    test('zero-order day earns no fixed pay', () {
      expect(
        computeDaySalary(
          ordersCount: 0,
          orderPrice: 9,
          dailyFixedPay: 705,
          distanceBonus: 0,
          manualBonus: 0,
          flatBonus: 0,
        ),
        0,
      );
    });

    test('counted day sums orders + fixed + bonuses', () {
      expect(
        computeDaySalary(
          ordersCount: 7,
          orderPrice: 9,
          dailyFixedPay: 705,
          distanceBonus: 0,
          manualBonus: 0,
          flatBonus: 35,
        ),
        803,
      );
    });
  });

  group('payoutWeek', () {
    DaySummary day(String key, double total,
        {double manual = 0, double distance = 0, double flat = 0}) {
      return DaySummary(
        uid: 'd1',
        dateKey: key,
        ordersCount: 1,
        totalKm: 10,
        salaryTotal: total,
        manualBonus: manual,
        distanceBonus: distance,
        flatBonus: flat,
      );
    }

    test('net = base + bonuses − deductions, week-scoped', () {
      final payout = payoutWeek(
        summaries: [day('2026-10-25', 800, flat: 35), day('2026-10-26', 750)],
        adjustments: [
          const Adjustment(
            id: 'a1',
            uid: 'd1',
            type: AdjustmentType.bonus,
            amount: 100,
            reason: 'manual',
            weekKey: '2026-10-25',
            createdBy: 'm1',
            createdAtMillis: 0,
          ),
          const Adjustment(
            id: 'a2',
            uid: 'd1',
            type: AdjustmentType.deduction,
            amount: 50,
            reason: 'late',
            weekKey: '2026-10-25',
            createdBy: 'm1',
            createdAtMillis: 0,
          ),
          const Adjustment(
            id: 'a3',
            uid: 'd1',
            type: AdjustmentType.bonus,
            amount: 999,
            reason: 'other week',
            weekKey: '2026-11-01',
            createdBy: 'm1',
            createdAtMillis: 0,
          ),
        ],
        weekKey: '2026-10-25',
      );
      expect(payout.base, 1550);
      expect(payout.bonus, 100);
      expect(payout.deduction, 50);
      expect(payout.net, 1600);
      expect(payout.totalBonus, 135);
    });

    test('adjustmentsForWeek filters by weekKey', () {
      final all = [
        const Adjustment(
          id: 'a1',
          uid: 'd1',
          type: AdjustmentType.bonus,
          amount: 10,
          reason: 'x',
          weekKey: '2026-10-25',
          createdBy: 'm1',
          createdAtMillis: 0,
        ),
        const Adjustment(
          id: 'a2',
          uid: 'd1',
          type: AdjustmentType.bonus,
          amount: 20,
          reason: 'x',
          weekKey: '2026-11-01',
          createdBy: 'm1',
          createdAtMillis: 0,
        ),
      ];
      expect(adjustmentsForWeek(all, '2026-10-25').length, 1);
    });
  });

  group('manager gate', () {
    const manager = ManagerAccount(
      uid: 'm1',
      email: 'm@test.com',
      username: 'admin',
      role: ManagerRole.manager,
    );
    const driver = ManagerAccount(
      uid: 'd1',
      email: 'd@test.com',
      username: 'omar',
    );

    test('manager passes, driver refused, blocked refused', () {
      expect(managerGate(manager), GateDecision.ok);
      expect(managerGate(driver), GateDecision.notManager);
      expect(
        managerGate(
          const ManagerAccount(
            uid: 'b1',
            email: 'b@test.com',
            username: 'blocked',
            blocked: true,
          ),
        ),
        GateDecision.blocked,
      );
      expect(
        managerGate(
          const ManagerAccount(
            uid: 'm2',
            email: 'm2@test.com',
            username: 'admin2',
            role: ManagerRole.manager,
            mustChangePassword: true,
          ),
        ),
        GateDecision.mustChangePassword,
      );
      expect(managerGate(null), GateDecision.noAccount);
    });

    test('team list hides blocked, block list shows only blocked', () {
      final users = [
        manager,
        driver,
        const ManagerAccount(
          uid: 'b1',
          email: 'b@test.com',
          username: 'blocked',
          blocked: true,
        ),
      ];
      expect(visibleTeamUsers(users).length, 2);
      expect(blockedUsers(users).length, 1);
      expect(blockedUsers(users).first.uid, 'b1');
    });
  });

  group('adjustment validation', () {
    test('reason required, amount positive', () {
      expect(
        validateAdjustment(amount: 0, reason: 'x'),
        isNotNull,
      );
      expect(
        validateAdjustment(amount: 50, reason: '  '),
        isNotNull,
      );
      expect(validateAdjustment(amount: 50, reason: 'good'), isNull);
    });
  });

  group('order records', () {
    test('entries array parses field-for-field', () {
      final record = DayOrderRecord.fromJson({
        'dateKey': '2026-10-29',
        'completedOrders': 1,
        'totalKm': 9.7,
        'entries': [
          {
            'id': 'ord-123456',
            'dateKey': '2026-10-29',
            'timestampMillis': 1000,
            'kmOut': 5.5,
            'kmBack': 4.2,
            'notes': 'شارع النيل',
            'status': 3,
            'pickupTimeMillis': 100,
            'deliveredTimeMillis': 200,
            'martArrivedTimeMillis': 300,
            'gpsKmOut': 5.5,
            'gpsKmBack': 0,
            'outgoingDurationSec': 600,
            'returnDurationSec': 480,
            'phone': '01000000009',
            'countOnly': false,
            'manualBonusEgp': 10,
            'createdAtMillis': 50,
          },
        ],
      });
      expect(record.hasEntries, isTrue);
      final order = record.entries.first;
      expect(order.effectiveKmOut, 5.5);
      expect(order.effectiveKmBack, 4.2);
      expect(order.isManualBack, isTrue);
      expect(order.isManualOut, isFalse);
      expect(order.statusLabelAr, 'مكتمل');
      expect(order.bonusInstantMillis, 50);
      expect(order.notes, 'شارع النيل');
    });

    test('count-only cloud shape keeps counts, no invented orders', () {
      final record = DayOrderRecord.fromJson({
        'dateKey': '2026-10-29',
        'completedOrders': 7,
        'totalKm': 31.4,
      });
      expect(record.hasEntries, isFalse);
      expect(record.entries, isEmpty);
      expect(record.completedOrders, 7);
      expect(record.totalKm, 31.4);
    });

    test('order entry round-trips through JSON', () {
      const order = OrderEntry(
        id: 'o1',
        dateKey: '2026-10-29',
        timestampMillis: 1000,
        kmOut: 3,
        kmBack: 2,
        notes: 'test',
        status: 3,
        manualBonusEgp: 5,
      );
      final back = OrderEntry.fromJson(order.toJson());
      expect(back.id, 'o1');
      expect(back.effectiveKmTotal, 5);
      expect(back.manualBonusEgp, 5);
    });
  });

  group('week rollup', () {
    test('rollup folds summaries + adjustments', () {
      final json = buildWeekRollupJson(
        uid: 'd1',
        weekKey: '2026-10-25',
        summaries: [
          buildDaySummary(
            uid: 'd1',
            dateKey: '2026-10-25',
            ordersCount: 7,
            totalKm: 31.4,
            orderPrice: 9,
            dailyFixedPay: 705,
            distanceBonus: 0,
            manualBonus: 0,
            flatBonus: 35,
          ),
        ],
        adjustments: [
          const Adjustment(
            id: 'a1',
            uid: 'd1',
            type: AdjustmentType.bonus,
            amount: 100,
            reason: 'x',
            weekKey: '2026-10-25',
            createdBy: 'm1',
            createdAtMillis: 0,
          ),
        ],
      );
      expect(json['salaryBase'], 803);
      expect(json['adjustmentsTotal'], 100);
      expect(json['salaryTotal'], 903);
      expect(json['ordersCount'], 7);
    });
  });
}
