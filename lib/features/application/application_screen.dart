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
import '../../core/strings.dart';
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
      appBar: AppBar(title: Text(DmStrings.of(context).applicationTitle)),
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
                            Text(DmStrings.of(context).managerSignedIn),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InfoRow(
                    icon: Icons.person_rounded,
                    label: DmStrings.of(context).usernameLabel,
                    value: account.username,
                  ),
                  InfoRow(
                    icon: Icons.phone_rounded,
                    label: DmStrings.of(context).phoneLabel,
                    value: account.phone,
                  ),
                  InfoRow(
                    icon: Icons.email_rounded,
                    label: DmStrings.of(context).emailLabel,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DmStrings.of(context).teamTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          DmStrings.of(context).teamEntrySubtitle,
                        ),
                      ],
                    ),
                  ),
                  Icon(DmStrings.of(context).isArabic
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded),
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
                    DmStrings.of(context).appSettingsTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ListenableBuilder(
                    listenable: settings,
                    builder: (context, _) {
                      final s = DmStrings.of(context);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<ThemeMode>(
                            segments: [
                              ButtonSegment(
                                value: ThemeMode.system,
                                label: Text(s.themeAuto),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                label: Text(s.themeLight),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                label: Text(s.themeDark),
                              ),
                            ],
                            selected: {settings.themeMode},
                            onSelectionChanged: (modes) {
                              settings.setThemeMode(modes.first);
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.languageTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<Locale>(
                            segments: [
                              ButtonSegment(
                                value: const Locale('ar'),
                                label: Text(s.languageArabic),
                              ),
                              ButtonSegment(
                                value: const Locale('en'),
                                label: Text(s.languageEnglish),
                              ),
                            ],
                            selected: {settings.locale},
                            onSelectionChanged: (locales) {
                              settings.setLocale(locales.first);
                            },
                          ),
                        ],
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
                    child: Row(
                      children: [
                        Icon(Icons.bug_report_rounded),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DmStrings.of(context).diagnosticsTitle),
                              Text(
                                DmStrings.of(context).diagnosticsSubtitle,
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
              label: Text(DmStrings.of(context).signOut),
              onPressed: () async {
                final confirmed = await showConfirmDialog(
                  context: context,
                  title: DmStrings.of(context).signOutQ,
                  body: DmStrings.of(context).signOutBody,
                  confirmLabel: DmStrings.of(context).signOut,
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
    final s = DmStrings.of(context);
    if (current.isEmpty || next.isEmpty) {
      setState(() => _error = s.fillAllFields);
      return;
    }
    if (next.length < 6) {
      setState(() => _error = s.passwordMinLength);
      return;
    }
    if (next != confirm) {
      setState(() => _error = s.passwordMismatch);
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
        _done = DmStrings.of(context).passwordChanged;
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
    final s = DmStrings.of(context);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.changePasswordTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _current,
            obscureText: true,
            decoration: InputDecoration(
              labelText: s.currentPasswordLabel,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _next,
            obscureText: true,
            decoration: InputDecoration(
              labelText: s.newPasswordLabel,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: InputDecoration(
              labelText: s.confirmPasswordLabel,
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              s.localizeError(_error!),
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
                : Text(s.changePasswordTitle),
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
      SnackBar(content: Text(DmStrings.of(context).emailCopied)),
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
      SnackBar(content: Text(DmStrings.of(context).linkCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DmStrings.of(context).helpSupportTitle,
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
                label: DmStrings.of(context).aboutApp,
                value: snap.data ?? _fallbackVersion,
              );
            },
          ),
          const SizedBox(height: 4),
          InfoRow(
            icon: Icons.brush_rounded,
            label: DmStrings.of(context).designedBy,
            value: 'eng/Mohamed El Sayed',
          ),
          const SizedBox(height: 4),
          InfoRow(
            icon: Icons.email_rounded,
            label: DmStrings.of(context).emailLabel,
            value: _supportEmail,
            onTap: () => _openMail(context),
          ),
          const SizedBox(height: 4),
          InfoRow(
            icon: Icons.phone_rounded,
            label: DmStrings.of(context).contactLabel,
            value: _contactNumber,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('helpCallUs'),
            icon: const Icon(Icons.call_rounded),
            label: Text(DmStrings.of(context).callUs),
            onPressed: () => launchUrl(Uri.parse('tel:$_contactNumber')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('helpPortfolio'),
            icon: const Icon(Icons.language_rounded),
            label: Text(DmStrings.of(context).personalWebsite),
            onPressed: () => _openPortfolio(context),
          ),
        ],
      ),
    );
  }
}
