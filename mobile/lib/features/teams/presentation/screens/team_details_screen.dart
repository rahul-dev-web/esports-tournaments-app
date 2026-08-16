import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/auth_providers.dart';
import '../providers/team_provider.dart';
import 'invite_player_screen.dart';

class TeamDetailsScreen extends ConsumerWidget {
  final String teamId;

  const TeamDetailsScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamDetailsProvider(teamId));
    final membersAsync = ref.watch(teamMembersProvider(teamId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(teamDetailsProvider(teamId));
              ref.invalidate(teamMembersProvider(teamId));
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: teamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(error: error.toString()),
        data: (team) {
          final isCaptain = team['captain_id']?.toString() == currentUserId;
          final isPrivate = team['is_private'] == true;

          return membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(error: error.toString()),
            data: (members) {
              final isMember = members.any(
                (member) => member['id']?.toString() == currentUserId,
              );

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(teamDetailsProvider(teamId));
                  ref.invalidate(teamMembersProvider(teamId));
                  await ref.read(teamDetailsProvider(teamId).future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _TeamHero(team: team, memberCount: members.length),
                    const SizedBox(height: 16),
                    if (!isMember && !isPrivate)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.group_add_rounded),
                          label: const Text('Join Team'),
                          onPressed: () => _joinTeam(context, ref),
                        ),
                      ),
                    if (!isMember && isPrivate)
                      const _InfoBanner(
                        icon: Icons.lock_outline_rounded,
                        text: 'This is a private team. You can join only through a captain invitation.',
                      ),
                    if (isCaptain) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Invite Players'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => InvitePlayerScreen(teamId: teamId),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Edit Team'),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Team editor will be added in the next team polish pass.')),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Members',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text('${members.length} players'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...members.map(
                      (member) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: member['photo_url'] != null
                                ? NetworkImage(member['photo_url'].toString())
                                : null,
                            child: member['photo_url'] == null
                                ? const Icon(Icons.person_outline_rounded)
                                : null,
                          ),
                          title: Text(member['name']?.toString() ?? 'Player'),
                          subtitle: Text('@${member['username'] ?? 'player'}'),
                          trailing: member['is_captain'] == true
                              ? const Chip(label: Text('Captain'))
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _joinTeam(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(joinTeamProvider(teamId).future);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You joined the team successfully.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

class _TeamHero extends StatelessWidget {
  final Map<String, dynamic> team;
  final int memberCount;

  const _TeamHero({required this.team, required this.memberCount});

  @override
  Widget build(BuildContext context) {
    final isPrivate = team['is_private'] == true;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF18213D), Color(0xFF0D142A)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundImage: team['logo_url'] != null
                ? NetworkImage(team['logo_url'].toString())
                : null,
            child: team['logo_url'] == null
                ? const Icon(Icons.groups_rounded, size: 34)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team['name']?.toString() ?? 'Team',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(team['game']?.toString() ?? 'Esports'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(
                        isPrivate ? Icons.lock_outline : Icons.public,
                        size: 15,
                      ),
                      label: Text(isPrivate ? 'Private' : 'Open'),
                    ),
                    Chip(label: Text('$memberCount players')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;

  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(error, textAlign: TextAlign.center),
      ),
    );
  }
}
