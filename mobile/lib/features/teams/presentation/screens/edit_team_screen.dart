import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/team_provider.dart';

class EditTeamScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> team;

  const EditTeamScreen({super.key, required this.team});

  @override
  ConsumerState<EditTeamScreen> createState() => _EditTeamScreenState();
}

class _EditTeamScreenState extends ConsumerState<EditTeamScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _gameController;
  late final TextEditingController _logoController;
  late bool _isPrivate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.team['name']?.toString() ?? '');
    _gameController = TextEditingController(text: widget.team['game']?.toString() ?? '');
    _logoController = TextEditingController(text: widget.team['logo_url']?.toString() ?? '');
    _isPrivate = widget.team['is_private'] == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gameController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final game = _gameController.text.trim();
    if (name.length < 2 || game.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid team name and game.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await ref.read(updateTeamProvider({
        'team_id': widget.team['id'].toString(),
        'name': name,
        'game': game,
        'is_private': _isPrivate,
        'logo_url': _logoController.text.trim().isEmpty ? null : _logoController.text.trim(),
      }).future);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Team')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Team name', prefixIcon: Icon(Icons.groups_rounded)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _gameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Game', prefixIcon: Icon(Icons.sports_esports_rounded)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _logoController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Logo URL (optional)', prefixIcon: Icon(Icons.image_outlined)),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Private team'),
            subtitle: const Text('Only invited players can join.'),
            value: _isPrivate,
            onChanged: (value) => setState(() => _isPrivate = value),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving...' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
