import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/team_provider.dart';
 
class InvitePlayerScreen extends ConsumerStatefulWidget {
  final String teamId;
 
  const InvitePlayerScreen({
    Key? key,
    required this.teamId,
  }) : super(key: key);
 
  @override
  ConsumerState<InvitePlayerScreen> createState() =>
      _InvitePlayerScreenState();
}
 
class _InvitePlayerScreenState extends ConsumerState<InvitePlayerScreen> {
  late TextEditingController _searchController;
  String _searchQuery = '';
 
  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }
 
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    final searchResults = _searchQuery.length >= 2
        ? ref.watch(searchUsersProvider(_searchQuery))
        : const AsyncValue.data([]);
 
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Players')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Search players...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: searchResults.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (err, stack) => Center(
                child: Text('Error: $err'),
              ),
              data: (players) {
                if (players.isEmpty) {
                  return const Center(
                    child: Text('No players found'),
                  );
                }
 
                return ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: player['photo_url'] != null
                            ? NetworkImage(player['photo_url'])
                            : null,
                        child: player['photo_url'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(player['name']),
                      subtitle: Text('@${player['username']}'),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(sendInvitationProvider({
                              'team_id': widget.teamId,
                              'receiver_id': player['id'],
                              'message': 'Join my team!',
                            }).future);
 
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Invitation sent!'),
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        child: const Text('Invite'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}