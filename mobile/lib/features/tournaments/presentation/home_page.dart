import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tournament_model.dart';
import 'providers/tournament_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(tournamentListProvider(const TournamentListFilter(status: TournamentStatus.published)));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(tournamentListProvider(const TournamentListFilter(status: TournamentStatus.published))),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8A5CFF), Color(0xFF39D0FF)]), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.sports_esports, color: Colors.white)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ArenaHub', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                  Text('Tournament battleground', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54)),
                ]),
                const Spacer(),
                IconButton(onPressed: () => context.push('/profile'), icon: const Icon(Icons.person_outline), color: Colors.white),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(colors: [Color(0xFF1B2140), Color(0xFF0F1730)]), border: Border.all(color: Colors.white12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Compete. Register. Win.', style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.05)),
                  const SizedBox(height: 10),
                  Text('Discover live tournaments, build your squad and register through the same rules controlled by the ArenaHub backend.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.45)),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: const [_Pill(label: 'Google Login'), _Pill(label: 'Team System'), _Pill(label: 'Ad Verification')]),
                  const SizedBox(height: 18),
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => context.push('/tournaments'), icon: const Icon(Icons.emoji_events_outlined), label: const Text('Explore tournaments'))),
                ]),
              ),
              const SizedBox(height: 24),
              Row(children: [Expanded(child: Text('Live tournaments', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900))), TextButton(onPressed: () => context.push('/tournaments'), child: const Text('View all'))]),
              const SizedBox(height: 8),
              tournaments.when(
                loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                error: (error, _) => _HomeError(message: error.toString()),
                data: (items) {
                  if (items.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Text('No published tournaments yet.', style: TextStyle(color: Colors.white54)));
                  return Column(children: items.take(4).map((item) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _TournamentPreview(tournament: item))).toList());
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _MiniCard(icon: Icons.groups_outlined, title: 'Teams', subtitle: 'Build your squad', onTap: () => context.push('/teams'))),
                const SizedBox(width: 12),
                Expanded(child: _MiniCard(icon: Icons.person_outline, title: 'Profile', subtitle: 'Manage player info', onTap: () => context.push('/profile'))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _TournamentPreview extends StatelessWidget {
  const _TournamentPreview({required this.tournament});
  final TournamentModel tournament;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () => context.push('/tournaments/${tournament.id}'),
    child: Ink(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF10182F), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)), child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF8A5CFF).withValues(alpha: .15), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.emoji_events_outlined, color: Color(0xFF8A5CFF))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tournament.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${tournament.game} • ${tournament.typeLabel}', style: const TextStyle(color: Colors.white60, fontSize: 12)), const SizedBox(height: 5), Text('${tournament.registeredTeams}/${tournament.totalSlots} teams • ${tournament.reward.isEmpty ? 'Reward TBA' : tournament.reward}', style: const TextStyle(color: Colors.white54, fontSize: 11))])),
      const Icon(Icons.chevron_right, color: Colors.white38),
    ])),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white10)), child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)));
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Ink(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .05), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: const Color(0xFF39D0FF)), const SizedBox(height: 10), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11))])));
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(16)), child: Text('Tournament feed unavailable: $message', style: const TextStyle(color: Colors.white54, fontSize: 12)));
}
