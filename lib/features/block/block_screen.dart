// Block tab — the blocked users list (name + blocked date).
// Tap → detail → Unblock with confirmation, restoring full access
// with data intact. Blocking itself happens from the team detail
// (never on swipe alone, never self); this tab is the home of the
// blocked list and the unblock path.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/diagnostics.dart';
import '../../core/strings.dart';
import '../../core/week_utils.dart';
import '../../data/backend.dart';
import '../../data/models.dart';
import '../../widgets/confirm.dart';
import '../../theme/dm_theme.dart';
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
          () => _liveError = DmStrings.of(context).liveStoppedGeneric,
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
    final s = DmStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.blockTitle),
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
                      child: Text(s.reconnect),
                    ),
                  ],
                ),
              ),
            if (!_loaded)
              const ListSkeleton()
            else if (_users.isEmpty)
              GlassCard(
                child: Text(s.noBlockedNow),
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
                                        ? s.blockedDay(s.dayLabel(dateKeyOfMillis(user.blockedAt)))
                                        : s.blockedLabel,
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
    final s = DmStrings.of(context);
    // DmPage: see TeamScreen — pushed routes need the aurora behind
    // the page itself or they render black.
    return DmPage(
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
                    label: s.phoneLabel,
                    value: account.phone,
                  ),
                  InfoRow(
                    icon: Icons.email_rounded,
                    label: s.emailLabel,
                    value: account.email,
                  ),
                  Text(
                    account.blockedAt > 0
                        ? s.blockedDay(s.dayLabel(dateKeyOfMillis(account.blockedAt)))
                        : s.blockedLabel,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.blockDataKept,
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
                  title: s.unblockTitle(account.displayName),
                  body: s.unblockDetailBody,
                  confirmLabel: s.unblockAction,
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
                      SnackBar(content: Text(s.failed(s.localizeError(e)))),
                    );
                  }
                }
              },
              child: Text(s.unblockAction),
            ),
          ],
        ),
      ),
    );
  }
}
