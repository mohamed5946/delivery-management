// Application tab — the manager's OWN account area (NOT the team
// list). Same Arabic language as DeliveryFlow:
//   * manager profile + sign-in state
//   * a prominent "فريق العمل" entry → the standalone team screen
//   * account management: change password, explicit confirmed
//     sign-out
//   * app settings (theme) + diagnostics log entry
//   * Help & Support section mirroring DeliveryFlow's sheet —
//     same rows, all functional. ONE difference: the About row
//     shows THIS app's real version from package info (1.0.0+1
//     for v1), never DeliveryFlow's version.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/diagnostics.dart';
import '../../data/backend.dart';
import '../../data/models.dart';
import '../../widgets/confirm.dart';
import '../../widgets/glass.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../session.dart';
import '../settings.dart';
import '../team/team_screen.dart';

const _supportEmail = 'ma4670156@gmail.com';
const _contactNumber = '01557887719';
const _portfolioUrl = 'https://mohamed5946.github.io/portfolio/';

/// Fallback shown only when platform version info is unavailable
/// (never on a real device). Bump with pubspec on every release.
const _fallbackVersion = '1.0.0+1';

class ApplicationScreen extends StatefulWidget {
  const ApplicationScreen({
    super.key,
    required this.backend,
    required this.session,
    required this.settings,
  });

  final ManagerBackend backend;
  final SessionController session;
  final SettingsController settings;

  @override
  State<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends State<ApplicationScreen> {
  ManagerAccount? _account;
  StreamSubscription<ManagerAccount?>? _sub;

  @override
  void initState() {
    super.initState();
    _account = widget.session.account;
    final uid = widget.session.account?.uid;
    if (uid != null) {
      // Live profile: payout prefs / blocked flag changes land here
      // the moment they change. Errors fall back silently to the
      // session snapshot (the rest of the tab still works) and are
      // logged to diagnostics.
      _sub = widget.backend.watchAccount(uid).listen(
        (account) {
          if (!mounted || account == null) return;
          setState(() => _account = account);
        },
        onError: (Object e) {
          diagnosticsLog.add('live', 'application account stream: $e');
        },
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final backend = widget.backend;
    final settings = widget.settings;
    final account = _account ?? session.account!;
    return Scaffold(
      appBar: AppBar(title: const Text('Application')),
      body: SingleChildScrollView(
        padding: GlassTokens.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            GlassTokens.primaryBlue.withValues(alpha: 0.12),
                        child: Text(
                          account.displayName.isEmpty
                              ? '?'
                              : account.displayName[0],
                          style: const TextStyle(
                            color: GlassTokens.primaryBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const Text('مدير • مسجل دخول'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InfoRow(
                    icon: Icons.person_rounded,
                    label: 'اسم المستخدم',
                    value: account.username,
                  ),
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
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Prominent team entry — its own standalone screen.
            GlassCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TeamScreen(
                      backend: backend,
                      managerUid: account.uid,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color:
                          GlassTokens.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: GlassTokens.primaryBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'فريق العمل',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'كل الناس اللي شغالة معانا — سواقين ومديرين',
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ChangePasswordCard(session: session),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إعدادات التطبيق',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ListenableBuilder(
                    listenable: settings,
                    builder: (context, _) {
                      return SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('تلقائي'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('فاتح'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('داكن'),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (modes) {
                          settings.setThemeMode(modes.first);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    key: const ValueKey('applicationDiagnostics'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DiagnosticsScreen(),
                        ),
                      );
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.bug_report_rounded),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('سجل التشخيص'),
                              Text(
                                'كل الأحداث والأخطاء بأسبابها الحقيقية',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _HelpSupportSection(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('applicationSignOut'),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('تسجيل الخروج'),
              onPressed: () async {
                final confirmed = await showConfirmDialog(
                  context: context,
                  title: 'تسجيل الخروج؟',
                  body: 'هتخرج من حساب المدير، وهتحتاج تسجل '
                      'دخول تاني عشان ترجع.',
                  confirmLabel: 'تسجيل الخروج',
                  destructive: false,
                );
                if (confirmed && context.mounted) {
                  await session.signOut();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordCard extends StatefulWidget {
  const _ChangePasswordCard({required this.session});

  final SessionController session;

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  String? _error;
  String? _done;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _current.text;
    final next = _next.text;
    final confirm = _confirm.text;
    if (current.isEmpty || next.isEmpty) {
      setState(() => _error = 'املأ كل الحقول.');
      return;
    }
    if (next.length < 6) {
      setState(() => _error = 'كلمة المرور الجديدة لازم 6 حروف على الأقل.');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'كلمة المرور الجديدة مش مطابقة للتأكيد.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _done = null;
    });
    try {
      await widget.session.backend.changePassword(current, next);
      await widget.session.refreshAccount();
      if (!mounted) return;
      setState(() {
        _done = 'تم تغيير كلمة المرور.';
        _current.clear();
        _next.clear();
        _confirm.clear();
      });
    } catch (e) {
      diagnosticsLog.add('account', 'changePassword failed: $e');
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'تغيير كلمة المرور',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'كلمة المرور الحالية',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'تأكيد كلمة المرور الجديدة',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_done != null) ...[
            const SizedBox(height: 8),
            Text(
              _done!,
              style: const TextStyle(color: Colors.green),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('تغيير كلمة المرور'),
          ),
        ],
      ),
    );
  }
}

/// Help & Support — mirrors DeliveryFlow's sheet, same rows, all
/// functional. The About row reads THIS app's real version from
/// package info (never DeliveryFlow's version).
class _HelpSupportSection extends StatelessWidget {
  const _HelpSupportSection();

  Future<String> _version() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return _fallbackVersion;
    }
  }

  Future<void> _openMail(BuildContext context) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse('mailto:$_supportEmail'));
    } catch (_) {
      ok = false;
    }
    if (ok || !context.mounted) return;
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الإيميل')),
    );
  }

  Future<void> _openPortfolio(BuildContext context) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(_portfolioUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (ok || !context.mounted) return;
    await Clipboard.setData(const ClipboardData(text: _portfolioUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الرابط')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المساعدة والدعم',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: _version(),
            builder: (context, snap) {
              return InfoRow(
                icon: Icons.info_rounded,
                label: 'عن التطبيق',
                value: snap.data ?? _fallbackVersion,
              );
            },
          ),
          const SizedBox(height: 4),
          const InfoRow(
            icon: Icons.brush_rounded,
            label: 'تصميم',
            value: 'eng/Mohamed El Sayed',
          ),
          const SizedBox(height: 4),
          InfoRow(
            icon: Icons.email_rounded,
            label: 'الإيميل',
            value: _supportEmail,
            onTap: () => _openMail(context),
          ),
          const SizedBox(height: 4),
          const InfoRow(
            icon: Icons.phone_rounded,
            label: 'التواصل',
            value: _contactNumber,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('helpCallUs'),
            icon: const Icon(Icons.call_rounded),
            label: const Text('اتصل بنا'),
            onPressed: () => launchUrl(Uri.parse('tel:$_contactNumber')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('helpPortfolio'),
            icon: const Icon(Icons.language_rounded),
            label: const Text('الموقع الشخصي'),
            onPressed: () => _openPortfolio(context),
          ),
        ],
      ),
    );
  }
}
