import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/presentation/providers/profile_provider.dart';
import '../data/models/tournament_model.dart';
import 'providers/tournament_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(tournamentListProvider(const TournamentListFilter(status: TournamentStatus.published)));
    final profile = ref.watch(userProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tournamentListProvider(const TournamentListFilter(status: TournamentStatus.published)));
            ref.invalidate(userProfileProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF8A5CFF), Color(0xFF39D0FF)]),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ArenaHub', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                        const Text('Free Fire tournaments', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => context.push('/profile'),
                    icon: const Icon(Icons.person_outline_rounded, size: 22),
                    color: Colors.white70,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(colors: [Color(0xFF1C1740), Color(0xFF0D1B31)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(color: const Color(0x339B6CFF)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 30, height: 30, decoration: BoxDecoration(color: const Color(0x149B6CFF), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFBFA5FF), size: 17)),
                    const SizedBox(width: 9),
                    const Text('FREE FIRE', style: TextStyle(color: Color(0xFFC9B7FF), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  ]),
                  const SizedBox(height: 14),
                  Text('Compete. Register. Win.', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.05)),
                  const SizedBox(height: 7),
                  const Text('Find live tournaments, build your team and secure your slot.', style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 15),
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => context.push('/tournaments'), icon: const Icon(Icons.emoji_events_outlined, size: 19), label: const Text('Explore tournaments'))),
                ]),
              ),
              const SizedBox(height: 14),
              profile.maybeWhen(
                data: (data) {
                  final uid = (data['in_game_uid'] ?? '').toString().trim();
                  if (uid.isNotEmpty) return const SizedBox.shrink();
                  return _ProfileSetupCard(onTap: () => context.push('/profile/setup'));
                },
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: Text('Live tournaments', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900))),
                TextButton(onPressed: () => context.push('/tournaments'), child: const Text('View all')),
              ]),
              const SizedBox(height: 4),
              tournaments.when(
                loading: () => const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                error: (error, _) => _HomeError(message: error.toString()),
                data: (items) {
                  if (items.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No published tournaments yet.', style: TextStyle(color: Colors.white54)));
                  return Column(children: items.take(4).map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _TournamentPreview(tournament: item))).toList());
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _MiniCard(icon: Icons.groups_outlined, title: 'Teams', subtitle: 'Build your squad', onTap: () => context.push('/teams'))),
                const SizedBox(width: 10),
                Expanded(child: _MiniCard(icon: Icons.person_outline_rounded, title: 'Profile', subtitle: 'Player settings', onTap: () => context.push('/profile'))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSetupCard extends StatelessWidget {
  const _ProfileSetupCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF15132A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x559B6CFF)),
        ),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0x199B6CFF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.badge_outlined, color: Color(0xFFC9B7FF), size: 19)),
          const SizedBox(width: 11),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Finish your player profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            SizedBox(height: 3),
            Text('Set your in-game UID to unlock team and registration flows.', style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.35)),
          ])),
          TextButton(onPressed: onTap, child: const Text('Set up')),
        ]),
      );
}

class _TournamentPreview extends StatelessWidget {
  const _TournamentPreview({required this.tournament});
  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/tournaments/${tournament.id}'),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: const Color(0xFF10182F), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0x148A5CFF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.emoji_events_outlined, color: Color(0xFFBFA5FF), size: 19)),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tournament.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 4),
              Text('${tournament.game} • ${tournament.typeLabel}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 4),
              Text('${tournament.registeredTeams}/${tournament.totalSlots} teams • ${tournament.reward.isEmpty ? 'Reward TBA' : tournament.reward}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
          ]),
        ),
      );
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: Colors.white.withOpacity(.045), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
          child: Row(children: [
            Icon(icon, color: const Color(0xFF39D0FF), size: 19),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 9)),
            ])),
          ]),
        ),
      );
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withOpacity(.04), borderRadius: BorderRadius.circular(16)), child: Text('Tournament feed unavailable: $message', style: const TextStyle(color: Colors.white54, fontSize: 11)));
}
