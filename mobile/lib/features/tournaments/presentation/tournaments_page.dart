import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tournament_model.dart';
import 'providers/tournament_provider.dart';

class TournamentsPage extends ConsumerStatefulWidget {
  const TournamentsPage({super.key});

  @override
  ConsumerState<TournamentsPage> createState() => _TournamentsPageState();
}

class _TournamentsPageState extends ConsumerState<TournamentsPage> {
  TournamentStatus? _status;
  String? _game;

  @override
  Widget build(BuildContext context) {
    final filter = TournamentListFilter(game: _game, status: _status);
    final tournaments = ref.watch(tournamentListProvider(filter));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        title: const Text('Tournaments'),
        backgroundColor: const Color(0xFF070B18),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(tournamentListProvider(filter)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Text('Find your next battleground', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Live data from the ArenaHub backend.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60)),
            const SizedBox(height: 18),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(label: 'All', selected: _status == null, onTap: () => setState(() => _status = null)),
                  _FilterChip(label: 'Upcoming', selected: _status == TournamentStatus.published, onTap: () => setState(() => _status = TournamentStatus.published)),
                  _FilterChip(label: 'Closed', selected: _status == TournamentStatus.closed, onTap: () => setState(() => _status = TournamentStatus.closed)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            tournaments.when(
              loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
              error: (error, _) => _ErrorState(message: error.toString(), onRetry: () => ref.invalidate(tournamentListProvider(filter))),
              data: (items) {
                if (items.isEmpty) return const _EmptyState();
                return Column(children: items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TournamentCard(tournament: item),
                )).toList());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.tournament});
  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final remaining = (tournament.totalSlots - tournament.registeredTeams).clamp(0, tournament.totalSlots);
    final progress = tournament.totalSlots == 0 ? 0.0 : (tournament.registeredTeams / tournament.totalSlots).clamp(0.0, 1.0);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => context.push('/tournaments/${tournament.id}'),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF10182F),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(tournament.name, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900))),
            _StatusBadge(status: tournament.status),
          ]),
          const SizedBox(height: 8),
          Text('${tournament.game} • ${tournament.mode} • ${tournament.typeLabel}', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _Meta(label: 'Reward', value: tournament.reward.isEmpty ? 'TBA' : tournament.reward)),
            Expanded(child: _Meta(label: 'Starts', value: _formatDate(tournament.startsAt))),
            Expanded(child: _Meta(label: 'Slots', value: '${tournament.registeredTeams}/${tournament.totalSlots}')),
          ]),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.white10)),
          const SizedBox(height: 8),
          Text('$remaining slots remaining', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final TournamentStatus status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: status == TournamentStatus.published ? const Color(0xFF183B35) : Colors.white10, borderRadius: BorderRadius.circular(99)),
    child: Text(status.name.toUpperCase(), style: TextStyle(color: status == TournamentStatus.published ? const Color(0xFF65E6B5) : Colors.white60, fontSize: 10, fontWeight: FontWeight.w800)),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: Colors.white45, fontSize: 11)),
    const SizedBox(height: 3),
    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
  ]);
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap(), selectedColor: const Color(0xFF8A5CFF), backgroundColor: Colors.white10, labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w700)));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.all(48), child: Column(children: [Icon(Icons.sports_esports_outlined, size: 48, color: Colors.white30), SizedBox(height: 12), Text('No tournaments found', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Check another filter or pull to refresh.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))]));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(28), child: Column(children: [const Icon(Icons.cloud_off, size: 42, color: Colors.white30), const SizedBox(height: 10), const Text('Could not load tournaments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 14), OutlinedButton(onPressed: onRetry, child: const Text('Retry'))]));
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
