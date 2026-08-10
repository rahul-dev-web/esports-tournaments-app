import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/team_provider.dart';
import 'create_team_screen.dart';
import 'team_details_screen.dart';
 
class TeamsListScreen extends ConsumerWidget {
  const TeamsListScreen({Key? key}) : super(key: key);
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamsProvider(null));
 
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateTeamScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (teams) {
          if (teams.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No teams yet'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const CreateTeamScreen(),
                        ),
                      );
                    },
                    child: const Text('Create Team'),
                  ),
                ],
              ),
            );
          }
 
          return ListView.builder(
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final team = teams[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: team['logo_url'] != null
                        ? NetworkImage(team['logo_url'])
                        : null,
                    child: team['logo_url'] == null
                        ? const Icon(Icons.groups)
                        : null,
                  ),
                  title: Text(team['name']),
                  subtitle: Text(
                    '${team['game']} • ${(team['member_ids'] as List?)?.length ?? 0} members',
                  ),
                  trailing: Icon(
                    team['is_private'] ? Icons.lock : Icons.public,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TeamDetailsScreen(
                          teamId: team['id'],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
 