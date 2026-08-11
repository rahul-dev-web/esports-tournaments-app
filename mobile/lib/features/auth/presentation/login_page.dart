import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sign in')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () async {
              if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Supabase env vars are not configured')),
                );
                return;
              }

              try {
                await Supabase.instance.client.auth.signInWithOAuth(
                  OAuthProvider.google,
                  redirectTo: oauthRedirectUrl,
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Login failed: $e')),
                );
              }
            },
            icon: const Icon(Icons.login),
            label: const Text('Continue with Google'),
          ),
        ),
      );
}
