// Block tab — the blocked users list (name + blocked date).
// Tap → detail → Unblock with confirmation, restoring full access
// with data intact. Blocking itself happens from the team detail
// (never on swipe alone, never self); this tab is the home of the
// blocked list and the unblock path.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/diagnostics.dart';
import '../../core/week_utils.dart';
import '../../data/backend.dart';
import '../../data/models.dart';
import '../../widgets/confirm.dart';
import '../../widgets/glass.dart';
import '../../widgets/shimmer_skeleton.dart';

class BlockScreen extends StatefulWidget {
  const BlockScreen({
    super.key,
    required this.backend,
    required this.managerUid,
  });

  final ManagerBackend backend;
  final String managerUid;

  @override
  State<BlockScreen> createState() => _BlockScreenState();
}

class _BlockScreenState extends State<BlockScreen> {
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
    super.dispose();
  }

  /// Live blocked list. Re-attaching is the manual refresh fallback.
  void _subscribe() {
    _sub?.cancel();
    _liveError = null;
    _sub = widget.backend.watchUsers().listen(
      (users) {
        if (!mounted) return;
        final blocked = blockedUsers(users);
        blocked.sort((a, b) => b.blockedAt.compareTo(a.blockedAt));
        setState(() {
          _users = blocked;
          _loaded = true;
        });
      },
      onError: (Object e) {
        diagnosticsLog.add('live', 'block stream error: $e');
        if (!mounted) return;
        setState(
          () => _liveError =
              'الاتصال المباشر وقف. اضغط تحديث لإعادة الاتصال.',
        );
      },
    );
  }

  void _refresh() {
    setState(() => _liveError = null);
    _subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Block'),
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
              GlassCard(
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
            if (!_loaded)
              const ListSkeleton()
            else if (_users.isEmpty)
              const GlassCard(
                child: Text('مفيش حد محظور حاليًا.'),
              )
            else
              Column(
                children: [
                  for (final user in _users)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        onTap: () {
                          // Live list refreshes itself on return;
                          // no manual reload needed.
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BlockedDetailScreen(
                                backend: widget.backend,
                                managerUid: widget.managerUid,
                                account: user,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.redAccent,
                              child: Icon(
                                Icons.block_rounded,
                                color: Colors.white,
                                size: 20,
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
                                    user.blockedAt > 0
                                        ? 'محظور يوم ${arabicDayLabel(dateKeyOfMillis(user.blockedAt))}'
                                        : 'محظور',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
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

class BlockedDetailScreen extends StatelessWidget {
  const BlockedDetailScreen({
    super.key,
    required this.backend,
    required this.managerUid,
    required this.account,
  });

  final ManagerBackend backend;
  final String managerUid;
  final ManagerAccount account;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(account.displayName)),
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
                    account.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                  Text(
                    account.blockedAt > 0
                        ? 'محظور يوم ${arabicDayLabel(dateKeyOfMillis(account.blockedAt))}'
                        : 'محظور',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'داتاه كلها محفوظة — فك الحظر بيرجّعه كامل، '
                    'بنفس الأوردرات والأجور والتعديلات.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('blockedUnblock'),
              onPressed: () async {
                final confirmed = await showConfirmDialog(
                  context: context,
                  title: 'فك حظر ${account.displayName}؟',
                  body: 'هيرجع يسجل دخول بداتاه كاملة، ويرجع '
                      'يظهر في الفريق والأجور.',
                  confirmLabel: 'فك الحظر',
                  destructive: false,
                );
                if (!confirmed || !context.mounted) return;
                try {
                  await backend.setBlocked(
                    account.uid,
                    false,
                    managerUid,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل: $e')),
                    );
                  }
                }
              },
              child: const Text('فك الحظر'),
            ),
          ],
        ),
      ),
    );
  }
}
