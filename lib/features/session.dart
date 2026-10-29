// Session + login gate for Delivery Management.
//
// Flow: restore a persisted Auth session on start (closing the app
// never logs out) → load the profile → apply the manager gate:
//   blocked            → signed out + blocked message
//   mustChangePassword → forced-change notice (the change itself
//                        happens in DeliveryFlow in v1; this app
//                        has no password-change screen for a
//                        flagged account yet — the Application tab
//                        change-password form serves unflagged
//                        managers)
//   not a manager      → signed out + "managers only" message
//   manager            → the 4-tab shell
// Sign-out is always explicit + confirmed (Application tab).
// There is NO sign-up screen and NO invite gate in v1: accounts
// are created in DeliveryFlow and promoted to manager there.

import 'package:flutter/foundation.dart';

import '../core/diagnostics.dart';
import '../data/backend.dart';
import '../data/models.dart';

enum SessionStatus {
  loading,
  signedOut,
  denied,
  blocked,
  mustChangePassword,
  ready,
}

class SessionController extends ChangeNotifier {
  SessionController(this._backend);

  final ManagerBackend _backend;
  SessionStatus status = SessionStatus.loading;
  ManagerAccount? account;
  String message = '';

  ManagerBackend get backend => _backend;

  Future<void> restore() async {
    status = SessionStatus.loading;
    message = '';
    notifyListeners();
    try {
      final uid = _backend.currentUid;
      if (uid == null) {
        status = SessionStatus.signedOut;
        notifyListeners();
        return;
      }
      await _enter(uid);
    } catch (e) {
      diagnosticsLog.add('session', 'restore failed: $e');
      status = SessionStatus.signedOut;
      message = 'تعذر استعادة الجلسة. سجّل دخولك من جديد.';
      notifyListeners();
    }
  }

  /// Signs in with a username OR phone OR email + password.
  Future<void> signIn(String identifier, String password) async {
    status = SessionStatus.loading;
    message = '';
    notifyListeners();
    try {
      final email = await _backend.resolveEmail(identifier);
      if (email == null) {
        status = SessionStatus.denied;
        message = 'لا يوجد حساب بهذا الاسم أو الرقم.';
        notifyListeners();
        return;
      }
      final uid = await _backend.signInWithEmail(email, password);
      await _enter(uid);
    } on BackendNotConfigured {
      status = SessionStatus.denied;
      message = const BackendNotConfigured().toString();
      notifyListeners();
    } on BackendAuthFailed {
      status = SessionStatus.denied;
      message = 'بيانات الدخول غير صحيحة.';
      notifyListeners();
    } catch (e) {
      diagnosticsLog.add('session', 'signIn failed: $e');
      status = SessionStatus.denied;
      message = 'تعذر تسجيل الدخول: $e';
      notifyListeners();
    }
  }

  Future<void> _enter(String uid) async {
    final loaded = await _backend.loadAccount(uid);
    switch (managerGate(loaded)) {
      case GateDecision.ok:
        account = loaded;
        status = SessionStatus.ready;
      case GateDecision.blocked:
        await _backend.signOut();
        account = null;
        status = SessionStatus.blocked;
        message = 'هذا الحساب محظور. تواصل مع مدير آخر.';
      case GateDecision.mustChangePassword:
        account = loaded;
        status = SessionStatus.mustChangePassword;
        message = 'لازم تغيّر كلمة المرور الأول من تطبيق DeliveryFlow، '
            'وبعدها ادخل هنا تاني.';
      case GateDecision.notManager:
        await _backend.signOut();
        account = null;
        status = SessionStatus.denied;
        message = 'هذا التطبيق للمديرين فقط.';
      case GateDecision.noAccount:
        await _backend.signOut();
        account = null;
        status = SessionStatus.denied;
        message = 'لا يوجد ملف حساب لهذا المستخدم.';
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _backend.signOut();
    } catch (e) {
      diagnosticsLog.add('session', 'signOut failed: $e');
    }
    account = null;
    status = SessionStatus.signedOut;
    message = '';
    notifyListeners();
  }

  /// Refreshes the in-memory profile (after a role/password change).
  Future<void> refreshAccount() async {
    final uid = account?.uid ?? _backend.currentUid;
    if (uid == null) return;
    final loaded = await _backend.loadAccount(uid);
    if (loaded != null) {
      account = loaded;
      notifyListeners();
    }
  }
}
