// Weekly payroll tab: driver names for the selected week, each
// row showing payout method, weekly net, and visible bonus /
// deduction lines (never a silent net). Tap a name → payout detail
// with the day-by-day breakdown. Blocked drivers are excluded.
// Row and detail share [payoutWeek], so their nets always agree.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/diagnostics.dart';
import '../../core/week_utils.dart';
import '../../data/backend.dart';
import '../../data/models.dart';
import '../../widgets/glass.dart';
import '../../widgets/shimmer_skeleton.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({
    super.key,
    required this.backend,
    required this.managerUid,
  });

  final ManagerBackend backend;
  final String managerUid;

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollRowData {
  const _PayrollRowData({required this.account, required this.payout});

  final ManagerAccount account;
  final PayoutWeek payout;
}

class _PayrollScreenState extends State<PayrollScreen> {
  var _weekStart = weekStartSunday(DateTime.now());
  List<_PayrollRowData> _rows = const [];
  List<ManagerAccount> _users = const [];
  Map<String, List<DaySummary>> _week = const {};
  final Map<String, List<Adjustment>> _adjustments = {};
  final _subs = <StreamSubscription<dynamic>>[];
  final _adjustmentSubs = <String, StreamSubscription<List<Adjustment>>>{};
  // Per-user summaries listeners — same fix as the dashboard: the
  // collectionGroup('summaries') query is denied for a manager under
  // the published rules (field-proven PERMISSION_DENIED), while
  // per-user subcollection reads work.
  final _summarySubs = <String, StreamSubscription<List<DaySummary>>>{};
  final _userSummaries = <String, List<DaySummary>>{};
  final _summaryPending = <String>{};
  var _summaryKeys = const <String>[];
  var _summariesFallback = false;
  var _usersLoaded = false;
  var _summariesLoaded = false;
  String? _liveError;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _cancelAll();
    super.dispose();
  }

  void _cancelAll() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    for (final sub in _adjustmentSubs.values) {
      sub.cancel();
    }
    _adjustmentSubs.clear();
    for (final sub in _summarySubs.values) {
      sub.cancel();
    }
    _summarySubs.clear();
    _userSummaries.clear();
    _summaryPending.clear();
    _summariesLoaded = false;
  }

  String get _weekKey => dateKey(_weekStart);

  /// Live listeners (users, per-user week summaries, per-user
  /// adjustments). Re-attaching is also the manual refresh fallback.
  void _subscribe() {
    _cancelAll();
    _liveError = null;
    _summariesFallback = false;
    _summaryKeys = weekDateKeys(_weekStart);
    _subs.add(
      widget.backend.watchUsers().listen(
        (users) {
          if (!mounted) return;
          final visible = visibleTeamUsers(users);
          setState(() {
            _users = visible;
            _usersLoaded = true;
          });
          _syncAdjustmentSubs(visible);
          _syncSummarySubs(visible);
          _rebuildRows();
        },
        onError: (Object e) => _onUsersError(e),
      ),
    );
  }

  void _syncSummarySubs(List<ManagerAccount> users) {
    final ids = users.map((u) => u.uid).toSet();
    var changed = false;
    for (final id
        in _summarySubs.keys.where((k) => !ids.contains(k)).toList()) {
      _summarySubs.remove(id)?.cancel();
      _userSummaries.remove(id);
      _summaryPending.remove(id);
      changed = true;
    }
    for (final user in users) {
      if (_summarySubs.containsKey(user.uid)) continue;
      _summaryPending.add(user.uid);
      _summarySubs[user.uid] =
          widget.backend.watchSummariesForUser(user.uid, _summaryKeys).listen(
        (list) {
          if (!mounted) return;
          _userSummaries[user.uid] = list;
          _summaryPending.remove(user.uid);
          _rebuildWeek();
        },
        onError: (Object e) => _onSummariesError(e),
      );
    }
    if (changed || _summarySubs.isEmpty) _rebuildWeek();
  }

  void _rebuildWeek() {
    if (!mounted) return;
    final week = <String, List<DaySummary>>{};
    for (final list in _userSummaries.values) {
      for (final s in list) {
        (week[s.dateKey] ??= []).add(s);
      }
    }
    setState(() {
      _week = week;
      // Latch: once loaded (live or fallback) it stays loaded.
      if (_summaryPending.isEmpty || _summariesFallback) {
        _summariesLoaded = true;
      }
    });
    _rebuildRows();
  }

  /// Summaries listener failed: one-time fetch fallback + the REAL
  /// reason on the error card (same fix as the dashboard).
  Future<void> _onSummariesError(Object e) async {
    diagnosticsLog.add('live', 'payroll summaries stream error: $e');
    if (!mounted) return;
    Map<String, List<DaySummary>>? fetched;
    Object? fetchError;
    try {
      fetched = await widget.backend.listSummariesForDays(_summaryKeys);
    } catch (err) {
      fetchError = err;
    }
    if (!mounted) return;
    setState(() {
      _liveError = 'الاتصال المباشر وقف (summaries): $e'
          '${fetchError != null ? '\nتعذر الجلب الاحتياطي: $fetchError' : ''}';
      if (fetched != null) {
        _summariesFallback = true;
        _week = fetched;
        _summariesLoaded = true;
      }
    });
    _rebuildRows();
  }

  /// Users stream failed: one-time fetch fallback + real reason.
  Future<void> _onUsersError(Object e) async {
    diagnosticsLog.add('live', 'payroll users stream error: $e');
    if (!mounted) return;
    List<ManagerAccount>? fetched;
    Object? fetchError;
    try {
      fetched = await widget.backend.listUsers();
    } catch (err) {
      fetchError = err;
    }
    if (!mounted) return;
    setState(() {
      _liveError = 'الاتصال المباشر وقف (users): $e'
          '${fetchError != null ? '\nتعذر الجلب الاحتياطي: $fetchError' : ''}';
      if (fetched != null) {
        final visible = visibleTeamUsers(fetched);
        _users = visible;
        _usersLoaded = true;
        _syncAdjustmentSubs(visible);
        _syncSummarySubs(visible);
      }
    });
    _rebuildRows();
  }

  void _syncAdjustmentSubs(List<ManagerAccount> users) {
    final ids = users.map((u) => u.uid).toSet();
    for (final id
        in _adjustmentSubs.keys.where((k) => !ids.contains(k)).toList()) {
      _adjustmentSubs.remove(id)?.cancel();
    }
    for (final user in users) {
      if (_adjustmentSubs.containsKey(user.uid)) continue;
      _adjustmentSubs[user.uid] =
          widget.backend.watchAdjustments(user.uid).listen(
        (adjs) {
          if (!mounted) return;
          setState(() => _adjustments[user.uid] = adjs);
          _rebuildRows();
        },
        onError: (Object e) => _onLiveError('adjustments', e),
      );
    }
  }

  void _rebuildRows() {
    if (!mounted) return;
    final keys = weekDateKeys(_weekStart);
    final out = <_PayrollRowData>[];
    for (final user in _users) {
      final summaries = keys
          .map((k) => _week[k] ?? const <DaySummary>[])
          .expand((list) => list)
          .where((s) => s.uid == user.uid);
      out.add(
        _PayrollRowData(
          account: user,
          payout: payoutWeek(
            summaries: summaries,
            adjustments: _adjustments[user.uid] ?? const [],
            weekKey: _weekKey,
          ),
        ),
      );
    }
    out.sort(
      (a, b) => a.account.displayName.compareTo(b.account.displayName),
    );
    setState(() => _rows = out);
  }

  void _onLiveError(String what, Object e) {
    diagnosticsLog.add('live', 'payroll $what stream error: $e');
    if (!mounted) return;
    setState(
      () => _liveError = 'الاتصال المباشر وقف ($what): $e',
    );
  }

  void _refresh() {
    setState(() {
      _liveError = null;
      _summariesFallback = false;
    });
    _subscribe();
  }

  void _shiftWeek(int weeks) {
    setState(() {
      _weekStart = addDays(_weekStart, 7 * weeks);
    });
    _subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأجور الأسبوعية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: GlassTokens.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _shiftWeek(-1),
                  ),
                  Expanded(
                    child: Text(
                      'أسبوع ${arabicDayLabel(_weekKey)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _shiftWeek(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_liveError != null)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_liveError!),
                    if (_summariesFallback) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'البيانات المعروضة من جلب لمرة واحدة — '
                        'اضغط إعادة الاتصال لاستعادة المباشر.',
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('إعادة الاتصال'),
                    ),
                  ],
                ),
              ),
            if (!(_usersLoaded && _summariesLoaded))
              const ListSkeleton()
            else if (_rows.isEmpty)
              const GlassCard(
                child: Text('مفيش أعضاء فريق لعرض أجورهم.'),
              )
            else
              Column(
                children: [
                  for (final row in _rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PayoutDetailScreen(
                                backend: widget.backend,
                                account: row.account,
                                weekStart: _weekStart,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.account.displayName,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  Text(
                                    'طريقة القبض: '
                                    '${row.account.payoutMethod.labelAr}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if (row.payout.totalBonus > 0)
                                    Text(
                                      'بونص: +${egp(row.payout.totalBonus)}',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  if (row.payout.deduction > 0)
                                    Text(
                                      'خصم: −${egp(row.payout.deduction)}',
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              egp(row.payout.net),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class PayoutDetailScreen extends StatefulWidget {
  const PayoutDetailScreen({
    super.key,
    required this.backend,
    required this.account,
    required this.weekStart,
  });

  final ManagerBackend backend;
  final ManagerAccount account;
  final DateTime weekStart;

  @override
  State<PayoutDetailScreen> createState() => _PayoutDetailScreenState();
}

class _PayoutDetailScreenState extends State<PayoutDetailScreen> {
  List<DaySummary> _summaries = const [];
  List<Adjustment> _adjustments = const [];
  ManagerAccount? _account;
  var _summariesLoaded = false;
  var _adjustmentsLoaded = false;
  String? _liveError;
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _subscribe();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  void _subscribe() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _liveError = null;
    _subs.add(
      widget.backend.watchAccount(widget.account.uid).listen(
        (account) {
          if (!mounted || account == null) return;
          setState(() => _account = account);
        },
        onError: (Object e) => _onLiveError('account', e),
      ),
    );
    _subs.add(
      widget.backend
          .watchSummariesForUser(
        widget.account.uid,
        weekDateKeys(widget.weekStart),
      )
          .listen(
        (summaries) {
          if (!mounted) return;
          setState(() {
            _summaries = summaries;
            _summariesLoaded = true;
          });
        },
        onError: (Object e) => _onLiveError('summaries', e),
      ),
    );
    _subs.add(
      widget.backend.watchAdjustments(widget.account.uid).listen(
        (adjustments) {
          if (!mounted) return;
          setState(() {
            _adjustments = adjustments;
            _adjustmentsLoaded = true;
          });
        },
        onError: (Object e) => _onLiveError('adjustments', e),
      ),
    );
  }

  void _onLiveError(String what, Object e) {
    diagnosticsLog.add('live', 'payout detail $what stream error: $e');
    if (!mounted) return;
    setState(
      () => _liveError =
          'الاتصال المباشر وقف ($what). اضغط تحديث لإعادة الاتصال.',
    );
  }

  void _refresh() {
    setState(() => _liveError = null);
    _subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final account = _account ?? widget.account;
    final weekKey = dateKey(widget.weekStart);
    final keys = weekDateKeys(widget.weekStart);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('قبض ${account.displayName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_liveError != null) {
            return SingleChildScrollView(
              padding: GlassTokens.screenPadding,
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_liveError!),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('إعادة الاتصال'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!(_summariesLoaded && _adjustmentsLoaded)) {
            return const SingleChildScrollView(
              padding: GlassTokens.screenPadding,
              child: ListSkeleton(),
            );
          }
          final payout = payoutWeek(
            summaries: _summaries,
            adjustments: _adjustments,
            weekKey: weekKey,
          );
          final byDay = <String, List<Adjustment>>{};
          for (final a in adjustmentsForWeek(_adjustments, weekKey)) {
            final dayKey = dateKeyOfMillis(a.createdAtMillis);
            (byDay[dayKey] ??= []).add(a);
          }
          final outsideWeek = adjustmentsForWeek(
            _adjustments,
            weekKey,
          ).where((a) => !keys.contains(dateKeyOfMillis(a.createdAtMillis)));
          DaySummary? summaryFor(String dayKey) {
            for (final s in _summaries) {
              if (s.dateKey == dayKey) return s;
            }
            return null;
          }

          return SingleChildScrollView(
            padding: GlassTokens.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text('أسبوع ${arabicDayLabel(weekKey)}'),
                      const SizedBox(height: 8),
                      InfoRow(
                        icon: Icons.payments_rounded,
                        label: 'طريقة القبض',
                        value: account.payoutMethod.labelAr,
                      ),
                      InfoRow(
                        icon: Icons.phone_rounded,
                        label: 'رقم التحويل',
                        value: account.payoutNumber,
                      ),
                      InfoRow(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'اسم المحفظة',
                        value: account.payoutName,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المستحق',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text('مجاميع الأيام: ${egp(payout.base)}'),
                      if (payout.bonus > 0)
                        Text(
                          'بونص (تعديلات): +${egp(payout.bonus)}',
                          style: TextStyle(color: scheme.primary),
                        ),
                      if (payout.deduction > 0)
                        Text(
                          'خصومات (تعديلات): −${egp(payout.deduction)}',
                          style: TextStyle(color: scheme.error),
                        ),
                      const Divider(),
                      Text(
                        egp(payout.net),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final dayKey in keys) ...[
                  Builder(
                    builder: (context) {
                      final summary = summaryFor(dayKey);
                      final dayAdjs = byDay[dayKey] ?? const [];
                      final dayBonus = summary == null
                          ? 0.0
                          : summary.manualBonus +
                              summary.distanceBonus +
                              summary.flatBonus;
                      final hasBonus =
                          dayBonus > 0 || dayAdjs.any((a) => a.isBonus);
                      final hasDeduction = dayAdjs.any((a) => !a.isBonus);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      arabicDayLabel(dayKey),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ),
                                  Text(
                                    summary == null
                                        ? 'مفيش بيانات'
                                        : egp(summary.salaryTotal),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                              if (hasBonus || hasDeduction) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (hasBonus)
                                      Text(
                                        'بونص',
                                        style: TextStyle(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    if (hasBonus && hasDeduction)
                                      const SizedBox(width: 12),
                                    if (hasDeduction)
                                      Text(
                                        'خصم',
                                        style: TextStyle(
                                          color: scheme.error,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              for (final a in dayAdjs) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(child: Text(a.reason)),
                                    Text(
                                      signedEgp(
                                        a.amount,
                                        isBonus: a.isBonus,
                                      ),
                                      style: TextStyle(
                                        color: a.isBonus
                                            ? scheme.primary
                                            : scheme.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
                if (outsideWeek.isNotEmpty)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تعديلات تانية لنفس الأسبوع',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Text(
                          'محسوبة في المجموع، لكن اتعملت في يوم '
                          'بره الأسبوع.',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        for (final a in outsideWeek)
                          Row(
                            children: [
                              Expanded(child: Text(a.reason)),
                              Text(
                                signedEgp(a.amount, isBonus: a.isBonus),
                                style: TextStyle(
                                  color:
                                      a.isBonus ? scheme.primary : scheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
