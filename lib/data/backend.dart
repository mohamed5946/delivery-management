// Data access for Delivery Management.
//
// Login/session reads are one-time `.get()` fetches. Manager
// screens sync LIVE via Firestore snapshot streams (watch*): while
// the app runs, every change lands instantly without manual
// refresh. DeliveryFlow's own pull-based design is untouched —
// this live layer exists only in this manager app. The
// [ManagerBackend] interface is what every screen talks to;
// [FirestoreManagerBackend] is the real one and
// [FakeManagerBackend] is the in-memory stand-in used by tests.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/diagnostics.dart';
import '../core/phone_utils.dart';
import '../core/week_utils.dart';
import 'firebase_options.dart';
import 'models.dart';

class BackendDenied implements Exception {
  const BackendDenied([this.message = 'غير مسموح']);
  final String message;
  @override
  String toString() => message;
}

class BackendBlocked implements Exception {
  const BackendBlocked([this.message = 'هذا الحساب محظور.']);
  final String message;
  @override
  String toString() => message;
}

class BackendNotManager implements Exception {
  const BackendNotManager([this.message = 'هذا التطبيق للمديرين فقط.']);
  final String message;
  @override
  String toString() => message;
}

class BackendNotConfigured implements Exception {
  const BackendNotConfigured();
  @override
  String toString() => 'لم يتم ربط Firebase بعد. سجّل تطبيق Android جديد في '
      'كونسول Firebase بنفس المشروع ثم الصق إعدادات Firebase '
      'في lib/data/firebase_options.dart.';
}

/// Backend used when Firebase never initialized (placeholders still
/// in firebase_options.dart, or initializeApp threw). It NEVER touches
/// Firebase: v1.0.0 froze on the Android launch splash exactly because
/// main() constructed FirestoreManagerBackend() — whose constructor
/// reads FirebaseAuth.instance — before runApp while no Firebase app
/// existed, so the constructor threw before any Flutter frame ever
/// rendered. main() must only construct the real backend after a
/// successful initializeApp, and use this one otherwise, so the app
/// always reaches a readable login screen.
class UnconfiguredBackend implements ManagerBackend {
  const UnconfiguredBackend();

  @override
  String? get currentUid => null;

  @override
  Future<String?> resolveEmail(String identifier) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<String> signInWithEmail(String email, String password) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<ManagerAccount?> loadAccount(String uid) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<List<ManagerAccount>> listUsers() async {
    throw const BackendNotConfigured();
  }

  @override
  Future<DaySummary?> fetchDaySummary(String uid, String dateKey) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<Map<String, List<DaySummary>>> listSummariesForDays(
    List<String> dateKeys,
  ) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<List<DaySummary>> listSummariesForUser(
    String uid,
    List<String> dateKeys,
  ) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<List<Adjustment>> listAdjustments(String uid) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<DayOrderRecord?> fetchOrderRecord(String uid, String dateKey) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<void> saveDaySummary(DaySummary summary, String managerUid) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<void> saveOrderRecord(
    String uid,
    String dateKey,
    DayOrderRecord record,
    String managerUid,
  ) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<Adjustment> addAdjustment(
    Adjustment adjustment,
    String managerUid,
  ) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<void> deleteAdjustment(String uid, String adjustmentId) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<void> setRole(String uid, ManagerRole role, String managerUid) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<void> setBlocked(String uid, bool blocked, String managerUid) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<void> sendDriverPasswordReset(
      String uid, String managerUid) async {
    throw const BackendNotConfigured();
  }

  @override
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    throw const BackendNotConfigured();
  }

  @override
  Stream<List<ManagerAccount>> watchUsers() {
    return Stream.error(const BackendNotConfigured());
  }

  @override
  Stream<List<DaySummary>> watchSummariesForUser(
    String uid,
    List<String> dateKeys,
  ) {
    return Stream.error(const BackendNotConfigured());
  }

  @override
  Stream<List<Adjustment>> watchAdjustments(String uid) {
    return Stream.error(const BackendNotConfigured());
  }

  @override
  Stream<DayOrderRecord?> watchOrderRecord(String uid, String dateKey) {
    return Stream.error(const BackendNotConfigured());
  }

  @override
  Stream<ManagerAccount?> watchAccount(String uid) {
    return Stream.error(const BackendNotConfigured());
  }
}

class BackendAuthFailed implements Exception {
  const BackendAuthFailed([this.message = 'بيانات الدخول غير صحيحة.']);
  final String message;
  @override
  String toString() => message;
}

/// Everything the app needs from a backend. UIDs, doc ids and field
/// names match DeliveryFlow exactly.
abstract class ManagerBackend {
  String? get currentUid;

  /// Resolves a username OR phone OR email to the Auth email, via
  /// the same lookup docs DeliveryFlow writes. Returns null when
  /// no account matches.
  Future<String?> resolveEmail(String identifier);

  /// Signs in with an Auth email + password. Returns the UID.
  Future<String> signInWithEmail(String email, String password);

  Future<void> signOut();

  /// Loads a profile doc. Null when the doc does not exist.
  Future<ManagerAccount?> loadAccount(String uid);

  /// All user docs. Manager-only by Firestore rules.
  Future<List<ManagerAccount>> listUsers();

  Future<DaySummary?> fetchDaySummary(String uid, String dateKey);

  /// Summaries for the given days, grouped by dateKey. Manager-only.
  Future<Map<String, List<DaySummary>>> listSummariesForDays(
    List<String> dateKeys,
  );

  Future<List<DaySummary>> listSummariesForUser(
    String uid,
    List<String> dateKeys,
  );

  Future<List<Adjustment>> listAdjustments(String uid);

  Future<DayOrderRecord?> fetchOrderRecord(String uid, String dateKey);

  /// Manager edit of a day's components. Recomputes the day total,
  /// stamps the manager edit, stamps the 21-day detail expiry, and
  /// refreshes the week's permanent rollup best-effort.
  Future<void> saveDaySummary(DaySummary summary, String managerUid);

  /// Manager edit of one order inside a day record (notes/phone/km/
  /// bonus). Rewrites the day's order doc; never invents entries.
  Future<void> saveOrderRecord(
    String uid,
    String dateKey,
    DayOrderRecord record,
    String managerUid,
  );

  /// Adds a manager adjustment (bonus/deduction, reason required).
  /// Managers cannot adjust their own pay.
  Future<Adjustment> addAdjustment(Adjustment adjustment, String managerUid);

  Future<void> deleteAdjustment(String uid, String adjustmentId);

  /// Promote/demote. Never self (rules + this guard enforce it).
  Future<void> setRole(String uid, ManagerRole role, String managerUid);

  /// Block / unblock. Never self. Data is always kept.
  Future<void> setBlocked(String uid, bool blocked, String managerUid);

  /// Manager-initiated password reset for a DRIVER: sends a
  /// reset-link email to the driver's email on file via the Auth
  /// client SDK. No backend, no rules changes. Never self, never
  /// another manager (callers + implementations enforce it).
  /// Throws when the driver has no email on file. Sends nothing
  /// and reveals nothing about any password: the reset-link flow
  /// is the entire feature — passwords are never displayed,
  /// stored, logged, or transmitted by this app.
  Future<void> sendDriverPasswordReset(String uid, String managerUid);

  /// Password change for the signed-in manager. Uses the Auth user's
  /// own email for re-authentication (never a profile field that a
  /// console-created doc might lack) and clears the
  /// mustChangePassword flag on success.
  Future<void> changePassword(String currentPassword, String newPassword);

  // ── LIVE streams (manager app ONLY) ──────────────────────────
  // DeliveryFlow stays pull-based (.get()); THIS app syncs live
  // while it runs: Firestore snapshot listeners push every change
  // (new driver, day total, order, bonus/deduction, block, payout
  // prefs) to the screens the moment it lands — no manual refresh.
  // Screens attach on initState and cancel on dispose (and the
  // shell unmounts on sign-out, cancelling everything). Listener
  // errors surface to the screen as a plain-language message, never
  // a silent stale screen. Closed-app push (FCM) is NOT in scope.

  /// All user docs, live.
  Stream<List<ManagerAccount>> watchUsers();

  /// One user's summaries for the given days, live. There is
  /// deliberately NO cross-user summaries stream: a
  /// collectionGroup('summaries') query is denied with
  /// PERMISSION_DENIED for a manager under the published rules
  /// (field-proven 2026-10-29), while per-user subcollection reads
  /// are allowed — so screens attach one listener per user.
  Stream<List<DaySummary>> watchSummariesForUser(
    String uid,
    List<String> dateKeys,
  );

  /// One user's adjustments, live.
  Stream<List<Adjustment>> watchAdjustments(String uid);

  /// One user's day order record, live (null when none exists).
  Stream<DayOrderRecord?> watchOrderRecord(String uid, String dateKey);

  /// One profile doc, live (null when it does not exist).
  Stream<ManagerAccount?> watchAccount(String uid);
}

/// Detail docs expire 21 days after their date (same retention rule
/// as DeliveryFlow v27.35).
DateTime detailExpireAtDate(String dateKey) {
  return addDays(parseDateKey(dateKey), 21);
}

class FirestoreManagerBackend implements ManagerBackend {
  FirestoreManagerBackend({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  void _requireConfigured() {
    if (!DefaultFirebaseOptions.isConfigured) {
      throw const BackendNotConfigured();
    }
  }

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> _summaries(String uid) =>
      _users.doc(uid).collection('summaries');

  CollectionReference<Map<String, dynamic>> _adjustments(String uid) =>
      _users.doc(uid).collection('adjustments');

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<String?> resolveEmail(String identifier) async {
    _requireConfigured();
    final trimmed = identifier.trim();
    try {
      if (trimmed.contains('@')) return trimmed;
      if (looksLikePhone(trimmed)) {
        final snap = await _firestore
            .collection('phones')
            .doc(phoneLookupKey(trimmed))
            .get();
        return snap.data()?['email'] as String?;
      }
      final snap = await _firestore
          .collection('usernames')
          .doc(usernameLookupKey(trimmed))
          .get();
      return snap.data()?['email'] as String?;
    } catch (e) {
      diagnosticsLog.add('auth', 'resolveEmail failed: $e');
      rethrow;
    }
  }

  @override
  Future<String> signInWithEmail(String email, String password) async {
    _requireConfigured();
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) throw const BackendAuthFailed();
      return uid;
    } on FirebaseAuthException catch (e) {
      diagnosticsLog.add('auth', 'signIn failed: ${e.code}');
      throw const BackendAuthFailed();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      diagnosticsLog.add('auth', 'signOut failed: $e');
      rethrow;
    }
  }

  @override
  Future<ManagerAccount?> loadAccount(String uid) async {
    _requireConfigured();
    final snap = await _users.doc(uid).get();
    final data = snap.data();
    if (data == null) return null;
    return ManagerAccount.fromJson(uid, data);
  }

  @override
  Future<List<ManagerAccount>> listUsers() async {
    _requireConfigured();
    final snap = await _users.get();
    return [
      for (final doc in snap.docs) ManagerAccount.fromJson(doc.id, doc.data()),
    ];
  }

  @override
  Future<DaySummary?> fetchDaySummary(String uid, String dateKey) async {
    _requireConfigured();
    final snap = await _summaries(uid).doc(dateKey).get();
    final data = snap.data();
    if (data == null) return null;
    return DaySummary.fromJson(uid, data);
  }

  @override
  Future<Map<String, List<DaySummary>>> listSummariesForDays(
    List<String> dateKeys,
  ) async {
    _requireConfigured();
    final users = await listUsers();
    final out = {for (final d in dateKeys) d: <DaySummary>[]};
    for (final user in users) {
      for (final dateKey in dateKeys) {
        final summary = await fetchDaySummary(user.uid, dateKey);
        if (summary != null) out[dateKey]!.add(summary);
      }
    }
    return out;
  }

  @override
  Future<List<DaySummary>> listSummariesForUser(
    String uid,
    List<String> dateKeys,
  ) async {
    _requireConfigured();
    final out = <DaySummary>[];
    for (final dateKey in dateKeys) {
      final summary = await fetchDaySummary(uid, dateKey);
      if (summary != null) out.add(summary);
    }
    return out;
  }

  @override
  Future<List<Adjustment>> listAdjustments(String uid) async {
    _requireConfigured();
    final snap = await _adjustments(uid).get();
    return [
      for (final doc in snap.docs) Adjustment.fromJson(doc.id, uid, doc.data()),
    ];
  }

  @override
  Future<DayOrderRecord?> fetchOrderRecord(
    String uid,
    String dateKey,
  ) async {
    _requireConfigured();
    final snap = await _users.doc(uid).collection('orders').doc(dateKey).get();
    final data = snap.data();
    if (data == null) return null;
    return DayOrderRecord.fromJson(data);
  }

  Future<void> _refreshRollupBestEffort(String uid, String weekKey) async {
    try {
      final keys = weekDateKeys(parseDateKey(weekKey));
      final summaries = await listSummariesForUser(uid, keys);
      final adjustments = await listAdjustments(uid);
      await _users.doc(uid).collection('weekRollups').doc(weekKey).set(
            buildWeekRollupJson(
              uid: uid,
              weekKey: weekKey,
              summaries: summaries,
              adjustments: adjustments,
            ),
          );
    } catch (e) {
      // Best-effort only: a stale rollup is repaired by DeliveryFlow's
      // own sign-in backfill; the manager edit itself must not fail.
      diagnosticsLog.add('rollup', 'refresh failed for $uid/$weekKey: $e');
    }
  }

  @override
  Future<void> saveDaySummary(DaySummary summary, String managerUid) async {
    _requireConfigured();
    final at = DateTime.now().millisecondsSinceEpoch;
    final stamped = summary.copyWith(
      editedByManagerUid: managerUid,
      editedByManagerAtMillis: at,
      updatedAtMillis: at,
    );
    final data = stamped.toJson()
      ..['expireAt'] = Timestamp.fromDate(detailExpireAtDate(summary.dateKey));
    await _summaries(summary.uid).doc(summary.dateKey).set(data);
    await _refreshRollupBestEffort(
      summary.uid,
      weekKeyOf(parseDateKey(summary.dateKey)),
    );
  }

  @override
  Future<void> saveOrderRecord(
    String uid,
    String dateKey,
    DayOrderRecord record,
    String managerUid,
  ) async {
    _requireConfigured();
    final data = record.toJson()
      ..['expireAt'] = Timestamp.fromDate(detailExpireAtDate(dateKey))
      ..['editedByManagerUid'] = managerUid
      ..['editedByManagerAtMillis'] = DateTime.now().millisecondsSinceEpoch;
    await _users.doc(uid).collection('orders').doc(dateKey).set(data);
  }

  @override
  Future<Adjustment> addAdjustment(
    Adjustment adjustment,
    String managerUid,
  ) async {
    _requireConfigured();
    if (managerUid == adjustment.uid) {
      throw const BackendDenied('لا يمكن للمدير تعديل أجره بنفسه.');
    }
    final error = validateAdjustment(
      amount: adjustment.amount,
      reason: adjustment.reason,
    );
    if (error != null) throw BackendDenied(error);
    final ref = adjustment.id.isEmpty
        ? _adjustments(adjustment.uid).doc()
        : _adjustments(adjustment.uid).doc(adjustment.id);
    final data = adjustment.toJson()
      ..['createdBy'] = managerUid
      ..['expireAt'] = Timestamp.fromDate(
        addDays(parseDateKey(adjustment.weekKey), 21),
      );
    await ref.set(data);
    final saved = Adjustment.fromJson(ref.id, adjustment.uid, data);
    await _refreshRollupBestEffort(adjustment.uid, adjustment.weekKey);
    return saved;
  }

  @override
  Future<void> deleteAdjustment(String uid, String adjustmentId) async {
    _requireConfigured();
    String? weekKey;
    try {
      final snap = await _adjustments(uid).doc(adjustmentId).get();
      weekKey = snap.data()?['weekKey'] as String?;
    } catch (_) {}
    await _adjustments(uid).doc(adjustmentId).delete();
    if (weekKey != null && weekKey.isNotEmpty) {
      await _refreshRollupBestEffort(uid, weekKey);
    }
  }

  @override
  Future<void> setRole(
    String uid,
    ManagerRole role,
    String managerUid,
  ) async {
    _requireConfigured();
    if (uid == managerUid) {
      throw const BackendDenied('لا يمكن تغيير دور حسابك بنفسك.');
    }
    await _users.doc(uid).update({'role': role.name});
  }

  @override
  Future<void> setBlocked(
    String uid,
    bool blocked,
    String managerUid,
  ) async {
    _requireConfigured();
    if (uid == managerUid) {
      throw const BackendDenied('لا يمكن حظر حسابك بنفسك.');
    }
    await _users.doc(uid).update({
      'blocked': blocked,
      'blockedAt': blocked ? DateTime.now().millisecondsSinceEpoch : 0,
      'blockedBy': blocked ? managerUid : '',
    });
  }

  @override
  @override
  Future<void> sendDriverPasswordReset(
      String uid, String managerUid) async {
    _requireConfigured();
    if (uid == managerUid) {
      throw const BackendDenied('لا يمكن إرسال إعادة تعيين لحسابك بنفسك.');
    }
    final doc = await _users.doc(uid).get();
    final data = doc.data();
    if (data == null) {
      throw const BackendDenied('لا يوجد ملف حساب لهذا المستخدم.');
    }
    final account = ManagerAccount.fromJson(doc.id, data);
    if (account.isManager) {
      throw const BackendDenied('إعادة التعيين للسواقين بس — مش للمديرين.');
    }
    final email = account.email.trim();
    if (email.isEmpty) {
      throw const BackendDenied('مفيش إيميل مسجل للسواق ده.');
    }
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    _requireConfigured();
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw const BackendDenied('لا توجد جلسة دخول حالية.');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      await _users.doc(user.uid).update({'mustChangePassword': false});
    } on FirebaseAuthException catch (e) {
      diagnosticsLog.add('auth', 'changePassword failed: ${e.code}');
      throw const BackendAuthFailed('كلمة المرور الحالية غير صحيحة.');
    }
  }

  // ── LIVE streams ─────────────────────────────────────────────

  @override
  Stream<List<ManagerAccount>> watchUsers() {
    _requireConfigured();
    return _users.snapshots().map(
          (snap) => [
            for (final doc in snap.docs)
              ManagerAccount.fromJson(doc.id, doc.data()),
          ],
        );
  }

  @override
  Stream<List<DaySummary>> watchSummariesForUser(
    String uid,
    List<String> dateKeys,
  ) {
    _requireConfigured();
    if (dateKeys.isEmpty) return Stream.value(const []);
    return _summaries(uid).where('dateKey', whereIn: dateKeys).snapshots().map(
          (snap) => [
            for (final doc in snap.docs) DaySummary.fromJson(uid, doc.data()),
          ],
        );
  }

  @override
  Stream<List<Adjustment>> watchAdjustments(String uid) {
    _requireConfigured();
    return _adjustments(uid).snapshots().map(
          (snap) => [
            for (final doc in snap.docs)
              Adjustment.fromJson(doc.id, uid, doc.data()),
          ],
        );
  }

  @override
  Stream<DayOrderRecord?> watchOrderRecord(String uid, String dateKey) {
    _requireConfigured();
    return _users
        .doc(uid)
        .collection('orders')
        .doc(dateKey)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return DayOrderRecord.fromJson(data);
    });
  }

  @override
  Stream<ManagerAccount?> watchAccount(String uid) {
    _requireConfigured();
    return _users.doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return ManagerAccount.fromJson(uid, data);
    });
  }
}

/// In-memory backend for tests. Seeds accounts, summaries,
/// adjustments and order records; enforces the same guards as the
/// real backend (manager-only team reads, no self role/block, no
/// self adjustment). Mutations re-emit every live stream, so tests
/// can assert live updates without Firestore.
class FakeManagerBackend implements ManagerBackend {
  FakeManagerBackend({
    required List<ManagerAccount> accounts,
    Map<String, String> passwordsByEmail = const {},
    Map<String, List<DaySummary>> summaries = const {},
    Map<String, List<Adjustment>> adjustments = const {},
    Map<String, Map<String, DayOrderRecord>> orderRecords = const {},
  })  : _accounts = {for (final a in accounts) a.uid: a},
        _passwordsByEmail = Map.of(passwordsByEmail),
        _summaries = {
          for (final e in summaries.entries) e.key: List.of(e.value),
        },
        _adjustments = {
          for (final e in adjustments.entries) e.key: List.of(e.value),
        },
        _orderRecords = {
          for (final e in orderRecords.entries) e.key: Map.of(e.value),
        };

  final Map<String, ManagerAccount> _accounts;
  final Map<String, String> _passwordsByEmail;
  final Map<String, List<DaySummary>> _summaries;
  final Map<String, List<Adjustment>> _adjustments;
  final Map<String, Map<String, DayOrderRecord>> _orderRecords;
  String? _uid;

  /// Test seam: when set, per-user summaries streams fail with this
  /// error (drives the listener-error fallback tests).
  Object? summariesStreamError;

  // ── Live-feed machinery ──────────────────────────────────────
  final _liveFeeds = <_LiveFeed>[];

  void _registerFeed(
    StreamController<dynamic> controller,
    Object? Function() snapshot,
  ) {
    final feed = _LiveFeed(controller, snapshot);
    _liveFeeds.add(feed);
    controller.onListen = () {
      scheduleMicrotask(() {
        if (!controller.isClosed) controller.add(snapshot());
      });
    };
    controller.onCancel = () {
      _liveFeeds.remove(feed);
    };
  }

  void _emitLive() {
    for (final feed in List.of(_liveFeeds)) {
      if (!feed.controller.isClosed) {
        feed.controller.add(feed.snapshot());
      }
    }
  }

  Stream<T> _liveStream<T>(T Function() snapshot) {
    final controller = StreamController<T>();
    _registerFeed(
      controller as StreamController<dynamic>,
      () => snapshot() as Object?,
    );
    return controller.stream;
  }

  void _requireSignedIn() {
    if (_uid == null) throw const BackendDenied('غير مسجل دخول.');
  }

  ManagerAccount _me() {
    _requireSignedIn();
    return _accounts[_uid]!;
  }

  @override
  String? get currentUid => _uid;

  @override
  Future<String?> resolveEmail(String identifier) async {
    final trimmed = identifier.trim();
    if (trimmed.contains('@')) {
      return _accounts.values
              .any((a) => a.email.toLowerCase() == trimmed.toLowerCase())
          ? trimmed
          : null;
    }
    if (looksLikePhone(trimmed)) {
      final normalized = normalizeEgyptPhone(trimmed);
      for (final a in _accounts.values) {
        if (a.phone.isNotEmpty && normalizeEgyptPhone(a.phone) == normalized) {
          return a.email;
        }
      }
      return null;
    }
    final key = usernameLookupKey(trimmed);
    for (final a in _accounts.values) {
      if (a.username.toLowerCase() == key) return a.email;
    }
    return null;
  }

  @override
  Future<String> signInWithEmail(String email, String password) async {
    final account = _accounts.values.where(
      (a) => a.email.toLowerCase() == email.toLowerCase(),
    );
    if (account.isEmpty) throw const BackendAuthFailed();
    final found = account.first;
    if (_passwordsByEmail[found.email] != password) {
      throw const BackendAuthFailed();
    }
    _uid = found.uid;
    return found.uid;
  }

  @override
  Future<void> signOut() async {
    _uid = null;
  }

  @override
  Future<ManagerAccount?> loadAccount(String uid) async => _accounts[uid];

  @override
  Future<List<ManagerAccount>> listUsers() async {
    if (!_me().isManager) throw const BackendDenied('manager only');
    return _accounts.values.toList();
  }

  @override
  Future<DaySummary?> fetchDaySummary(String uid, String dateKey) async {
    final list = _summaries[uid] ?? const [];
    for (final s in list) {
      if (s.dateKey == dateKey) return s;
    }
    return null;
  }

  @override
  Future<Map<String, List<DaySummary>>> listSummariesForDays(
    List<String> dateKeys,
  ) async {
    final out = {for (final d in dateKeys) d: <DaySummary>[]};
    for (final uid in _summaries.keys) {
      for (final s in _summaries[uid]!) {
        if (out.containsKey(s.dateKey)) out[s.dateKey]!.add(s);
      }
    }
    return out;
  }

  @override
  Future<List<DaySummary>> listSummariesForUser(
    String uid,
    List<String> dateKeys,
  ) async {
    return [
      for (final s in _summaries[uid] ?? const [])
        if (dateKeys.contains(s.dateKey)) s,
    ];
  }

  @override
  Future<List<Adjustment>> listAdjustments(String uid) async {
    return List.of(_adjustments[uid] ?? const []);
  }

  @override
  Future<DayOrderRecord?> fetchOrderRecord(
    String uid,
    String dateKey,
  ) async =>
      _orderRecords[uid]?[dateKey];

  @override
  Future<void> saveDaySummary(DaySummary summary, String managerUid) async {
    final list = _summaries.putIfAbsent(summary.uid, () => []);
    list.removeWhere((s) => s.dateKey == summary.dateKey);
    list.add(summary.copyWith(
      editedByManagerUid: managerUid,
      editedByManagerAtMillis: DateTime.now().millisecondsSinceEpoch,
    ));
    _emitLive();
  }

  @override
  Future<void> saveOrderRecord(
    String uid,
    String dateKey,
    DayOrderRecord record,
    String managerUid,
  ) async {
    _orderRecords.putIfAbsent(uid, () => {})[dateKey] = record;
    _emitLive();
  }

  @override
  Future<Adjustment> addAdjustment(
    Adjustment adjustment,
    String managerUid,
  ) async {
    if (managerUid == adjustment.uid) {
      throw const BackendDenied('لا يمكن للمدير تعديل أجره بنفسه.');
    }
    final error = validateAdjustment(
      amount: adjustment.amount,
      reason: adjustment.reason,
    );
    if (error != null) throw BackendDenied(error);
    final saved = Adjustment(
      id: adjustment.id.isEmpty
          ? 'adj-${DateTime.now().millisecondsSinceEpoch}'
          : adjustment.id,
      uid: adjustment.uid,
      type: adjustment.type,
      amount: adjustment.amount,
      reason: adjustment.reason,
      weekKey: adjustment.weekKey,
      createdBy: managerUid,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    _adjustments.putIfAbsent(adjustment.uid, () => []).add(saved);
    _emitLive();
    return saved;
  }

  @override
  Future<void> deleteAdjustment(String uid, String adjustmentId) async {
    _adjustments[uid]?.removeWhere((a) => a.id == adjustmentId);
    _emitLive();
  }

  @override
  Future<void> setRole(
    String uid,
    ManagerRole role,
    String managerUid,
  ) async {
    if (uid == managerUid) {
      throw const BackendDenied('لا يمكن تغيير دور حسابك بنفسك.');
    }
    final old = _accounts[uid];
    if (old == null) return;
    _accounts[uid] = ManagerAccount(
      uid: old.uid,
      email: old.email,
      username: old.username,
      role: role,
      phone: old.phone,
      mustChangePassword: old.mustChangePassword,
      blocked: old.blocked,
      blockedAt: old.blockedAt,
      blockedBy: old.blockedBy,
      payoutMethod: old.payoutMethod,
      payoutNumber: old.payoutNumber,
      payoutName: old.payoutName,
    );
    _emitLive();
  }

  @override
  Future<void> setBlocked(
    String uid,
    bool blocked,
    String managerUid,
  ) async {
    if (uid == managerUid) {
      throw const BackendDenied('لا يمكن حظر حسابك بنفسك.');
    }
    final old = _accounts[uid];
    if (old == null) return;
    _accounts[uid] = ManagerAccount(
      uid: old.uid,
      email: old.email,
      username: old.username,
      role: old.role,
      phone: old.phone,
      mustChangePassword: old.mustChangePassword,
      blocked: blocked,
      blockedAt: blocked ? DateTime.now().millisecondsSinceEpoch : 0,
      blockedBy: blocked ? managerUid : '',
      payoutMethod: old.payoutMethod,
      payoutNumber: old.payoutNumber,
      payoutName: old.payoutName,
    );
    _emitLive();
  }

  @override
  Future<void> sendDriverPasswordReset(
      String uid, String managerUid) async {
    if (uid == managerUid) {
      throw const BackendDenied('لا يمكن إرسال إعادة تعيين لحسابك بنفسك.');
    }
    final target = _accounts[uid];
    if (target == null) return;
    if (target.isManager) {
      throw const BackendDenied('إعادة التعيين للسواقين بس — مش للمديرين.');
    }
    if (target.email.trim().isEmpty) {
      throw const BackendDenied('مفيش إيميل مسجل للسواق ده.');
    }
    if (sendResetError != null) throw sendResetError!;
    resetEmailsSent.add(target.email);
  }

  /// Test seam: reset-link emails "sent" by [sendDriverPasswordReset]
  /// (recipient emails, in order). No real email is ever sent, and
  /// no link or code is ever recorded.
  final resetEmailsSent = <String>[];

  /// Test seam: when set, [sendDriverPasswordReset] throws this.
  Object? sendResetError;

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final me = _me();
    if (_passwordsByEmail[me.email] != currentPassword) {
      throw const BackendAuthFailed('كلمة المرور الحالية غير صحيحة.');
    }
    _passwordsByEmail[me.email] = newPassword;
    if (me.mustChangePassword) {
      _accounts[me.uid] = ManagerAccount(
        uid: me.uid,
        email: me.email,
        username: me.username,
        role: me.role,
        phone: me.phone,
        mustChangePassword: false,
        blocked: me.blocked,
        blockedAt: me.blockedAt,
        blockedBy: me.blockedBy,
        payoutMethod: me.payoutMethod,
        payoutNumber: me.payoutNumber,
        payoutName: me.payoutName,
      );
    }
    _emitLive();
  }

  // ── LIVE streams (fake) ──────────────────────────────────────

  @override
  Stream<List<ManagerAccount>> watchUsers() {
    if (_uid == null || !_accounts[_uid]!.isManager) {
      return Stream.error(const BackendDenied('manager only'));
    }
    return _liveStream(() => _accounts.values.toList());
  }

  @override
  Stream<List<DaySummary>> watchSummariesForUser(
    String uid,
    List<String> dateKeys,
  ) {
    // Test seam: when set, per-user summaries streams fail with this
    // error (drives the listener-error fallback tests).
    if (summariesStreamError != null) {
      return Stream.error(summariesStreamError!);
    }
    return _liveStream(() => [
          for (final s in _summaries[uid] ?? const [])
            if (dateKeys.contains(s.dateKey)) s,
        ]);
  }

  @override
  Stream<List<Adjustment>> watchAdjustments(String uid) {
    return _liveStream(() => List.of(_adjustments[uid] ?? const []));
  }

  @override
  Stream<DayOrderRecord?> watchOrderRecord(String uid, String dateKey) {
    return _liveStream(() => _orderRecords[uid]?[dateKey]);
  }

  @override
  Stream<ManagerAccount?> watchAccount(String uid) {
    return _liveStream(() => _accounts[uid]);
  }
}

class _LiveFeed {
  const _LiveFeed(this.controller, this.snapshot);

  final StreamController<dynamic> controller;
  final Object? Function() snapshot;
}
