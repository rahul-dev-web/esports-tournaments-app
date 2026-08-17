import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../registrations/presentation/register_tournament_page.dart';
import '../data/models/tournament_model.dart';
import 'providers/tournament_provider.dart';

class TournamentDetailsPage extends ConsumerWidget {
  const TournamentDetailsPage({super.key, required this.tournamentId});
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(tournamentDetailsProvider(tournamentId));
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(title: const Text('Tournament Details'), backgroundColor: const Color(0xFF070B18), foregroundColor: Colors.white),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off, color: Colors.white30, size: 48), const SizedBox(height: 12), const Text('Tournament unavailable', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(error.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)), const SizedBox(height: 14), OutlinedButton(onPressed: () => ref.invalidate(tournamentDetailsProvider(tournamentId)), child: const Text('Retry'))]))),
        data: (tournament) => _Details(tournament: tournament),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.tournament});
  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final progress = tournament.totalSlots == 0 ? 0.0 : (tournament.registeredTeams / tournament.totalSlots).clamp(0.0, 1.0);
    final isOpen = tournament.status == TournamentStatus.published;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1B2140), Color(0xFF10182F)]), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tournament.game.toUpperCase(), style: const TextStyle(color: Color(0xFF39D0FF), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4)), const SizedBox(height: 8), Text(tournament.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.05)), const SizedBox(height: 10), Text('${tournament.mode} • ${tournament.typeLabel}', style: const TextStyle(color: Colors.white70, fontSize: 15))]),
      const SizedBox(height: 16),
      _Section(title: 'Tournament info', children: [
        _InfoRow(icon: Icons.schedule, label: 'Starts', value: _formatDate(tournament.startsAt)),
        _InfoRow(icon: Icons.groups_outlined, label: 'Team size', value: '${tournament.teamSize} players'),
        _InfoRow(icon: Icons.emoji_events_outlined, label: 'Reward', value: tournament.reward.isEmpty ? 'TBA' : tournament.reward),
        _InfoRow(icon: Icons.confirmation_number_outlined, label: 'Entry', value: tournament.entryRequirement.isEmpty ? 'No requirement' : tournament.entryRequirement),
      ]),
      const SizedBox(height: 12),
      _Section(title: 'Slots', children: [Row(children: [Expanded(child: Text('${tournament.registeredTeams}/${tournament.totalSlots} teams registered', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))), Text('${(progress * 100).round()}%', style: const TextStyle(color: Colors.white60))]), const SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.white10))]),
      const SizedBox(height: 12),
      _Section(title: 'Registration policy', children: [Text(tournament.policyLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(tournament.adsRequired > 0 ? '${tournament.adsRequired} rewarded ad${tournament.adsRequired == 1 ? '' : 's'} required.' : 'No rewarded ads required.', style: const TextStyle(color: Colors.white60))]),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: isOpen ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegisterTournamentPage(tournament: tournament))) : null, icon: const Icon(Icons.how_to_reg), label: Text(isOpen ? 'Register with my team' : tournament.status.name.toUpperCase())),
      if (!isOpen)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Registration is controlled by the tournament status in the backend.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
    ]);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title; final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF10182F), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), const SizedBox(height: 12), ...children]));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon; final String label; final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Icon(icon, color: const Color(0xFF8A5CFF), size: 20), const SizedBox(width: 10), Expanded(child: Text(label, style: const TextStyle(color: Colors.white54))), Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))]));
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
