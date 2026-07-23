import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeStep = false;
  bool _loading = false;
  String? _error;

  Future<void> _send() async {
    setState(() { _error = null; _loading = true; });
    try {
      await Api.sendOtp(_email.text.trim());
      setState(() => _codeStep = true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    setState(() { _error = null; _loading = true; });
    try {
      await Api.verifyOtp(_email.text.trim(), _code.text.trim());
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Text('🐾', textAlign: TextAlign.center, style: TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                const Text('PAWD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: PawdColors.brand,
                        letterSpacing: -1)),
                const SizedBox(height: 4),
                const Text('Find your pet a friend nearby.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: PawdColors.inkSoft)),
                const SizedBox(height: 28),
                if (_error != null) ...[
                  _ErrorBanner(_error!),
                  const SizedBox(height: 12),
                ],
                if (!_codeStep) ...[
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        labelText: 'Email address', hintText: 'you@example.com'),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _loading || _email.text.isEmpty ? null : _send,
                    child: Text(_loading ? 'Sending…' : 'Send login code'),
                  ),
                  const SizedBox(height: 10),
                  const Text("We'll email you a 6-digit code. No password needed.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PawdColors.inkSoft, fontSize: 13)),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: PawdColors.brandSoft,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('Code sent to ${_email.text.trim()}. Check your inbox.',
                        style: const TextStyle(
                            color: PawdColors.brand, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofillHints: const [AutofillHints.oneTimeCode],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Login code', hintText: 'Code from your email'),
                  ),
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: _loading || _code.text.length < 6 ? null : _verify,
                    child: Text(_loading ? 'Verifying…' : 'Verify & continue'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => setState(() { _codeStep = false; _code.clear(); _error = null; }),
                    child: const Text('Use a different email'),
                  ),
                ],
                const SizedBox(height: 24),
                const Text('By continuing you confirm you are 18+ and agree to meet responsibly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: PawdColors.inkSoft, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: PawdColors.danger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PawdColors.danger.withValues(alpha: 0.3))),
        child: Text(text, style: const TextStyle(color: PawdColors.danger, fontSize: 14)),
      );
}
