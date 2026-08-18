import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _signingIn = false;

  Future<void> _signIn() async {
debugPrint('[AUTH_DEBUG] ===== GOOGLE SIGN-IN START =====');
debugPrint('[AUTH_DEBUG] platform=${defaultTargetPlatform.name}');
debugPrint('[AUTH_DEBUG] supabaseConfigured=${supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty}');
debugPrint('[AUTH_DEBUG] supabaseUrl=$supabaseUrl');
debugPrint('[AUTH_DEBUG] oauthRedirectUrl=$oauthRedirectUrl');
debugPrint('[AUTH_DEBUG] currentSessionBefore=${Supabase.instance.client.auth.currentSession != null}');

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      debugPrint('[AUTH_DEBUG] ERROR: Supabase is not configured.');
      _showMessage('Supabase is not configured for this build.');
      return;
    }

    setState(() => _signingIn = true);

    try {
      final result = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: oauthRedirectUrl,
      );

      debugPrint('[AUTH_DEBUG] signInWithOAuth returned=$result');
      debugPrint('[AUTH_DEBUG] currentSessionImmediatelyAfter=${Supabase.instance.client.auth.currentSession != null}');
      debugPrint('[AUTH_DEBUG] ===== GOOGLE SIGN-IN BROWSER OPENED =====');
    } catch (error, stackTrace) {
      debugPrint('[AUTH_DEBUG] SIGN-IN EXCEPTION: $error');
      debugPrint('[AUTH_DEBUG] STACK: $stackTrace');
      if (mounted) _showMessage('Google sign-in failed: $error');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      debugPrint('[AUTH_DEBUG] authProvider changed: previous=${previous?.runtimeType}, next=${next.runtimeType}');
      if (next.hasError) {
        debugPrint('[AUTH_DEBUG] authProvider error=${next.error}');
        _showMessage('Account setup failed. Please try again.');
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 76,
                    width: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [ArenaTheme.primary, ArenaTheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 28, offset: Offset(0, 12)),
                      ],
                    ),
                    child: const Icon(Icons.sports_esports_rounded, size: 40),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'ENTER THE ARENA',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Compete. Build your squad. Track every tournament from one place.',
                    style: TextStyle(color: Colors.white60, height: 1.5, fontSize: 15),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Player Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          const Text('Use your Google account to continue.', style: TextStyle(color: Colors.white54)),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _signingIn ? null : _signIn,
                            icon: _signingIn
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.account_circle_rounded),
                            label: Text(_signingIn ? 'Opening Google...' : 'Continue with Google'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'By continuing, you agree to use the account associated with your tournament profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
