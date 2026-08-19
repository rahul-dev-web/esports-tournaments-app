import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/profile_provider.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _uidController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _uidController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ref.read(userProfileProvider.future);
    if (!mounted) return;
    _nameController.text = (profile['name'] ?? '').toString();
    _usernameController.text = (profile['username'] ?? '').toString();
    _uidController.text = (profile['in_game_uid'] ?? '').toString();
    if (_uidController.text.trim().isNotEmpty) {
      Navigator.of(context).pop();
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadProfile);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await ref.read(updateProfileProvider({
        'in_game_uid': _uidController.text.trim(),
        if (_nameController.text.trim().isNotEmpty)
          'name': _nameController.text.trim(),
        if (_usernameController.text.trim().isNotEmpty)
          'username': _usernameController.text.trim(),
      }).future);

      ref.invalidate(userProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player profile completed successfully')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save profile: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A13),
      appBar: AppBar(title: const Text('Complete Player Profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.sports_esports_rounded, size: 64, color: Color(0xFF9B6CFF)),
              const SizedBox(height: 18),
              const Text(
                'Set your player identity',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your in-game UID is required before you can use player features. It can be set once and cannot be changed later.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.45),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _uidController,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'In-game UID / Game ID',
                  hintText: 'Enter your game ID',
                  prefixIcon: Icon(Icons.gamepad_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'In-game UID is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_saving ? 'Saving...' : 'Save Player Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
