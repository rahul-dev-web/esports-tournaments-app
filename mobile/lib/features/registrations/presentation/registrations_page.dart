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
      appBar: AppBar(
        title: const Text('My Registrations'),
        backgroundColor: const Color(0xFF070B18),
        foregroundColor: Colors.white,
      ),
      body: registrations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Message(
          message: error.toString(),
          onRetry: () => ref.invalidate(myRegistrationsProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(myRegistrationsProvider),
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 180),
                    Center(
                      child: Text(
                        'No tournament registrations yet.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) => _RegistrationCard(
                    registration: items[index],
                  ),
                ),
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
    final tournament = ref.watch(
      tournamentDetailsProvider(registration.tournamentId),
    );
    return tournament.when(
      loading: () => _CardShell(child: const LinearProgressIndicator()),
      error: (_, __) => _CardShell(
        child: _Content(title: 'Tournament', registration: registration),
      ),
      data: (item) => _CardShell(
        child: _Content(
          title: item.name,
          subtitle: '${item.game} • ${item.typeLabel}',
          registration: registration,
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF10182F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: child,
      );
}

class _Content extends StatelessWidget {
  const _Content({
    required this.title,
    required this.registration,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final RegistrationModel registration;

  @override
  Widget build(BuildContext context) {
    final status = _statusMeta(registration);
    final progress = registration.adsRequired > 0
        ? (registration.adsCompleted / registration.adsRequired)
            .clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(label: status.label, icon: status.icon),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.groups_rounded,
          text: 'Team ${registration.teamId}',
        ),
        const SizedBox(height: 7),
        if (registration.isRegistered)
          Row(
            children: [
              const Icon(
                Icons.confirmation_number_rounded,
                size: 15,
                color: Color(0xFF39D0FF),
              ),
              const SizedBox(width: 6),
              Text(
                'Tournament slot #${registration.slot ?? '-'}',
                style: const TextStyle(
                  color: Color(0xFF39D0FF),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          )
        else ...[
          Row(
            children: [
              const Icon(
                Icons.ondemand_video_rounded,
                size: 15,
                color: Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                '${registration.adsCompleted}/${registration.adsRequired} ads verified',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          if (registration.adsRequired > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: progress,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF39D0FF)),
              ),
            ),
          ],
        ],
        const SizedBox(height: 10),
        Text(
          status.description,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 15, color: Colors.white54),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
        ],
      );
}

class _StatusMeta {
  const _StatusMeta(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
}

_StatusMeta _statusMeta(RegistrationModel registration) {
  final normalized = registration.statusLabel.trim().toLowerCase();
  if (registration.isRegistered || normalized == 'registered') {
    return const _StatusMeta(
      'Registered',
      'Your team has a confirmed tournament slot.',
      Icons.check_circle_rounded,
    );
  }
  if (normalized.contains('reject')) {
    return const _StatusMeta(
      'Rejected',
      'This registration was rejected by tournament management.',
      Icons.cancel_rounded,
    );
  }
  if (normalized.contains('expire')) {
    return const _StatusMeta(
      'Expired',
      'This registration is no longer active.',
      Icons.timer_off_rounded,
    );
  }
  if (normalized.contains('ad')) {
    return const _StatusMeta(
      'Ad Verification',
      'Complete the required verified ads to unlock registration.',
      Icons.verified_rounded,
    );
  }
  return const _StatusMeta(
    'Pending',
    'Registration is waiting for the required conditions.',
    Icons.schedule_rounded,
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
