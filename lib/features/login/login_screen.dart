// Sign-in screen (v1).
//
// ONE identifier field (username OR phone) + password, resolved
// through DeliveryFlow's lookup docs. Manager-role gate lives in
// the session, not here: a driver who signs in is signed straight
// back out with a plain "managers only" message.
// No sign-up, no invite gate, no Google sign-in in v1 — and never
// any shared, default, or hardcoded credential.

import 'package:flutter/material.dart';

import '../../widgets/glass.dart';
import '../session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _idController.text.trim();
    final pw = _pwController.text;
    if (id.isEmpty || pw.isEmpty) return;
    FocusScope.of(context).unfocus();
    await widget.session.signIn(id, pw);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final busy = session.status == SessionStatus.loading;
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: GlassTokens.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  const Icon(
                    Icons.manage_accounts_rounded,
                    size: 72,
                    color: GlassTokens.primaryBlue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Delivery Management',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تطبيق المديرين — نفس بيانات DeliveryFlow',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: const ValueKey('loginIdentifier'),
                          controller: _idController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'اسم المستخدم أو رقم التليفون',
                            prefixIcon: Icon(Icons.person_rounded),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey('loginPassword'),
                          controller: _pwController,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const ValueKey('loginSubmit'),
                          onPressed: busy ? null : _submit,
                          child: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('دخول'),
                        ),
                        if (session.status == SessionStatus.denied ||
                            session.status == SessionStatus.blocked ||
                            session.status ==
                                SessionStatus.mustChangePassword) ...[
                          const SizedBox(height: 12),
                          Text(
                            session.message,
                            key: const ValueKey('loginError'),
                            style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'الحسابات بتتعمل من DeliveryFlow وبتترقى لمدير '
                    'من هناك. مفيش إنشاء حساب من هنا.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
