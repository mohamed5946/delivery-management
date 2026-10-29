// Delivery Management v1 — manager-only companion to DeliveryFlow.
//
// Same Firebase project, same Firestore data, manager accounts
// only. Arabic UI (Egyptian, masculine forms), RTL.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/diagnostics.dart';
import 'data/backend.dart';
import 'data/firebase_options.dart';
import 'features/login/login_screen.dart';
import 'features/session.dart';
import 'features/settings.dart';
import 'features/shell.dart';
import 'theme/dm_theme.dart';
import 'widgets/glass.dart';
import 'widgets/shimmer_skeleton.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Only a successful initializeApp makes the real backend safe to
  // construct: FirestoreManagerBackend's constructor reads
  // FirebaseAuth.instance, which throws when no Firebase app exists.
  // v1.0.0 constructed it unconditionally before runApp while init
  // was skipped (placeholders), so the throw happened before any
  // Flutter frame and the Android launch splash stayed forever.
  // Never again: the real backend is constructed ONLY after init
  // succeeds; otherwise the app runs on UnconfiguredBackend and
  // reaches a readable login screen with a plain message.
  bool firebaseReady = false;
  if (DefaultFirebaseOptions.isConfigured) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseReady = true;
    } catch (e) {
      diagnosticsLog.add('init', 'Firebase init failed: $e');
    }
  } else {
    diagnosticsLog.add(
      'init',
      'Firebase not configured: placeholders in '
          'lib/data/firebase_options.dart.',
    );
  }
  final settings = SettingsController();
  await settings.load();
  runApp(
    DeliveryManagementApp(
      backend: firebaseReady
          ? FirestoreManagerBackend()
          : const UnconfiguredBackend(),
      settings: settings,
      firebaseReady: firebaseReady,
    ),
  );
}

/// Testable app root: tests inject a [FakeManagerBackend] and a
/// fresh [SessionController]/[SettingsController].
class DeliveryManagementApp extends StatefulWidget {
  const DeliveryManagementApp({
    super.key,
    required this.backend,
    required this.settings,
    this.session,
    this.firebaseReady = true,
  });

  final ManagerBackend backend;
  final SettingsController settings;
  final SessionController? session;

  /// False when Firebase never initialized: the app still runs, but
  /// the login screen says plainly that sign-in cannot work yet.
  final bool firebaseReady;

  @override
  State<DeliveryManagementApp> createState() => _DeliveryManagementAppState();
}

class _DeliveryManagementAppState extends State<DeliveryManagementApp> {
  late final SessionController _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session ?? SessionController(widget.backend);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _session.restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Delivery Management',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar'), Locale('en')],
          themeMode: widget.settings.themeMode,
          // DeliveryFlow's theme (default preset), ported — not a
          // generic Material seed theme.
          theme: DmTheme.light(),
          darkTheme: DmTheme.dark(),
          // DeliveryFlow's shell pattern: the aurora background sits
          // behind every screen (all Scaffolds are transparent).
          home: Stack(
            children: [
              const DmAuroraBackground(),
              ListenableBuilder(
                listenable: _session,
                builder: (context, _) {
                  switch (_session.status) {
                    case SessionStatus.loading:
                      return const Scaffold(
                        body: SingleChildScrollView(
                          padding: GlassTokens.screenPadding,
                          child: DashboardSkeleton(),
                        ),
                      );
                    case SessionStatus.ready:
                      return ManagerShell(
                        backend: widget.backend,
                        session: _session,
                        settings: widget.settings,
                      );
                    case SessionStatus.signedOut:
                    case SessionStatus.denied:
                    case SessionStatus.blocked:
                    case SessionStatus.mustChangePassword:
                      return LoginScreen(
                        session: _session,
                        firebaseReady: widget.firebaseReady,
                      );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
