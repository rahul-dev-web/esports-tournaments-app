import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/team_provider.dart';
import 'invite_player_screen.dart';
 
class TeamDetailsScreen extends ConsumerWidget {
  final String teamId;
 
  const TeamDetailsScreen({
    Key? key,
    required this.teamId,
  }) : super(key: key);
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamDetailsProvider(teamId));
    final membersAsync = ref.watch(teamMembersProvider(teamId));
    final currentUserId = ref.watch(currentUserIdProvider);
 
    return Scaffold(
      appBar: AppBar(title: const Text('Team Details')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team header
            teamAsync.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (team) {
                final isCaptain = team['captain_id'] == currentUserId;
 
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: team['logo_url'] != null
                                ? NetworkImage(team['logo_url'])
                                : null,
                            child: team['logo_url'] == null
                                ? const Icon(Icons.groups, size: 40)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  team['name'],
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Text(team['game']),
                                Text(
                                  team['is_private'] ? 'Private' : 'Open',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (isCaptain) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      InvitePlayerScreen(teamId: teamId),
                                ),
                              );
                            },
                            child: const Text('Invite Players'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              // Edit team
                            },
                            child: const Text('Edit Team'),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Members',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            // Members list
            membersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $err'),
              ),
              data: (members) {
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: member['photo_url'] != null
                            ? NetworkImage(member['photo_url'])
                            : null,
                        child: member['photo_url'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(member['name']),
                      subtitle: Text('@${member['username']}'),
                      trailing: member['is_captain']
                          ? const Chip(label: Text('Captain'))
                          : null,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}