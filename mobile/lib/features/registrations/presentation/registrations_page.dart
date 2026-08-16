import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tournaments/presentation/providers/tournament_provider.dart';
import '../data/registration_models.dart';
import 'registration_provider.dart';

class RegistrationsPage extends ConsumerWidget {
  const RegistrationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrations = ref.watch(myRegistrationsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(title: const Text('My Registrations'), backgroundColor: const Color(0xFF070B18), foregroundColor: Colors.white),
      body: registrations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Message(message: error.toString(), onRetry: () => ref.invalidate(myRegistrationsProvider)),
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(myRegistrationsProvider),
          child: items.isEmpty
              ? ListView(children: const [SizedBox(height: 180), Center(child: Text('No tournament registrations yet.', style: TextStyle(color: Colors.white54)))])
              : ListView.separated(padding: const EdgeInsets.all(16), itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, index) => _RegistrationCard(registration: items[index])),
        ),
      ),
    );
  }
}

class _RegistrationCard extends ConsumerWidget {
  const _RegistrationCard({required this.registration});
  final RegistrationModel registration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournament = ref.watch(tournamentDetailsProvider(registration.tournamentId));
    return tournament.when(
      loading: () => _CardShell(child: const LinearProgressIndicator()),
      error: (_, __) => _CardShell(child: _Content(title: 'Tournament', registration: registration)),
      data: (item) => _CardShell(child: _Content(title: item.name, subtitle: '${item.game} • ${item.typeLabel}', registration: registration)),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF10182F), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)), child: child);
}

class _Content extends StatelessWidget {
  const _Content({required this.title, required this.registration, this.subtitle});
  final String title; final String? subtitle; final RegistrationModel registration;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))), _StatusChip(status: registration.statusLabel)]),
    if (subtitle != null) ...[const SizedBox(height: 5), Text(subtitle!, style: const TextStyle(color: Colors.white54, fontSize: 12))],
    const SizedBox(height: 12),
    Text('Team: ${registration.teamId}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
    const SizedBox(height: 5),
    if (registration.isRegistered) Text('Slot #${registration.slot ?? '-'}', style: const TextStyle(color: Color(0xFF39D0FF), fontWeight: FontWeight.w800)) else Text('${registration.adsCompleted}/${registration.adsRequired} ads verified', style: const TextStyle(color: Colors.white60, fontSize: 12)),
  ]);
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(99)), child: Text(status, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800)));
}

class _Message extends StatelessWidget {
  const _Message({required this.message, required this.onRetry});
  final String message; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)), const SizedBox(height: 12), OutlinedButton(onPressed: onRetry, child: const Text('Retry'))])));
}
