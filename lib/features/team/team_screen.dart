// Team section — its own standalone screen, opened from the
// prominent "فريق العمل" entry in the Application tab.
//
// Team list: searchable, all people (drivers + managers, blocked
// members excluded — they live in the Block tab).
// Tap a person → driver detail, the deepest screen in the app:
//   * phone, email, payout method/number/wallet name
//   * DAY SELECTOR (the manager picks the day)
//   * that day's totals + salary components + manager-edit stamp
//   * the week's totals (base + bonuses − deductions)
//   * that day's ORDERS list → tap an order → FULL order detail
//     mirroring the driver-side screen field-for-field (status,
//     times, km legs + GPS km + manual badges, durations, notes,
//     phone, manual bonus, count-only, route point counts)
//   * edit day components, manager adjustments (reason required),
//     promote/demote (never self), block/unblock (never self,
//     confirmation first, data always kept)
//
// HONEST DATA NOTE: DeliveryFlow's cloud order docs today carry
// only {dateKey, completedOrders, totalKm} — per-order entries live
// only on the driver's phone. The orders section reads the
// `entries` array when present (exact driver-app JSON shape), so
// full per-order detail lights up as soon as the driver app
// uploads entries; until then it shows the day count and totals
// and says so plainly — it never invents orders.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/diagnostics.dart';
import '../../core/week_utils.dart';
import '../../data/backend.dart';
import '../../data/models.dart';
import '../../widgets/confirm.dart';
import '../../widgets/glass.dart';
import '../../widgets/shimmer_skeleton.dart';

String _timeLabel(int? millis) {
  if (millis == null) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _durationLabel(int seconds) {
  if (seconds <= 0) return '—';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s == 0 ? '$m د' : '$m د $s ث';
}

class TeamScreen extends StatefulWidget {
  const TeamScreen({
    super.key,
    required this.backend,
    required this.managerUid,
  });

  final ManagerBackend backend;
  final String managerUid;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _search = TextEditingController();
  var _query = '';
  List<ManagerAccount> _users = const [];
  var _loaded = false;
  String? _liveError;
  StreamSubscription<List<ManagerAccount>>? _sub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Live team list. Re-attaching is the manual refresh fallback.
  void _subscribe() {
    _sub?.cancel();
    _liveError = null;
    _sub = widget.backend.watchUsers().listen(
      (users) {
        if (!mounted) return;
        final visible = visibleTeamUsers(users);
        visible.sort((a, b) => a.displayName.compareTo(b.displayName));
        setState(() {
          _users = visible;
          _loaded = true;
        });
      },
      onError: (Object e) {
        diagnosticsLog.add('live', 'team stream error: $e');
        if (!mounted) return;
        setState(
          () => _liveError =
              'الاتصال المباشر وقف. اضغط تحديث لإعادة الاتصال.',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فريق العمل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _liveError = null);
              _subscribe();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: GlassTokens.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('teamSearch'),
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'ابحث بالاسم',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            if (_liveError != null)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_liveError!),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() => _liveError = null);
                        _subscribe();
                      },
                      child: const Text('إعادة الاتصال'),
                    ),
                  ],
                ),
              ),
            if (!_loaded)
              const ListSkeleton()
            else
              Builder(
                builder: (context) {
                  final q = _query.trim().toLowerCase();
                  final users = [
                    for (final u in _users)
                      if (q.isEmpty ||
                          u.displayName.toLowerCase().contains(q))
                        u,
                  ];
                  if (users.isEmpty) {
                    return const GlassCard(
                      child: Text('مفيش نتائج مطابقة.'),
                    );
                  }
                  return Column(
                    children: [
                      for (final user in users)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DriverDetailScreen(
                                    backend: widget.backend,
                                    managerUid: widget.managerUid,
                                    account: user,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: GlassTokens.primaryBlue
                                      .withValues(alpha: 0.12),
                                  child: Text(
                                    user.displayName.isEmpty
                                        ? '?'
                                        : user.displayName[0],
                                    style: const TextStyle(
                                      color: GlassTokens.primaryBlue,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.displayName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                      Text(
                                        user.isManager ? 'مدير' : 'سواق',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (user.phone.isNotEmpty)
                                  Text(
                                    user.phone,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class DriverDetailScreen extends StatefulWidget {
  const DriverDetailScreen({
    super.key,
    required this.backend,
    required this.managerUid,
    required this.account,
  });

  final ManagerBackend backend;
  final String managerUid;
  final ManagerAccount account;

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  var _selectedDay = DateTime.now();
  ManagerAccount? _account;
  List<DaySummary> _weekSummaries = const [];
  DayOrderRecord? _record;
  List<Adjustment> _adjustments = const [];
  var _summariesLoaded = false;
  var _adjustmentsLoaded = false;
  var _recordLoaded = false;
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

  String get _dayKey => dateKey(_selectedDay);
  String get _weekKey => weekKeyOf(_selectedDay);

  /// Live listeners: profile (payout prefs, blocked flag), week
  /// summaries, adjustments, and the day's order record. Any change
  /// — a driver adding an order, a bonus, a block — re-renders
  /// this screen the moment it lands. Re-attaching is the manual
  /// refresh fallback.
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
            weekDateKeys(_selectedDay),
          )
          .listen(
        (summaries) {
          if (!mounted) return;
          setState(() {
            _weekSummaries = summaries;
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
    _subs.add(
      widget.backend.watchOrderRecord(widget.account.uid, _dayKey).listen(
        (record) {
          if (!mounted) return;
          setState(() {
            _record = record;
            _recordLoaded = true;
          });
        },
        onError: (Object e) => _onLiveError('orders', e),
      ),
    );
  }

  void _onLiveError(String what, Object e) {
    diagnosticsLog.add('live', 'driver detail $what stream error: $e');
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

  void _shiftDay(int days) {
    setState(() {
      _selectedDay = addDays(_selectedDay, days);
    });
    _subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final account = _account ?? widget.account;
    final isSelf = account.uid == widget.managerUid;
    final scheme = Theme.of(context).colorScheme;
    DaySummary? daySummary() {
      for (final s in _weekSummaries) {
        if (s.dateKey == _dayKey) return s;
      }
      return null;
    }

    final summary = daySummary();
    final payout = payoutWeek(
      summaries: _weekSummaries,
      adjustments: _adjustments,
      weekKey: _weekKey,
    );
    final loaded = _summariesLoaded && _adjustmentsLoaded;
    return Scaffold(
      appBar: AppBar(
        title: Text(account.displayName),
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
            if (_liveError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
              ),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          account.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: GlassTokens.primaryBlue
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          account.isManager ? 'مدير' : 'سواق',
                          style: const TextStyle(
                            color: GlassTokens.primaryBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (account.blocked)
                    const Text(
                      'محظور حاليًا',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(height: 8),
                  InfoRow(
                    icon: Icons.phone_rounded,
                    label: 'التليفون',
                    value: account.phone,
                  ),
                  InfoRow(
                    icon: Icons.email_rounded,
                    label: 'الإيميل',
                    value: account.email,
                  ),
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
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _shiftDay(-1),
                  ),
                  Expanded(
                    child: Text(
                      arabicDayLabel(_dayKey),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _shiftDay(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!loaded)
              const ListSkeleton()
            else ...[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'يوم ${arabicDayLabel(_dayKey)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    if (summary == null)
                      const Text('مفيش بيانات لليوم ده.')
                    else ...[
                      Text(
                        'أوردرات: ${summary.ordersCount} • '
                        'كم: ${summary.totalKm.toStringAsFixed(1)} • '
                        'المجموع: ${egp(summary.salaryTotal)}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'سعر الأوردر: ${egp(summary.orderPrice)} • '
                        'ثابت اليوم: ${egp(summary.dailyFixedPay)}',
                      ),
                      Text(
                        'بونص مسافة: ${egp(summary.distanceBonus)} • '
                        'بونص يدوي: ${egp(summary.manualBonus)} • '
                        'بونص ثابت: ${egp(summary.flatBonus)}',
                      ),
                      if (summary.editedByManager)
                        const Text(
                          'آخر تعديل كان من المدير.',
                          style: TextStyle(fontSize: 13),
                        ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey('driverEditDay'),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('تعديل بيانات اليوم'),
                      onPressed: () async {
                        final saved = await showDialog<bool>(
                          context: context,
                          builder: (_) => _EditDayDialog(
                            backend: widget.backend,
                            uid: widget.account.uid,
                            managerUid: widget.managerUid,
                            initial: summary,
                            dateKey: _dayKey,
                          ),
                        );
                        if (saved != true) return;
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم حفظ اليوم'),
                          ),
                        );
                      },
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
                      'مجموع الأسبوع',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text('مجاميع الأيام: ${egp(payout.base)}'),
                    if (payout.bonus > 0)
                      Text(
                        'بونص: +${egp(payout.bonus)}',
                        style: TextStyle(color: scheme.primary),
                      ),
                    if (payout.deduction > 0)
                      Text(
                        'خصم: −${egp(payout.deduction)}',
                        style: TextStyle(color: scheme.error),
                      ),
                    Text(
                      'الصافي: ${egp(payout.net)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!_recordLoaded)
                const GlassCard(child: Text('جاري تحميل الأوردرات...'))
              else
                _OrdersSection(
                  record: _record,
                  onOrderSaved: (updated) async {
                    final record = _record;
                    if (record == null) return;
                    final entries = [
                      for (final e in record.entries)
                        e.id == updated.id ? updated : e,
                    ];
                    await widget.backend.saveOrderRecord(
                      widget.account.uid,
                      _dayKey,
                      DayOrderRecord(
                        dateKey: _dayKey,
                        completedOrders: record.completedOrders,
                        totalKm: record.totalKm,
                        entries: entries,
                      ),
                      widget.managerUid,
                    );
                  },
                ),
              const SizedBox(height: 12),
              _AdjustmentsSection(
                backend: widget.backend,
                managerUid: widget.managerUid,
                uid: widget.account.uid,
                weekKey: _weekKey,
                adjustments: _adjustments,
                onChanged: _subscribe,
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isSelf)
                      const Text(
                        'ده حسابك — مينفعش تغيّر دورك أو تحظر '
                        'نفسك بنفسك.',
                      )
                    else ...[
                      FilledButton(
                        key: const ValueKey('driverRoleToggle'),
                        onPressed: () async {
                          final toManager = !account.isManager;
                          final confirmed = await showConfirmDialog(
                            context: context,
                            title:
                                toManager ? 'ترقية لمدير؟' : 'تنزيل لسواق؟',
                            body: toManager
                                ? '${account.displayName} هيبقى مدير '
                                    'ويشوف كل بيانات الفريق.'
                                : '${account.displayName} هيرجع سواق '
                                    'ومش هيشوف صفحة المديرين.',
                            confirmLabel: toManager ? 'ترقية' : 'تنزيل',
                            destructive: false,
                          );
                          if (!confirmed) return;
                          try {
                            await widget.backend.setRole(
                              account.uid,
                              toManager
                                  ? ManagerRole.manager
                                  : ManagerRole.driver,
                              widget.managerUid,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('فشل: $e')),
                              );
                            }
                          }
                        },
                        child: Text(
                          account.isManager ? 'تنزيل لسواق' : 'ترقية لمدير',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: const ValueKey('driverBlockToggle'),
                        onPressed: () async {
                          if (!account.blocked) {
                            final confirmed = await showConfirmDialog(
                              context: context,
                              title: 'حظر السواق؟',
                              body: 'مش هيقدر يسجل دخول، وهيختفي '
                                  'من الفريق، وأجوره مش هتتحسب. '
                                  'داتاه محفوظة — فك الحظر بيرجّعه '
                                  'كامل. مفيش حاجة بتتمسح.',
                              confirmLabel: 'حظر',
                            );
                            if (!confirmed) return;
                            try {
                              await widget.backend.setBlocked(
                                account.uid,
                                true,
                                widget.managerUid,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('فشل: $e')),
                                );
                              }
                            }
                          } else {
                            final confirmed = await showConfirmDialog(
                              context: context,
                              title: 'فك حظر السواق؟',
                              body: '${account.displayName} هيرجع '
                                  'يسجل دخول بداتاه كاملة.',
                              confirmLabel: 'فك الحظر',
                              destructive: false,
                            );
                            if (!confirmed) return;
                            try {
                              await widget.backend.setBlocked(
                                account.uid,
                                false,
                                widget.managerUid,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('فشل: $e')),
                                );
                              }
                            }
                          }
                        },
                        child: Text(
                          account.blocked ? 'فك الحظر' : 'حظر',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The day's orders. Full entries when the driver app uploads them;
/// an honest count-only state until then (never invented orders).
class _OrdersSection extends StatelessWidget {
  const _OrdersSection({required this.record, required this.onOrderSaved});

  final DayOrderRecord? record;
  final Future<void> Function(OrderEntry updated) onOrderSaved;

  @override
  Widget build(BuildContext context) {
    final rec = record;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أوردرات اليوم',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (rec == null)
            const Text('مفيش سجل أوردرات لليوم ده.')
          else if (!rec.hasEntries) ...[
            Text(
              '${rec.completedOrders} أوردر مكتمل • '
              '${rec.totalKm.toStringAsFixed(1)} كم',
            ),
            const SizedBox(height: 4),
            const Text(
              'تفاصيل الأوردر الواحد لسه مش بتترفع للسحابة من '
              'تطبيق السواق — أول ما تحديث الرفع ده ينزل، '
              'الأوردرات هتظهر هنا بالتفصيل.',
              style: TextStyle(fontSize: 13),
            ),
          ] else
            for (final order in rec.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(
                          order: order,
                          onSaved: onOrderSaved,
                        ),
                      ),
                    );
                  },
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${order.id.length > 6 ? order.id.substring(order.id.length - 6) : order.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(order.statusLabelAr),
                            if (order.notes.isNotEmpty)
                              Text(
                                order.notes,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${order.effectiveKmTotal.toStringAsFixed(1)} كم',
                      ),
                      if (order.manualBonusEgp > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '+${egp(order.manualBonusEgp)}',
                          style: const TextStyle(
                            color: GlassTokens.primaryBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _AdjustmentsSection extends StatefulWidget {
  const _AdjustmentsSection({
    required this.backend,
    required this.managerUid,
    required this.uid,
    required this.weekKey,
    required this.adjustments,
    required this.onChanged,
  });

  final ManagerBackend backend;
  final String managerUid;
  final String uid;
  final String weekKey;
  final List<Adjustment> adjustments;
  final VoidCallback onChanged;

  @override
  State<_AdjustmentsSection> createState() => _AdjustmentsSectionState();
}

class _AdjustmentsSectionState extends State<_AdjustmentsSection> {
  var _isBonus = true;
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final amount =
        double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    final error = validateAdjustment(amount: amount, reason: _reason.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.backend.addAdjustment(
        Adjustment(
          id: '',
          uid: widget.uid,
          type: _isBonus ? AdjustmentType.bonus : AdjustmentType.deduction,
          amount: amount!,
          reason: _reason.text.trim(),
          weekKey: widget.weekKey,
          createdBy: widget.managerUid,
          createdAtMillis: DateTime.now().millisecondsSinceEpoch,
        ),
        widget.managerUid,
      );
      _amount.clear();
      _reason.clear();
      widget.onChanged();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = [...widget.adjustments]
      ..sort((a, b) => b.createdAtMillis.compareTo(a.createdAtMillis));
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'تعديلات المدير (بونص / خصم)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (sorted.isEmpty)
            const Text('مفيش تعديلات لحد دلوقتي.')
          else
            for (final a in sorted)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${a.isBonus ? 'بونص' : 'خصم'}: ${a.reason} '
                        '(أسبوع ${a.weekKey})',
                      ),
                    ),
                    Text(
                      signedEgp(a.amount, isBonus: a.isBonus),
                      style: TextStyle(
                        color:
                            a.isBonus ? scheme.primary : scheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      key: ValueKey('deleteAdjustment-${a.id}'),
                      icon: const Icon(Icons.delete_rounded, size: 20),
                      onPressed: () async {
                        final confirmed = await showConfirmDialog(
                          context: context,
                          title: 'مسح التعديل؟',
                          body: 'التعديل هيتشال من مجموع الأسبوع.',
                          confirmLabel: 'مسح',
                        );
                        if (!confirmed) return;
                        await widget.backend.deleteAdjustment(
                          widget.uid,
                          a.id,
                        );
                        widget.onChanged();
                      },
                    ),
                  ],
                ),
              ),
          const Divider(),
          Row(
            children: [
              ChoiceChip(
                label: const Text('بونص'),
                selected: _isBonus,
                onSelected: (_) => setState(() => _isBonus = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('خصم'),
                selected: !_isBonus,
                onSelected: (_) => setState(() => _isBonus = false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'المبلغ (ج.م)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reason,
            decoration: const InputDecoration(
              labelText: 'السبب (مطلوب)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: scheme.error),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _add,
            child: const Text('إضافة التعديل'),
          ),
        ],
      ),
    );
  }
}

/// Edit-day dialog. Saves through the backend (which recomputes the
/// total, stamps the manager edit, and refreshes the rollup) and
/// pops `true` on success; the caller reloads.
class _EditDayDialog extends StatefulWidget {
  const _EditDayDialog({
    required this.backend,
    required this.uid,
    required this.managerUid,
    required this.initial,
    required this.dateKey,
  });

  final ManagerBackend backend;
  final String uid;
  final String managerUid;
  final DaySummary? initial;
  final String dateKey;

  @override
  State<_EditDayDialog> createState() => _EditDayDialogState();
}

class _EditDayDialogState extends State<_EditDayDialog> {
  late final TextEditingController _orders;
  late final TextEditingController _km;
  late final TextEditingController _price;
  late final TextEditingController _fixed;
  late final TextEditingController _distance;
  late final TextEditingController _manual;
  late final TextEditingController _flat;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    String num(double v) => v == v.truncateToDouble()
        ? v.toInt().toString()
        : v.toString();
    _orders = TextEditingController(text: '${s?.ordersCount ?? 0}');
    _km = TextEditingController(text: num(s?.totalKm ?? 0));
    _price = TextEditingController(text: num(s?.orderPrice ?? 0));
    _fixed = TextEditingController(text: num(s?.dailyFixedPay ?? 0));
    _distance = TextEditingController(text: num(s?.distanceBonus ?? 0));
    _manual = TextEditingController(text: num(s?.manualBonus ?? 0));
    _flat = TextEditingController(text: num(s?.flatBonus ?? 0));
  }

  @override
  void dispose() {
    _orders.dispose();
    _km.dispose();
    _price.dispose();
    _fixed.dispose();
    _distance.dispose();
    _manual.dispose();
    _flat.dispose();
    super.dispose();
  }

  double? _d(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل بيانات اليوم'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _orders,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'عدد الأوردرات'),
            ),
            TextField(
              controller: _km,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'إجمالي الكم'),
            ),
            TextField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'سعر الأوردر (ج.م)'),
            ),
            TextField(
              controller: _fixed,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'ثابت اليوم (ج.م)'),
            ),
            TextField(
              controller: _distance,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'بونص مسافة (ج.م)'),
            ),
            TextField(
              controller: _manual,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'بونص يدوي (ج.م)'),
            ),
            TextField(
              controller: _flat,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'بونص ثابت (ج.م)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () async {
            final orders = int.tryParse(_orders.text.trim());
            final km = _d(_km);
            final price = _d(_price);
            final fixed = _d(_fixed);
            final distance = _d(_distance);
            final manual = _d(_manual);
            final flat = _d(_flat);
            if (orders == null ||
                orders < 0 ||
                km == null ||
                km < 0 ||
                price == null ||
                price < 0 ||
                fixed == null ||
                fixed < 0 ||
                distance == null ||
                distance < 0 ||
                manual == null ||
                manual < 0 ||
                flat == null ||
                flat < 0) {
              setState(() => _error = 'أدخل أرقام صحيحة أكبر من أو تساوي صفر.');
              return;
            }
            try {
              await widget.backend.saveDaySummary(
                buildDaySummary(
                  uid: widget.uid,
                  dateKey: widget.dateKey,
                  ordersCount: orders,
                  totalKm: km,
                  orderPrice: price,
                  dailyFixedPay: fixed,
                  distanceBonus: distance,
                  manualBonus: manual,
                  flatBonus: flat,
                  updatedAtMillis:
                      DateTime.now().millisecondsSinceEpoch,
                ),
                widget.managerUid,
              );
            } catch (e) {
              if (mounted) setState(() => _error = e.toString());
              return;
            }
            if (!context.mounted) return;
            Navigator.pop(context, true);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

/// Full order detail — every field the driver sees on his side:
/// order number, status, address (notes), phone, km legs (manual +
/// GPS + effective, with يدوي badges), durations, lifecycle times,
/// manual bonus, count-only flag, creation/completion instants,
/// and recorded route point counts. No map in v1 (data fields are
/// all present; the map view is a later addition). Manager edit
/// covers notes / phone / km / bonus and rewrites the day record.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.onSaved,
  });

  final OrderEntry order;
  final Future<void> Function(OrderEntry updated) onSaved;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late OrderEntry _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _edit() async {
    final notes = TextEditingController(text: _order.notes);
    final phone = TextEditingController(text: _order.phone);
    final kmOut = TextEditingController(
      text: _order.effectiveKmOut.toString(),
    );
    final kmBack = TextEditingController(
      text: _order.effectiveKmBack.toString(),
    );
    final bonus = TextEditingController(
      text: _order.manualBonusEgp > 0
          ? _order.manualBonusEgp.toString()
          : '',
    );
    var error = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          return AlertDialog(
            title: const Text('تعديل الأوردر'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'العنوان / ملاحظات',
                    ),
                  ),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'تليفون العميل',
                    ),
                  ),
                  TextField(
                    controller: kmOut,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'كم الذهاب',
                    ),
                  ),
                  TextField(
                    controller: kmBack,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'كم العودة',
                    ),
                  ),
                  TextField(
                    controller: bonus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'بونص يدوي (ج.م)',
                    ),
                  ),
                  if (error.isNotEmpty)
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  final out =
                      double.tryParse(kmOut.text.trim());
                  final back =
                      double.tryParse(kmBack.text.trim());
                  final bText = bonus.text.trim();
                  final b = bText.isEmpty
                      ? 0.0
                      : double.tryParse(bText.replaceAll(',', '.'));
                  if (out == null ||
                      out < 0 ||
                      back == null ||
                      back < 0 ||
                      b == null ||
                      b < 0) {
                    setDialog(() => error = 'أدخل أرقام صحيحة.');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
    final out = double.tryParse(kmOut.text.trim()) ?? _order.kmOut;
    final back = double.tryParse(kmBack.text.trim()) ?? _order.kmBack;
    final bText = bonus.text.trim();
    final b = bText.isEmpty
        ? 0.0
        : (double.tryParse(bText.replaceAll(',', '.')) ??
            _order.manualBonusEgp);
    final newNotes = notes.text.trim();
    final newPhone = phone.text.trim();
    notes.dispose();
    phone.dispose();
    kmOut.dispose();
    kmBack.dispose();
    bonus.dispose();
    if (saved != true || !mounted) return;
    // Edited km becomes manual (GPS zeroed), same rule as the
    // driver-side edit sheet — so the يدوي badge shows.
    final updated = _order.copyWith(
      notes: newNotes,
      phone: newPhone,
      kmOut: out,
      kmBack: back,
      gpsKmOut: 0,
      gpsKmBack: 0,
      manualBonusEgp: b,
    );
    try {
      await widget.onSaved(updated);
      if (mounted) setState(() => _order = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final shortId =
        o.id.length > 6 ? o.id.substring(o.id.length - 6) : o.id;
    final totalSeconds = o.outgoingDurationSec + o.returnDurationSec;
    return Scaffold(
      appBar: AppBar(
        title: Text('أوردر #$shortId'),
        actions: [
          IconButton(
            key: const ValueKey('orderEdit'),
            icon: const Icon(Icons.edit_rounded),
            onPressed: _edit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: GlassTokens.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#$shortId — ${o.statusLabelAr}',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  InfoRow(
                    icon: Icons.location_on_rounded,
                    label: 'العنوان / ملاحظات',
                    value: o.notes,
                  ),
                  InfoRow(
                    icon: Icons.phone_rounded,
                    label: 'تليفون العميل',
                    value: o.phone,
                  ),
                  InfoRow(
                    icon: Icons.tag_rounded,
                    label: 'رقم الأوردر الكامل',
                    value: o.id,
                  ),
                  InfoRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'اليوم',
                    value: o.dateKey,
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
                    'المسافات',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ذهاب: ${o.effectiveKmOut.toStringAsFixed(2)} كم'
                    '${o.isManualOut ? ' (يدوي)' : ''} • '
                    'عودة: ${o.effectiveKmBack.toStringAsFixed(2)} كم'
                    '${o.isManualBack ? ' (يدوي)' : ''}',
                  ),
                  Text(
                    'إجمالي: ${o.effectiveKmTotal.toStringAsFixed(2)} كم',
                  ),
                  Text(
                    'GPS ذهاب: ${o.gpsKmOut.toStringAsFixed(2)} كم • '
                    'GPS عودة: ${o.gpsKmBack.toStringAsFixed(2)} كم',
                  ),
                  Text(
                    'يدوي ذهاب: ${o.kmOut.toStringAsFixed(2)} كم • '
                    'يدوي عودة: ${o.kmBack.toStringAsFixed(2)} كم',
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
                    'التوقيتات والمدد',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('بدأ التوصيل: ${_timeLabel(o.pickupTimeMillis)}'),
                  Text('وصل للعميل: ${_timeLabel(o.deliveredTimeMillis)}'),
                  Text(
                    'وصل للمارت: ${_timeLabel(o.martArrivedTimeMillis)}',
                  ),
                  Text(
                    'مدة الذهاب: ${_durationLabel(o.outgoingDurationSec)} • '
                    'مدة العودة: ${_durationLabel(o.returnDurationSec)} • '
                    'الإجمالي: ${_durationLabel(totalSeconds)}',
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
                    'مالية وحالة',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('بونص يدوي: ${egp(o.manualBonusEgp)}'),
                  Text(o.countOnly ? 'إدخال عددي فقط: نعم' : 'إدخال عددي فقط: لا'),
                  Text(
                    'اتعمل: ${_timeLabel(o.createdAtMillis == 0 ? null : o.createdAtMillis)} '
                    '• آخر تحديث: ${_timeLabel(o.timestampMillis)}',
                  ),
                  Text(
                    'نقاط المسار المسجلة: ${o.routePointCount} • '
                    'نقاط الطريق: ${o.roadOutLat.length + o.roadBackLat.length}',
                  ),
                  const Text(
                    'ملحوظة: الخريطة نفسها مش موجودة في نسخة '
                    'المدير الأولى — كل حقول البيانات موجودة هنا.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
