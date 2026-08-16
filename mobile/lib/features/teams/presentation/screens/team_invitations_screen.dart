import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/team_provider.dart';

class TeamInvitationsScreen extends ConsumerWidget {
  const TeamInvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(receivedInvitationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Invites'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(receivedInvitationsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(receivedInvitationsProvider.future),
        child: invitationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Could not load invitations',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(receivedInvitationsProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
          data: (invitations) {
            if (invitations.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                children: const [
                  Icon(Icons.mark_email_read_outlined, size: 56),
                  SizedBox(height: 16),
                  Text(
                    'No pending invites',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'When a captain invites you to a team, it will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: invitations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final invite = invitations[index];
                final team = Map<String, dynamic>.from(invite['team'] ?? const {});
                final sender = Map<String, dynamic>.from(invite['sender'] ?? const {});
                final invitationId = invite['id']?.toString();
                if (invitationId == null) return const SizedBox.shrink();

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8A5CFF), Color(0xFF39D0FF)],
                                ),
                              ),
                              child: const Icon(Icons.groups_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    team['name']?.toString() ?? 'Team invite',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 3),
                                  Text('${team['game'] ?? 'Esports'} • Invited by ${sender['name'] ?? 'Captain'}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if ((invite['message']?.toString() ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            '“${invite['message']}”',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _reject(context, ref, invitationId),
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _accept(context, ref, invitationId),
                                child: const Text('Join Team'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref, String invitationId) async {
    try {
      await ref.read(acceptInvitationProvider(invitationId).future);
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

  Future<void> _reject(BuildContext context, WidgetRef ref, String invitationId) async {
    try {
      await ref.read(rejectInvitationProvider(invitationId).future);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation declined.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}
