// Pure data model + business logic for Delivery Management.
//
// Mirrors DeliveryFlow's cloud model field-for-field (same Firestore
// docs, same week conventions) so both apps read and write the same
// data without any migration:
//   users/{uid}                     — profile doc
//   users/{uid}/summaries/{dateKey} — one day summary per day
//   users/{uid}/orders/{dateKey}    — one day order record per day
//   users/{uid}/adjustments/{id}    — manager bonus/deduction docs
//   users/{uid}/weekRollups/{weekKey} — permanent weekly totals
//   usernames/{lower} / phones/{sha256} — login lookup docs
//
// No Firebase imports here: every function below is unit-testable
// without a backend.

import '../core/strings.dart';

/// Roles. `manager` is never self-assignable from a client: only an
/// existing manager (or a console edit for the very first manager)
// may set it. Firestore rules enforce the same server-side.
enum ManagerRole { driver, manager }

ManagerRole managerRoleFromString(String? value) {
  if (value == 'manager') return ManagerRole.manager;
  return ManagerRole.driver;
}

/// Payout methods (driver preference, stored on the profile).
/// `none` = the driver has not set a method yet.
enum PayoutMethod {
  none,
  instapay,
  vodafoneCash,
  manual;

  String get labelAr => switch (this) {
        PayoutMethod.none => 'غير محدد',
        PayoutMethod.instapay => 'InstaPay',
        PayoutMethod.vodafoneCash => 'فودافون كاش',
        PayoutMethod.manual => 'يدوي',
      };

  /// Localized label; [labelAr] is the Arabic-only wrapper.
  String labelFor(DmStrings s) => switch (this) {
        PayoutMethod.none => s.payoutNotSet,
        PayoutMethod.instapay => 'InstaPay',
        PayoutMethod.vodafoneCash => s.payoutVodafoneCash,
        PayoutMethod.manual => s.payoutManual,
      };
}

PayoutMethod payoutMethodFromString(String? value) {
  return switch (value) {
    'instapay' => PayoutMethod.instapay,
    'vodafoneCash' => PayoutMethod.vodafoneCash,
    'manual' => PayoutMethod.manual,
    _ => PayoutMethod.none,
  };
}

/// One account: Firebase Auth UID + profile fields from the user doc.
/// Passwords are NEVER stored here, in Firestore, or locally.
class ManagerAccount {
  const ManagerAccount({
    required this.uid,
    required this.email,
    required this.username,
    this.role = ManagerRole.driver,
    this.phone = '',
    this.mustChangePassword = false,
    this.blocked = false,
    this.blockedAt = 0,
    this.blockedBy = '',
    this.payoutMethod = PayoutMethod.none,
    this.payoutNumber = '',
    this.payoutName = '',
  });

  final String uid;
  final String email;
  final String username;
  final ManagerRole role;
  final String phone;
  final bool mustChangePassword;
  final bool blocked;
  final int blockedAt;
  final String blockedBy;
  final PayoutMethod payoutMethod;
  final String payoutNumber;
  final String payoutName;

  bool get isManager => role == ManagerRole.manager;
  String get displayName => username.isEmpty ? email : username;

  Map<String, dynamic> toJson() => {
        'email': email,
        'username': username,
        'role': role.name,
        'phone': phone,
        'mustChangePassword': mustChangePassword,
        'blocked': blocked,
        'blockedAt': blockedAt,
        'blockedBy': blockedBy,
        'payoutMethod': payoutMethod.name,
        'payoutNumber': payoutNumber,
        'payoutName': payoutName,
      };

  factory ManagerAccount.fromJson(String uid, Map<String, dynamic> json) {
    return ManagerAccount(
      uid: uid,
      email: (json['email'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      role: managerRoleFromString(json['role'] as String?),
      phone: (json['phone'] as String?) ?? '',
      mustChangePassword: (json['mustChangePassword'] as bool?) ?? false,
      blocked: (json['blocked'] as bool?) ?? false,
      blockedAt: (json['blockedAt'] as int?) ?? 0,
      blockedBy: (json['blockedBy'] as String?) ?? '',
      payoutMethod: payoutMethodFromString(json['payoutMethod'] as String?),
      payoutNumber: (json['payoutNumber'] as String?) ?? '',
      payoutName: (json['payoutName'] as String?) ?? '',
    );
  }
}

/// The manager-app login gate. Exactly one outcome applies.
enum GateDecision { ok, noAccount, notManager, blocked, mustChangePassword }

GateDecision managerGate(ManagerAccount? account) {
  if (account == null) return GateDecision.noAccount;
  if (account.blocked) return GateDecision.blocked;
  if (account.mustChangePassword) return GateDecision.mustChangePassword;
  if (!account.isManager) return GateDecision.notManager;
  return GateDecision.ok;
}

/// One day's summary (manager read path: one small doc per driver
/// per day, never a scan of raw orders).
class DaySummary {
  const DaySummary({
    required this.uid,
    required this.dateKey,
    required this.ordersCount,
    required this.totalKm,
    required this.salaryTotal,
    this.updatedAtMillis = 0,
    this.orderPrice = 0,
    this.dailyFixedPay = 0,
    this.distanceBonus = 0,
    this.manualBonus = 0,
    this.flatBonus = 0,
    this.editedByManagerUid = '',
    this.editedByManagerAtMillis = 0,
  });

  final String uid;
  final String dateKey;
  final int ordersCount;
  final double totalKm;
  final double salaryTotal;
  final int updatedAtMillis;
  final double orderPrice;
  final double dailyFixedPay;
  final double distanceBonus;
  final double manualBonus;
  final double flatBonus;
  final String editedByManagerUid;
  final int editedByManagerAtMillis;

  bool get editedByManager => editedByManagerUid.isNotEmpty;
  bool get hasBreakdown =>
      orderPrice > 0 ||
      dailyFixedPay > 0 ||
      distanceBonus > 0 ||
      manualBonus > 0 ||
      flatBonus > 0;

  DaySummary copyWith({
    int? ordersCount,
    double? totalKm,
    double? salaryTotal,
    int? updatedAtMillis,
    double? orderPrice,
    double? dailyFixedPay,
    double? distanceBonus,
    double? manualBonus,
    double? flatBonus,
    String? editedByManagerUid,
    int? editedByManagerAtMillis,
  }) {
    return DaySummary(
      uid: uid,
      dateKey: dateKey,
      ordersCount: ordersCount ?? this.ordersCount,
      totalKm: totalKm ?? this.totalKm,
      salaryTotal: salaryTotal ?? this.salaryTotal,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      orderPrice: orderPrice ?? this.orderPrice,
      dailyFixedPay: dailyFixedPay ?? this.dailyFixedPay,
      distanceBonus: distanceBonus ?? this.distanceBonus,
      manualBonus: manualBonus ?? this.manualBonus,
      flatBonus: flatBonus ?? this.flatBonus,
      editedByManagerUid: editedByManagerUid ?? this.editedByManagerUid,
      editedByManagerAtMillis:
          editedByManagerAtMillis ?? this.editedByManagerAtMillis,
    );
  }

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'ordersCount': ordersCount,
        'totalKm': totalKm,
        'salaryTotal': salaryTotal,
        'updatedAtMillis': updatedAtMillis,
        'orderPrice': orderPrice,
        'dailyFixedPay': dailyFixedPay,
        'distanceBonus': distanceBonus,
        'manualBonus': manualBonus,
        'flatBonus': flatBonus,
        'editedByManagerUid': editedByManagerUid,
        'editedByManagerAtMillis': editedByManagerAtMillis,
      };

  factory DaySummary.fromJson(String uid, Map<String, dynamic> json) {
    return DaySummary(
      uid: uid,
      dateKey: (json['dateKey'] as String?) ?? '',
      ordersCount: (json['ordersCount'] as int?) ?? 0,
      totalKm: (json['totalKm'] as num?)?.toDouble() ?? 0,
      salaryTotal: (json['salaryTotal'] as num?)?.toDouble() ?? 0,
      updatedAtMillis: (json['updatedAtMillis'] as int?) ?? 0,
      orderPrice: (json['orderPrice'] as num?)?.toDouble() ?? 0,
      dailyFixedPay: (json['dailyFixedPay'] as num?)?.toDouble() ?? 0,
      distanceBonus: (json['distanceBonus'] as num?)?.toDouble() ?? 0,
      manualBonus: (json['manualBonus'] as num?)?.toDouble() ?? 0,
      flatBonus: (json['flatBonus'] as num?)?.toDouble() ?? 0,
      editedByManagerUid: (json['editedByManagerUid'] as String?) ?? '',
      editedByManagerAtMillis:
          (json['editedByManagerAtMillis'] as int?) ?? 0,
    );
  }
}

/// One day's salary, mirroring DeliveryFlow's weekly formula for a
/// single day: orders × price + (1 paid day × fixed pay when the day
/// has at least one order) + distance + manual + flat bonuses.
double computeDaySalary({
  required int ordersCount,
  required double orderPrice,
  required double dailyFixedPay,
  required double distanceBonus,
  required double manualBonus,
  required double flatBonus,
}) {
  final paidDay = ordersCount >= 1 ? 1 : 0;
  return ordersCount * orderPrice +
      paidDay * dailyFixedPay +
      distanceBonus +
      manualBonus +
      flatBonus;
}

DaySummary buildDaySummary({
  required String uid,
  required String dateKey,
  required int ordersCount,
  required double totalKm,
  required double orderPrice,
  required double dailyFixedPay,
  required double distanceBonus,
  required double manualBonus,
  required double flatBonus,
  int updatedAtMillis = 0,
}) {
  return DaySummary(
    uid: uid,
    dateKey: dateKey,
    ordersCount: ordersCount,
    totalKm: totalKm,
    salaryTotal: computeDaySalary(
      ordersCount: ordersCount,
      orderPrice: orderPrice,
      dailyFixedPay: dailyFixedPay,
      distanceBonus: distanceBonus,
      manualBonus: manualBonus,
      flatBonus: flatBonus,
    ),
    updatedAtMillis: updatedAtMillis,
    orderPrice: orderPrice,
    dailyFixedPay: dailyFixedPay,
    distanceBonus: distanceBonus,
    manualBonus: manualBonus,
    flatBonus: flatBonus,
  );
}

enum AdjustmentType { bonus, deduction }

AdjustmentType adjustmentTypeFromString(String? value) {
  return switch (value) {
    'deduction' => AdjustmentType.deduction,
    _ => AdjustmentType.bonus,
  };
}

/// A manager-issued per-driver adjustment (bonus / deduction).
/// Amount is always POSITIVE; the sign comes from [type]. Reason is
/// REQUIRED. Stored under users/{uid}/adjustments/{id}.
class Adjustment {
  const Adjustment({
    required this.id,
    required this.uid,
    required this.type,
    required this.amount,
    required this.reason,
    required this.weekKey,
    required this.createdBy,
    required this.createdAtMillis,
  });

  final String id;
  final String uid;
  final AdjustmentType type;
  final double amount;
  final String reason;
  final String weekKey;
  final String createdBy;
  final int createdAtMillis;

  bool get isBonus => type == AdjustmentType.bonus;
  double get signedAmount => isBonus ? amount : -amount;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'amount': amount,
        'reason': reason,
        'weekKey': weekKey,
        'createdBy': createdBy,
        'createdAtMillis': createdAtMillis,
      };

  factory Adjustment.fromJson(
    String id,
    String uid,
    Map<String, dynamic> json,
  ) {
    return Adjustment(
      id: id,
      uid: uid,
      type: adjustmentTypeFromString(json['type'] as String?),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      reason: (json['reason'] as String?) ?? '',
      weekKey: (json['weekKey'] as String?) ?? '',
      createdBy: (json['createdBy'] as String?) ?? '',
      createdAtMillis: (json['createdAtMillis'] as int?) ?? 0,
    );
  }
}

/// Adjustments of [all] belonging to [weekKey].
List<Adjustment> adjustmentsForWeek(List<Adjustment> all, String weekKey) {
  return [for (final a in all) if (a.weekKey == weekKey) a];
}

/// Validation for the manager's add form. Reason is MANDATORY and
/// amount must be > 0. Returns null when valid, else an error.
String? validateAdjustment({required double? amount, required String reason}) {
  if (amount == null || amount <= 0) {
    return 'أدخل مبلغ أكبر من صفر.';
  }
  if (reason.trim().isEmpty) {
    return 'السبب مطلوب — السواق لازم يعرف ليه.';
  }
  return null;
}

/// One order, mirroring DeliveryFlow's OrderEntry field-for-field
/// (same JSON keys as the driver app writes). The manager app never
/// starts tracking; it only reads (and, for notes/phone/km/bonus,
/// edits) these fields.
class OrderEntry {
  const OrderEntry({
    required this.id,
    required this.dateKey,
    required this.timestampMillis,
    this.kmOut = 0,
    this.kmBack = 0,
    this.notes = '',
    this.status = 0,
    this.pickupTimeMillis,
    this.deliveredTimeMillis,
    this.martArrivedTimeMillis,
    this.gpsKmOut = 0,
    this.gpsKmBack = 0,
    this.outgoingDurationSec = 0,
    this.returnDurationSec = 0,
    this.routeOutLat = const [],
    this.routeOutLng = const [],
    this.routeBackLat = const [],
    this.routeBackLng = const [],
    this.roadOutLat = const [],
    this.roadOutLng = const [],
    this.roadBackLat = const [],
    this.roadBackLng = const [],
    this.phone = '',
    this.countOnly = false,
    this.manualBonusEgp = 0,
    this.createdAtMillis = 0,
  });

  final String id;
  final String dateKey;
  final int timestampMillis;
  final double kmOut;
  final double kmBack;
  final String notes;
  final int status;
  final int? pickupTimeMillis;
  final int? deliveredTimeMillis;
  final int? martArrivedTimeMillis;
  final double gpsKmOut;
  final double gpsKmBack;
  final int outgoingDurationSec;
  final int returnDurationSec;
  final List<double> routeOutLat;
  final List<double> routeOutLng;
  final List<double> routeBackLat;
  final List<double> routeBackLng;
  final List<double> roadOutLat;
  final List<double> roadOutLng;
  final List<double> roadBackLat;
  final List<double> roadBackLng;
  final String phone;
  final bool countOnly;
  final double manualBonusEgp;
  final int createdAtMillis;

  int get bonusInstantMillis =>
      createdAtMillis > 0 ? createdAtMillis : timestampMillis;
  double get kmTotal => kmOut + kmBack;
  double get effectiveKmOut => gpsKmOut > 0 ? gpsKmOut : kmOut;
  double get effectiveKmBack => gpsKmBack > 0 ? gpsKmBack : kmBack;
  double get effectiveKmTotal => effectiveKmOut + effectiveKmBack;
  bool get isManualOut => gpsKmOut == 0 && kmOut > 0;
  bool get isManualBack => gpsKmBack == 0 && kmBack > 0;
  bool get hasManualKm => isManualOut || isManualBack;
  bool get isPending => status == 0;
  bool get isToCustomer => status == 1;
  bool get isToMart => status == 2;
  bool get isCompleted => status == 3;
  bool get isTracking => status == 1 || status == 2;
  bool get hasRoute =>
      routeOutLat.isNotEmpty || routeBackLat.isNotEmpty;
  int get routePointCount => routeOutLat.length + routeBackLat.length;

  String get statusLabelAr => statusLabel(DmStrings.arabic);

  String statusLabel(DmStrings s) => s.orderStatusLabel(status);

  OrderEntry copyWith({
    double? kmOut,
    double? kmBack,
    String? notes,
    String? phone,
    double? manualBonusEgp,
    double? gpsKmOut,
    double? gpsKmBack,
  }) {
    return OrderEntry(
      id: id,
      dateKey: dateKey,
      timestampMillis: timestampMillis,
      kmOut: kmOut ?? this.kmOut,
      kmBack: kmBack ?? this.kmBack,
      notes: notes ?? this.notes,
      status: status,
      pickupTimeMillis: pickupTimeMillis,
      deliveredTimeMillis: deliveredTimeMillis,
      martArrivedTimeMillis: martArrivedTimeMillis,
      gpsKmOut: gpsKmOut ?? this.gpsKmOut,
      gpsKmBack: gpsKmBack ?? this.gpsKmBack,
      outgoingDurationSec: outgoingDurationSec,
      returnDurationSec: returnDurationSec,
      routeOutLat: routeOutLat,
      routeOutLng: routeOutLng,
      routeBackLat: routeBackLat,
      routeBackLng: routeBackLng,
      roadOutLat: roadOutLat,
      roadOutLng: roadOutLng,
      roadBackLat: roadBackLat,
      roadBackLng: roadBackLng,
      phone: phone ?? this.phone,
      countOnly: countOnly,
      manualBonusEgp: manualBonusEgp ?? this.manualBonusEgp,
      createdAtMillis: createdAtMillis,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateKey': dateKey,
        'timestampMillis': timestampMillis,
        'kmOut': kmOut,
        'kmBack': kmBack,
        'notes': notes,
        'status': status,
        'pickupTimeMillis': pickupTimeMillis,
        'deliveredTimeMillis': deliveredTimeMillis,
        'martArrivedTimeMillis': martArrivedTimeMillis,
        'gpsKmOut': gpsKmOut,
        'gpsKmBack': gpsKmBack,
        'outgoingDurationSec': outgoingDurationSec,
        'returnDurationSec': returnDurationSec,
        'routeOutLat': routeOutLat,
        'routeOutLng': routeOutLng,
        'routeBackLat': routeBackLat,
        'routeBackLng': routeBackLng,
        'roadOutLat': roadOutLat,
        'roadOutLng': roadOutLng,
        'roadBackLat': roadBackLat,
        'roadBackLng': roadBackLng,
        'phone': phone,
        'countOnly': countOnly,
        'manualBonusEgp': manualBonusEgp,
        'createdAtMillis': createdAtMillis,
      };

  static List<double> _doubles(dynamic v) {
    if (v is! List) return const [];
    return [for (final e in v) (e as num).toDouble()];
  }

  factory OrderEntry.fromJson(Map<String, dynamic> json) {
    return OrderEntry(
      id: (json['id'] as String?) ?? '',
      dateKey: (json['dateKey'] as String?) ?? '',
      timestampMillis: (json['timestampMillis'] as num?)?.toInt() ?? 0,
      kmOut: (json['kmOut'] as num?)?.toDouble() ?? 0,
      kmBack: (json['kmBack'] as num?)?.toDouble() ?? 0,
      notes: (json['notes'] as String?) ?? '',
      status: (json['status'] as num?)?.toInt() ?? 0,
      pickupTimeMillis: (json['pickupTimeMillis'] as num?)?.toInt(),
      deliveredTimeMillis: (json['deliveredTimeMillis'] as num?)?.toInt(),
      martArrivedTimeMillis:
          (json['martArrivedTimeMillis'] as num?)?.toInt(),
      gpsKmOut: (json['gpsKmOut'] as num?)?.toDouble() ?? 0,
      gpsKmBack: (json['gpsKmBack'] as num?)?.toDouble() ?? 0,
      outgoingDurationSec:
          (json['outgoingDurationSec'] as num?)?.toInt() ?? 0,
      returnDurationSec: (json['returnDurationSec'] as num?)?.toInt() ?? 0,
      routeOutLat: _doubles(json['routeOutLat']),
      routeOutLng: _doubles(json['routeOutLng']),
      routeBackLat: _doubles(json['routeBackLat']),
      routeBackLng: _doubles(json['routeBackLng']),
      roadOutLat: _doubles(json['roadOutLat']),
      roadOutLng: _doubles(json['roadOutLng']),
      roadBackLat: _doubles(json['roadBackLat']),
      roadBackLng: _doubles(json['roadBackLng']),
      phone: (json['phone'] as String?) ?? '',
      countOnly: (json['countOnly'] as bool?) ?? false,
      manualBonusEgp: (json['manualBonusEgp'] as num?)?.toDouble() ?? 0,
      createdAtMillis: (json['createdAtMillis'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One day's order record from users/{uid}/orders/{dateKey}.
///
/// HONEST DATA NOTE (v1): DeliveryFlow's cloud order docs today
/// carry only {dateKey, completedOrders, totalKm} — the per-order
/// entries live only on the driver's phone. This parser reads the
/// `entries` array when present (the exact shape the driver app
/// would upload), so the day→orders→order-detail screens light up
/// with full data as soon as the driver app uploads entries; until
/// then the manager sees the day count and totals, never invented
/// orders.
class DayOrderRecord {
  const DayOrderRecord({
    required this.dateKey,
    required this.completedOrders,
    required this.totalKm,
    required this.entries,
  });

  final String dateKey;
  final int completedOrders;
  final double totalKm;
  final List<OrderEntry> entries;

  bool get hasEntries => entries.isNotEmpty;

  factory DayOrderRecord.fromJson(Map<String, dynamic> json) {
    final raw = json['entries'];
    final entries = <OrderEntry>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) entries.add(OrderEntry.fromJson(e));
      }
    }
    final completed = (json['completedOrders'] as num?)?.toInt() ??
        entries.where((e) => e.isCompleted).length;
    final km = (json['totalKm'] as num?)?.toDouble() ??
        entries.fold<double>(0, (s, e) => s + e.effectiveKmTotal);
    return DayOrderRecord(
      dateKey: (json['dateKey'] as String?) ?? '',
      completedOrders: completed,
      totalKm: km,
      entries: entries,
    );
  }

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'completedOrders': completedOrders,
        'totalKm': totalKm,
        'entries': [for (final e in entries) e.toJson()],
      };
}

/// One dashboard row: a team member plus their summary for the day.
class DriverDayRow {
  const DriverDayRow({required this.account, this.summary});

  final ManagerAccount account;
  final DaySummary? summary;

  bool get synced => summary != null;
  int get orders => summary?.ordersCount ?? 0;
  double get km => summary?.totalKm ?? 0;
  double get salary => summary?.salaryTotal ?? 0;
}

List<DriverDayRow> buildDriverRows(
  List<ManagerAccount> users,
  List<DaySummary> summaries,
) {
  final byUid = {for (final s in summaries) s.uid: s};
  return [
    for (final user in users)
      DriverDayRow(account: user, summary: byUid[user.uid]),
  ];
}

/// Glanceable totals for the selected day. Sums synced rows only.
class DashboardKpis {
  const DashboardKpis({
    required this.driversActive,
    required this.totalOrders,
    required this.totalKm,
    required this.salaryDue,
  });

  final int driversActive;
  final int totalOrders;
  final double totalKm;
  final double salaryDue;
}

DashboardKpis computeKpis(List<DriverDayRow> rows) {
  var orders = 0;
  var km = 0.0;
  var salary = 0.0;
  var active = 0;
  for (final row in rows) {
    if (!row.synced) continue;
    active++;
    orders += row.orders;
    km += row.km;
    salary += row.salary;
  }
  return DashboardKpis(
    driversActive: active,
    totalOrders: orders,
    totalKm: km,
    salaryDue: salary,
  );
}

enum DriverSort { orders, salary, name }

List<DriverDayRow> filterDrivers(List<DriverDayRow> rows, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return rows;
  return [
    for (final row in rows)
      if (row.account.displayName.toLowerCase().contains(q)) row,
  ];
}

List<DriverDayRow> sortDrivers(List<DriverDayRow> rows, DriverSort sort) {
  final sorted = [...rows];
  switch (sort) {
    case DriverSort.orders:
      sorted.sort((a, b) {
        final c = b.orders.compareTo(a.orders);
        return c != 0
            ? c
            : a.account.displayName.compareTo(b.account.displayName);
      });
    case DriverSort.salary:
      sorted.sort((a, b) {
        final c = b.salary.compareTo(a.salary);
        return c != 0
            ? c
            : a.account.displayName.compareTo(b.account.displayName);
      });
    case DriverSort.name:
      sorted.sort(
        (a, b) => a.account.displayName.compareTo(b.account.displayName),
      );
  }
  return sorted;
}

class DashboardAlerts {
  const DashboardAlerts({required this.zeroOrders, required this.notSynced});

  final List<DriverDayRow> zeroOrders;
  final List<DriverDayRow> notSynced;
  bool get isEmpty => zeroOrders.isEmpty && notSynced.isEmpty;
}

DashboardAlerts findAlerts(List<DriverDayRow> rows) {
  return DashboardAlerts(
    zeroOrders: [
      for (final row in rows)
        if (row.synced && row.orders == 0) row,
    ],
    notSynced: [for (final row in rows) if (!row.synced) row],
  );
}

/// Orders per day for a week, in [weekDateKeys] order.
List<int> weekOrdersPerDay(
  Map<String, List<DaySummary>> weekSummaries,
  List<String> weekDateKeys,
) {
  return [
    for (final key in weekDateKeys)
      (weekSummaries[key] ?? []).fold<int>(
        0,
        (sum, s) => sum + s.ordersCount,
      ),
  ];
}

/// One driver's week money, computed the same way for the payroll
/// row and the payout detail, so the two can never disagree:
/// net = base + bonusAdjustments − deductionAdjustments, where base
/// = the week's day salaryTotals (day bonuses included).
class PayoutWeek {
  const PayoutWeek({
    required this.base,
    required this.dayBonus,
    required this.bonus,
    required this.deduction,
  });

  final double base;
  final double dayBonus;
  final double bonus;
  final double deduction;
  double get net => base + bonus - deduction;
  double get totalBonus => dayBonus + bonus;
}

PayoutWeek payoutWeek({
  required Iterable<DaySummary> summaries,
  required Iterable<Adjustment> adjustments,
  required String weekKey,
}) {
  var base = 0.0;
  var dayBonus = 0.0;
  for (final s in summaries) {
    base += s.salaryTotal;
    dayBonus += s.manualBonus + s.distanceBonus + s.flatBonus;
  }
  var bonus = 0.0;
  var deduction = 0.0;
  for (final a in adjustmentsForWeek(adjustments.toList(), weekKey)) {
    if (a.isBonus) {
      bonus += a.amount;
    } else {
      deduction += a.amount;
    }
  }
  return PayoutWeek(
    base: base,
    dayBonus: dayBonus,
    bonus: bonus,
    deduction: deduction,
  );
}

/// Team list rules: blocked members are never in the team list —
/// they live in the Block tab. Everyone else (drivers + managers)
/// is listed.
List<ManagerAccount> visibleTeamUsers(List<ManagerAccount> users) {
  return [for (final u in users) if (!u.blocked) u];
}

List<ManagerAccount> blockedUsers(List<ManagerAccount> users) {
  return [for (final u in users) if (u.blocked) u];
}

/// Permanent week rollup payload (users/{uid}/weekRollups/{weekKey}).
/// Refreshed best-effort after manager day/adjustment writes so the
/// permanent record never goes stale behind the live totals.
Map<String, dynamic> buildWeekRollupJson({
  required String uid,
  required String weekKey,
  required List<DaySummary> summaries,
  required List<Adjustment> adjustments,
}) {
  var orders = 0;
  var km = 0.0;
  var ordersAmount = 0.0;
  var fixedPay = 0.0;
  var distance = 0.0;
  var manual = 0.0;
  var flat = 0.0;
  var base = 0.0;
  for (final s in summaries) {
    orders += s.ordersCount;
    km += s.totalKm;
    ordersAmount += s.ordersCount * s.orderPrice;
    fixedPay += s.ordersCount >= 1 ? s.dailyFixedPay : 0;
    distance += s.distanceBonus;
    manual += s.manualBonus;
    flat += s.flatBonus;
    base += s.salaryTotal;
  }
  final weekAdjustments = adjustmentsForWeek(adjustments, weekKey);
  final adjTotal =
      weekAdjustments.fold<double>(0, (s, a) => s + a.signedAmount);
  return {
    'weekKey': weekKey,
    'ordersCount': orders,
    'totalKm': km,
    'ordersAmount': ordersAmount,
    'fixedPayAmount': fixedPay,
    'distanceBonus': distance,
    'manualBonus': manual,
    'flatBonus': flat,
    'salaryBase': base,
    'adjustmentsTotal': adjTotal,
    'salaryTotal': base + adjTotal,
    'adjustmentCount': weekAdjustments.length,
    'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
  };
}
