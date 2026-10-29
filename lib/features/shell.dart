// The 4-tab shell (manager-only — the session gate runs before
// this screen ever appears).
//
// Tabs (bottom bar, in order):
//   1. Dashboard            — لوحة التحكم
//   2. الأجور الأسبوعية     — weekly payroll
//   3. Application          — the manager's OWN account area
//   4. Block                — blocked users
// The team lives in the Application tab as a prominent "فريق العمل"
// entry opening its own standalone screen — never mixed into the
// payroll tab.

import 'package:flutter/material.dart';

import '../data/backend.dart';
import '../theme/dm_theme.dart';
import 'application/application_screen.dart';
import 'block/block_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'payroll/payroll_screen.dart';
import 'session.dart';
import 'settings.dart';

class ManagerShell extends StatefulWidget {
  const ManagerShell({
    super.key,
    required this.backend,
    required this.session,
    required this.settings,
  });

  final ManagerBackend backend;
  final SessionController session;
  final SettingsController settings;

  @override
  State<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<ManagerShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final account = widget.session.account!;
    final screens = [
      DashboardScreen(
        key: const ValueKey('tabDashboard'),
        backend: widget.backend,
        session: widget.session,
      ),
      PayrollScreen(
        key: const ValueKey('tabPayroll'),
        backend: widget.backend,
        managerUid: account.uid,
      ),
      ApplicationScreen(
        key: const ValueKey('tabApplication'),
        backend: widget.backend,
        session: widget.session,
        settings: widget.settings,
      ),
      BlockScreen(
        key: const ValueKey('tabBlock'),
        backend: widget.backend,
        managerUid: account.uid,
      ),
    ];
    // DeliveryFlow's shell pattern: the floating glass nav bar is an
    // overlay above the content (not in the bottomNavigationBar
    // slot), and the aurora background extends edge-to-edge behind
    // it. Content gets bottom padding so nothing hides under the bar.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 96 + bottomInset),
            child: IndexedStack(index: _index, children: screens),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: DmGlassNavBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              icons: const [
                Icons.dashboard_rounded,
                Icons.payments_rounded,
                Icons.apps_rounded,
                Icons.block_rounded,
              ],
              labels: const [
                'Dashboard',
                'الأجور الأسبوعية',
                'Application',
                'Block',
              ],
            ),
          ),
        ],
      ),
    );
  }
}
