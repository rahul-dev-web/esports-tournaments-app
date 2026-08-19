import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
    debugPrint('[APP AUTH 01] Google login button pressed');
    debugPrint('[APP AUTH 02] Platform: ${kIsWeb ? 'WEB' : 'MOBILE'}');
    debugPrint('[APP AUTH 03] Current URL: ${Uri.base}');
    debugPrint('[APP AUTH 04] Supabase URL configured: ${supabaseUrl.isNotEmpty}');

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      debugPrint('[APP AUTH ERROR] Supabase configuration is missing');
      _showMessage('Supabase is not configured for this build.');
      return;
    }

    setState(() => _signingIn = true);

    try {
      if (kIsWeb) {
        // Web keeps the normal Supabase OAuth flow.
        final redirectTo = Uri.base.origin;

        debugPrint('[APP AUTH WEB 01] OAuth redirectTo: $redirectTo');
        debugPrint('[APP AUTH WEB 02] Calling Supabase signInWithOAuth(Google)...');

        final result = await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectTo,
          authScreenLaunchMode: LaunchMode.platformDefault,
        );

        debugPrint('[APP AUTH WEB 03] signInWithOAuth returned: $result');
        debugPrint('[APP AUTH WEB 04] URL after OAuth call: ${Uri.base}');
        debugPrint('[APP AUTH WEB 05] Session after OAuth call: ${Supabase.instance.client.auth.currentSession != null}');
      } else {
        // Android/iOS use native Google Sign-In + Supabase ID-token auth.
        // This deliberately does NOT launch the Supabase OAuth browser flow,
        // so the native app does not depend on the custom callback URL to finish
        // Google sign-in.
        debugPrint('[APP AUTH MOBILE 01] Native Google Sign-In flow selected');
        debugPrint('[APP AUTH MOBILE 02] Google Web client ID: $googleWebClientId');
        debugPrint('[APP AUTH MOBILE 03] Google Android client ID: $googleAndroidClientId');
        debugPrint('[APP AUTH MOBILE 04] Package: com.arenahub.arenahub_mobile');
        debugPrint('[APP AUTH MOBILE 05] Initializing GoogleSignIn with serverClientId = Web client ID');

        final googleSignIn = GoogleSignIn.instance;
        await googleSignIn.initialize(serverClientId: googleWebClientId);

        debugPrint('[APP AUTH MOBILE 06] GoogleSignIn initialized');
        debugPrint('[APP AUTH MOBILE 07] Starting Google account authentication...');

        if (!googleSignIn.supportsAuthenticate()) {
          throw const AuthException(
            'Google Sign-In authentication is not supported on this platform.',
          );
        }

        final googleAccount = await googleSignIn.authenticate();

        debugPrint('[APP AUTH MOBILE 08] Google authentication completed');
        debugPrint('[APP AUTH MOBILE 09] Google email: ${googleAccount.email}');

        // google_sign_in 7.x separates authentication from authorization.
        // Supabase requires a Google access token in addition to the ID token,
        // so request the standard OpenID Connect profile scopes before calling
        // Supabase signInWithIdToken().
        const googleScopes = <String>[
          'https://www.googleapis.com/auth/userinfo.email',
          'https://www.googleapis.com/auth/userinfo.profile',
          'openid',
        ];

        debugPrint('[APP AUTH MOBILE 10] Requesting Google authorization for ${googleScopes.length} scopes');

        var googleAuthorization = await googleAccount.authorizationClient
            .authorizationForScopes(googleScopes);

        debugPrint('[APP AUTH MOBILE 11] Cached Google access token: ${googleAuthorization?.accessToken != null ? 'PRESENT' : 'MISSING'}');

        if (googleAuthorization == null || googleAuthorization.accessToken.isEmpty) {
          debugPrint('[APP AUTH MOBILE 12] Requesting Google authorization interactively...');
          googleAuthorization = await googleAccount.authorizationClient
              .authorizeScopes(googleScopes);
        }

        final googleAuthentication = googleAccount.authentication;
        final idToken = googleAuthentication.idToken;
        final accessToken = googleAuthorization.accessToken;

        debugPrint('[APP AUTH MOBILE 13] Final Google ID token: ${idToken != null ? 'PRESENT' : 'MISSING'}');
        debugPrint('[APP AUTH MOBILE 14] Final Google access token: ${accessToken.isNotEmpty ? 'PRESENT' : 'MISSING'}');

        if (idToken == null || idToken.isEmpty) {
          throw const AuthException('Google did not return an ID token.');
        }

        if (accessToken.isEmpty) {
          throw const AuthException('Google did not return an access token.');
        }

        debugPrint('[APP AUTH MOBILE 15] Sending Google tokens to Supabase signInWithIdToken...');

        final response = await Supabase.instance.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );

        debugPrint('[APP AUTH MOBILE 16] Supabase signInWithIdToken completed');
        debugPrint('[APP AUTH MOBILE 17] Supabase session: ${response.session != null ? 'FOUND' : 'NULL'}');
        debugPrint('[APP AUTH MOBILE 18] Supabase user ID: ${response.user?.id ?? 'NULL'}');
        debugPrint('[APP AUTH MOBILE 19] Supabase user email: ${response.user?.email ?? 'NULL'}');
      }
    } on GoogleSignInException catch (error, stackTrace) {
      debugPrint('[APP AUTH ERROR] GoogleSignInException: $error');
      debugPrint('[APP AUTH ERROR] Description: ${error.description}');
      debugPrint('[APP AUTH ERROR] Code: ${error.code}');
      debugPrint('[APP AUTH ERROR] StackTrace: $stackTrace');
      if (mounted) _showMessage('Google sign-in failed: ${error.description ?? error.code}');
    } on AuthException catch (error, stackTrace) {
      debugPrint('[APP AUTH ERROR] Supabase AuthException: ${error.message}');
      debugPrint('[APP AUTH ERROR] Status: ${error.statusCode}');
      debugPrint('[APP AUTH ERROR] StackTrace: $stackTrace');
      if (mounted) _showMessage('Google sign-in failed: ${error.message}');
    } catch (error, stackTrace) {
      debugPrint('[APP AUTH ERROR] Google sign-in failed: $error');
      debugPrint('[APP AUTH ERROR] StackTrace: $stackTrace');
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
      debugPrint('[APP AUTH 20] authProvider changed');
      debugPrint('[APP AUTH 21] Previous: $previous');
      debugPrint('[APP AUTH 22] Current: $next');

      if (next.hasError) {
        debugPrint('[APP AUTH ERROR] authProvider error: ${next.error}');
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
