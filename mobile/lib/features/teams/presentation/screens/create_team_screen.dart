import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/team_provider.dart';
 
class CreateTeamScreen extends ConsumerStatefulWidget {
  const CreateTeamScreen({Key? key}) : super(key: key);
 
  @override
  ConsumerState<CreateTeamScreen> createState() => _CreateTeamScreenState();
}
 
class _CreateTeamScreenState extends ConsumerState<CreateTeamScreen> {
  late TextEditingController _nameController;
  late TextEditingController _gameController;
  bool _isPrivate = false;
  bool _isLoading = false;
 
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _gameController = TextEditingController();
  }
 
  @override
  void dispose() {
    _nameController.dispose();
    _gameController.dispose();
    super.dispose();
  }
 
  Future<void> _createTeam() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team name is required')),
      );
      return;
    }
 
    setState(() => _isLoading = true);
 
    try {
      await ref.read(createTeamProvider({
        'name': _nameController.text,
        'game': _gameController.text,
        'is_private': _isPrivate,
        'logo_url': null,
      }).future);
 
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team created successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Team')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Team Name',
                border: OutlineInputBorder(),
                hintText: 'My Team',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _gameController,
              decoration: const InputDecoration(
                labelText: 'Game',
                border: OutlineInputBorder(),
                hintText: 'e.g., CS:GO, Valorant, DOTA2',
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Private Team'),
              subtitle: const Text('Only invited players can join'),
              value: _isPrivate,
              onChanged: (value) {
                setState(() => _isPrivate = value ?? false);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _createTeam,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Team'),
            ),
          ],
        ),
      ),
    );
  }
}
 