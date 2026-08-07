import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Sign in')), body: Center(child: FilledButton.icon(
    onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.login), label: const Text('Continue with Google'),
  )));
}
