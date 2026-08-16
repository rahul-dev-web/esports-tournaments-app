import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../teams/presentation/providers/team_provider.dart';
import '../../tournaments/data/models/tournament_model.dart';
import '../data/registration_models.dart';
import 'registration_provider.dart';

class RegisterTournamentPage extends ConsumerStatefulWidget {
  const RegisterTournamentPage({super.key, required this.tournament});

  final TournamentModel tournament;

  @override
  ConsumerState<RegisterTournamentPage> createState() => _RegisterTournamentPageState();
}

class _RegisterTournamentPageState extends ConsumerState<RegisterTournamentPage> {
  String? selectedTeamId;
  bool submitting = false;

  @override
  Widget build(BuildContext context) {
    final teams = ref.watch(myTeamsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        title: const Text('Register Tournament'),
        backgroundColor: const Color(0xFF070B18),
        foregroundColor: Colors.white,
      ),
      body: teams.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _StateMessage(message: error.toString(), onRetry: () => ref.invalidate(myTeamsProvider)),
        data: (items) {
          final eligible = items.where((team) => team['game']?.toString().toLowerCase() == widget.tournament.game.toLowerCase()).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _TournamentHeader(tournament: widget.tournament),
              const SizedBox(height: 16),
              _Section(
                title: 'Choose your team',
                child: eligible.isEmpty
                    ? const Text('You do not have a team for this game yet. Create or join a team first.', style: TextStyle(color: Colors.white60, height: 1.45))
                    : Column(
                        children: eligible.map((team) {
                          final id = team['id']?.toString();
                          final name = team['name']?.toString() ?? 'Unnamed team';
                          final members = (team['member_ids'] as List?)?.length ?? 0;
                          final isCaptain = team['captain_id']?.toString() == _currentUserId;
                          final selected = id != null && id == selectedTeamId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: isCaptain && id != null ? () => setState(() => selectedTeamId = id) : null,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: selected ? const Color(0xFF211A49) : const Color(0xFF10182F),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: selected ? const Color(0xFF8A5CFF) : Colors.white10),
                                ),
                                child: Row(children: [
                                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? const Color(0xFF8A5CFF) : Colors.white38),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text('$members/${widget.tournament.teamSize} players • ${isCaptain ? 'Captain' : 'Not captain'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ])),
                                ]),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Registration requirements',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Requirement(icon: Icons.groups_outlined, text: 'Team must have exactly ${widget.tournament.teamSize} players.'),
                  _Requirement(icon: Icons.sports_esports_outlined, text: 'Team game must match ${widget.tournament.game}.'),
                  _Requirement(icon: Icons.verified_outlined, text: widget.tournament.policy == RegistrationPolicy.captainAds ? 'Captain completes ${widget.tournament.adsRequired} rewarded ad${widget.tournament.adsRequired == 1 ? '' : 's'}.' : 'Each team member completes one rewarded ad.'),
                ]),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: selectedTeamId == null || submitting ? null : _submit,
                icon: submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.how_to_reg),
                label: Text(submitting ? 'Starting...' : 'Start registration'),
              ),
              const SizedBox(height: 8),
              const Text('The backend remains the source of truth. Eligibility, duplicate registration, slot availability and registration policy are validated server-side.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4)),
            ],
          );
        },
      ),
    );
  }

  String? get _currentUserId => null;

  Future<void> _submit() async {
    if (selectedTeamId == null) return;
    setState(() => submitting = true);
    try {
      final registration = await ref.read(registrationDataSourceProvider).start(
        tournamentId: widget.tournament.id,
        teamId: selectedTeamId!,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RegistrationProgressPage(registration: registration, tournament: widget.tournament)));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }
}

class RegistrationProgressPage extends ConsumerWidget {
  const RegistrationProgressPage({super.key, required this.registration, required this.tournament});
  final RegistrationModel registration;
  final TournamentModel tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(registrationStatusProvider(registration.id));
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(title: const Text('Registration Status'), backgroundColor: const Color(0xFF070B18), foregroundColor: Colors.white),
      body: status.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _StateMessage(message: error.toString(), onRetry: () => ref.invalidate(registrationStatusProvider(registration.id))),
        data: (value) => ListView(padding: const EdgeInsets.all(16), children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF10182F), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)), child: Column(children: [
            Icon(value.isComplete ? Icons.verified : Icons.hourglass_top, size: 52, color: value.isComplete ? const Color(0xFF39D0FF) : const Color(0xFF8A5CFF)),
            const SizedBox(height: 12),
            Text(value.isComplete ? 'Registration complete' : value.status == RegistrationStatus.adVerification ? 'Ad verification in progress' : 'Registration started', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(value.isComplete ? 'Your tournament slot is ${value.slot ?? '-'}.' : 'Your registration is waiting for the required verification steps.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.4)),
          ])),
          const SizedBox(height: 14),
          _Section(title: 'Reward progress', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('${value.adsCompleted}/${value.adsRequired} ads verified', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))), Text('${(value.adsRequired == 0 ? 1 : value.adsCompleted / value.adsRequired).clamp(0.0, 1.0) * 100 ~/ 1}%', style: const TextStyle(color: Colors.white54))]),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: value.adsRequired == 0 ? 1 : (value.adsCompleted / value.adsRequired).clamp(0.0, 1.0), minHeight: 8),
          ])),
          const SizedBox(height: 14),
          const Text('Ad watching will be connected to the existing AdMob session + backend verification flow in the next step. No client-side completion is treated as a registration success.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4)),
        ]),
      ),
    );
  }
}

class _TournamentHeader extends StatelessWidget {
  const _TournamentHeader({required this.tournament});
  final TournamentModel tournament;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1B2140), Color(0xFF10182F)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tournament.game.toUpperCase(), style: const TextStyle(color: Color(0xFF39D0FF), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)), const SizedBox(height: 6), Text(tournament.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text('${tournament.typeLabel} • ${tournament.teamSize} players • ${tournament.policyLabel}', style: const TextStyle(color: Colors.white60, fontSize: 12))]));
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title; final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF10182F), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), const SizedBox(height: 12), child]));
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.icon, required this.text});
  final IconData icon; final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: const Color(0xFF8A5CFF), size: 18), const SizedBox(width: 9), Expanded(child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.35)))]));
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.message, required this.onRetry});
  final String message; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)), const SizedBox(height: 12), OutlinedButton(onPressed: onRetry, child: const Text('Retry'))])));
}
