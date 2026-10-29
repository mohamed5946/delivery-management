// Manager dashboard — the signature entry moment.
//
// When the manager enters, the dashboard comes ALIVE with him:
//   * every KPI number COUNTS UP from 0 to its real value (eased,
//     ~1.3s, never an instant jump);
//   * the week chart columns RISE UPWARD from the baseline,
//     staggered bar by bar, smooth and weighted;
//   * cards fade/slide in with a light stagger.
// Weighted, smooth, subtle — nothing pops in suddenly. The motion
// is the same luxury language as DeliveryFlow, not a gimmick.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/diagnostics.dart';
import '../../core/week_utils.dart';
import '../../data/backend.dart';
import '../../data/models.dart';
import '../../widgets/glass.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../session.dart';
import '../team/team_screen.dart';

/// A number that counts up from 0 to [value] (eased). Replays when
/// the value changes (e.g. after a refresh).
class CountUpNumber extends StatelessWidget {
  const CountUpNumber({
    super.key,
    required this.value,
    this.decimals = 0,
    this.style,
  });

  final double value;
  final int decimals;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 1300),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Text(
          v.toStringAsFixed(decimals),
          style: style,
        );
      },
    );
  }
}

/// Fades + slides a child up slightly, after [delay]. Used for the
/// KPI cards' staggered entrance.
class DelayedFadeSlide extends StatefulWidget {
  const DelayedFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<DelayedFadeSlide> createState() => _DelayedFadeSlideState();
}

class _DelayedFadeSlideState extends State<DelayedFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

/// One chart column rising upward from the baseline after [delay],
/// with its count ticking up above it.
class RisingBar extends StatefulWidget {
  const RisingBar({
    super.key,
    required this.fraction,
    required this.count,
    required this.delay,
    required this.color,
    required this.label,
  });

  /// 0..1 of the chart's max height.
  final double fraction;

  /// The value printed above the bar (counts up from 0).
  final int count;
  final Duration delay;
  final Color color;
  final String label;

  @override
  State<RisingBar> createState() => _RisingBarState();
}

class _RisingBarState extends State<RisingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _growth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _growth = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CountUpNumber(
          value: widget.count.toDouble(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: _growth,
          builder: (context, _) {
            return Container(
              width: 26,
              height: 110 * widget.fraction * _growth.value,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(widget.label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.users,
    required this.todayRows,
    required this.weekSummaries,
    required this.weekAdjustments,
  });

  final List<ManagerAccount> users;
  final List<DriverDayRow> todayRows;
  final Map<String, List<DaySummary>> weekSummaries;
  final Map<String, List<Adjustment>> weekAdjustments;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.backend,
    required this.session,
  });

  final ManagerBackend backend;
  final SessionController session;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  var _selectedDay = DateTime.now();
  List<ManagerAccount> _users = const [];
  Map<String, List<DaySummary>> _weekSummaries = const {};
  List<DaySummary> _todaySummaries = const [];
  final Map<String, List<Adjustment>> _weekAdjustments = {};
  final _adjustmentSubs = <String, StreamSubscription<List<Adjustment>>>{};
  // Per-user summaries listeners (one per visible user). A
  // collectionGroup('summaries') query is NOT used: under the
  // published rules it is denied with PERMISSION_DENIED for a
  // manager (field-proven 2026-10-29: the users listener works, so
  // the caller IS a manager, yet the group query is rejected),
  // while the same manager reads per-user subcollections fine —
  // the pattern DeliveryFlow's own dashboard already uses.
  final _summarySubs = <String, StreamSubscription<List<DaySummary>>>{};
  final _userSummaries = <String, List<DaySummary>>{};
  final _summaryPending = <String>{};
  var _summaryKeys = const <String>[];
  var _summariesFallback = false;
  final _subs = <StreamSubscription<dynamic>>[];
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

  String get _todayKey => dateKey(_selectedDay);

  /// Attaches the live listeners (users, per-user day summaries,
  /// per-user adjustments). Cancelling + re-attaching is also the
  /// manual refresh fallback.
  void _subscribe() {
    _cancelAll();
    _liveError = null;
    _summariesFallback = false;
    _summaryKeys = <String>{_todayKey, ...weekDateKeys(_selectedDay)}.toList();
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
          _rebuildSummaryAggregates();
        },
        onError: (Object e) => _onSummariesError(e),
      );
    }
    if (changed || _summarySubs.isEmpty) _rebuildSummaryAggregates();
  }

  void _rebuildSummaryAggregates() {
    if (!mounted) return;
    final week = <String, List<DaySummary>>{};
    final today = <DaySummary>[];
    for (final list in _userSummaries.values) {
      for (final s in list) {
        (week[s.dateKey] ??= []).add(s);
        if (s.dateKey == _todayKey) today.add(s);
      }
    }
    setState(() {
      _weekSummaries = week;
      _todaySummaries = today;
      // Latch: once loaded (live or fallback) it stays loaded;
      // later per-user events only grow the data, never re-skeleton.
      if (_summaryPending.isEmpty || _summariesFallback) {
        _summariesLoaded = true;
      }
    });
  }

  /// A summaries listener failed (field-proven: PERMISSION_DENIED on
  /// the old group query). Fall back to a one-time fetch — per-user
  /// single-doc gets, the access pattern DeliveryFlow's own
  /// dashboard already uses — so the screen still shows data, and
  /// put the REAL reason on the error card, not a generic line.
  Future<void> _onSummariesError(Object e) async {
    diagnosticsLog.add('live', 'summaries stream error: $e');
    if (!mounted) return;
    List<DaySummary>? fetched;
    Object? fetchError;
    try {
      final byDay = await widget.backend.listSummariesForDays(_summaryKeys);
      fetched = byDay.values.expand((list) => list).toList();
    } catch (err) {
      fetchError = err;
    }
    if (!mounted) return;
    setState(() {
      _liveError = 'الاتصال المباشر وقف (summaries): $e'
          '${fetchError != null ? '\nتعذر الجلب الاحتياطي: $fetchError' : ''}';
      if (fetched != null) {
        _summariesFallback = true;
        final week = <String, List<DaySummary>>{};
        final today = <DaySummary>[];
        for (final s in fetched) {
          (week[s.dateKey] ??= []).add(s);
          if (s.dateKey == _todayKey) today.add(s);
        }
        _weekSummaries = week;
        _todaySummaries = today;
        _summariesLoaded = true;
      }
    });
  }

  /// Same resilience for the users stream: one-time fetch fallback,
  /// real reason on the card.
  Future<void> _onUsersError(Object e) async {
    diagnosticsLog.add('live', 'users stream error: $e');
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
          setState(() => _weekAdjustments[user.uid] = adjs);
        },
        onError: (Object e) => _onLiveError('adjustments', e),
      );
    }
  }

  void _onLiveError(String what, Object e) {
    diagnosticsLog.add('live', '$what stream error: $e');
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

  void _shiftDay(int days) {
    setState(() {
      _selectedDay = addDays(_selectedDay, days);
    });
    _subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        actions: [
          IconButton(
            key: const ValueKey('dashboardDiagnostics'),
            icon: const Icon(Icons.bug_report_rounded),
            tooltip: 'سجل التشخيص',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DiagnosticsScreen(),
                ),
              );
            },
          ),
          IconButton(
            key: const ValueKey('dashboardRefresh'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: GlassTokens.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DaySelector(
                selected: _selectedDay,
                onShift: _shiftDay,
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
                const DashboardSkeleton()
              else
                _DashboardBody(
                  data: _DashboardData(
                    users: _users,
                    todayRows: buildDriverRows(_users, _todaySummaries),
                    weekSummaries: _weekSummaries,
                    weekAdjustments: _weekAdjustments,
                  ),
                  weekKey: weekKeyOf(_selectedDay),
                  weekKeys: weekDateKeys(_selectedDay),
                  backend: widget.backend,
                  managerUid: widget.session.account!.uid,
                  onTeamTap: (account) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DriverDetailScreen(
                          backend: widget.backend,
                          managerUid: widget.session.account!.uid,
                          account: account,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.selected, required this.onShift});

  final DateTime selected;
  final void Function(int days) onShift;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => onShift(-1),
          ),
          Expanded(
            child: Text(
              arabicDayLabel(dateKey(selected)),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => onShift(1),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.weekKey,
    required this.weekKeys,
    required this.backend,
    required this.managerUid,
    required this.onTeamTap,
  });

  final _DashboardData data;
  final String weekKey;
  final List<String> weekKeys;
  final ManagerBackend backend;
  final String managerUid;
  final void Function(ManagerAccount account) onTeamTap;

  @override
  Widget build(BuildContext context) {
    final kpis = computeKpis(data.todayRows);
    final alerts = findAlerts(data.todayRows);
    final weekOrders = weekOrdersPerDay(data.weekSummaries, weekKeys);
    final weekMax = weekOrders.fold<int>(0, (m, v) => v > m ? v : m);
    // Week salary due: every visible driver's payoutWeek net summed.
    var weekSalary = 0.0;
    var weekOrdersTotal = 0;
    var weekKmTotal = 0.0;
    for (final user in data.users) {
      final summaries = weekKeys
          .map((k) => data.weekSummaries[k] ?? const <DaySummary>[])
          .expand((list) => list)
          .where((s) => s.uid == user.uid);
      final payout = payoutWeek(
        summaries: summaries,
        adjustments: data.weekAdjustments[user.uid] ?? const [],
        weekKey: weekKey,
      );
      weekSalary += payout.net;
      final userWeek = data.weekSummaries.values
          .expand((list) => list)
          .where((s) => s.uid == user.uid);
      weekOrdersTotal += userWeek.fold<int>(0, (s, x) => s + x.ordersCount);
      weekKmTotal += userWeek.fold<double>(0, (s, x) => s + x.totalKm);
    }
    const dayLabels = ['أحد', 'إثنين', 'ثلاث', 'أربع', 'خميس', 'جمعة', 'سبت'];
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            _KpiCard(
              index: 0,
              label: 'فريق العمل',
              child: CountUpNumber(
                value: data.users.length.toDouble(),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            _KpiCard(
              index: 1,
              label: 'متزامن اليوم',
              child: Row(
                children: [
                  CountUpNumber(
                    value: kpis.driversActive.toDouble(),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    ' / ${data.users.length}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            _KpiCard(
              index: 2,
              label: 'أوردرات اليوم',
              child: CountUpNumber(
                value: kpis.totalOrders.toDouble(),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            _KpiCard(
              index: 3,
              label: 'كم اليوم',
              child: Row(
                children: [
                  CountUpNumber(
                    value: kpis.totalKm,
                    decimals: 1,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Text(' كم'),
                ],
              ),
            ),
            _KpiCard(
              index: 4,
              label: 'أوردرات الأسبوع',
              child: CountUpNumber(
                value: weekOrdersTotal.toDouble(),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            _KpiCard(
              index: 5,
              label: 'كم الأسبوع',
              child: Row(
                children: [
                  CountUpNumber(
                    value: weekKmTotal,
                    decimals: 1,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Text(' كم'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DelayedFadeSlide(
          delay: const Duration(milliseconds: 500),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مستحق الأسبوع',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                CountUpNumber(
                  value: weekSalary,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: GlassTokens.primaryBlue,
                      ),
                ),
                const Text('ج.م — شامل البونص والخصومات'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        DelayedFadeSlide(
          delay: const Duration(milliseconds: 550),
          child: GlassCard(
            key: ValueKey('dashboardWeekChart-$weekKey'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أوردرات الأسبوع',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 190,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (var i = 0; i < 7; i++)
                        RisingBar(
                          fraction: weekMax == 0 ? 0 : weekOrders[i] / weekMax,
                          count: weekOrders[i],
                          delay: Duration(milliseconds: 150 + i * 90),
                          color: i == 6
                              ? GlassTokens.primaryBlue
                              : scheme.primary.withValues(alpha: 0.55),
                          label: dayLabels[i],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'الأعمدة بتطلع من تحت لفوق، والأرقام بتتعد '
                  'من صفر — البرنامج حي معاك.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (!alerts.isEmpty) ...[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'محتاج انتباه',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (alerts.notSynced.isNotEmpty)
                  Text(
                    'غير متزامن: ${alerts.notSynced.map((r) => r.account.displayName).join('، ')}',
                  ),
                if (alerts.zeroOrders.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'صفر أوردرات: ${alerts.zeroOrders.map((r) => r.account.displayName).join('، ')}',
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'الفريق اليوم',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        for (final row in sortDrivers(data.todayRows, DriverSort.orders))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              onTap: () => onTeamTap(row.account),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        GlassTokens.primaryBlue.withValues(alpha: 0.12),
                    child: Text(
                      row.account.displayName.isEmpty
                          ? '?'
                          : row.account.displayName[0],
                      style: const TextStyle(
                        color: GlassTokens.primaryBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.account.displayName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          row.synced
                              ? '${row.orders} أوردر • ${row.km.toStringAsFixed(1)} كم'
                              : 'غير متزامن اليوم',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    egp(row.salary),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.index,
    required this.label,
    required this.child,
  });

  final int index;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DelayedFadeSlide(
      delay: Duration(milliseconds: 100 + index * 90),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            child,
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
