enum TournamentStatus { draft, published, closed }

enum TournamentType { solo, duo, squad, custom }

enum RegistrationPolicy { individualAds, captainAds }

class TournamentModel {
  const TournamentModel({
    required this.id,
    required this.name,
    required this.game,
    required this.mode,
    required this.tournamentType,
    required this.startsAt,
    required this.entryRequirement,
    required this.reward,
    required this.status,
    required this.totalSlots,
    required this.registeredTeams,
    required this.teamSize,
    required this.adsRequired,
    required this.policy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String game;
  final String mode;
  final TournamentType tournamentType;
  final DateTime startsAt;
  final String entryRequirement;
  final String reward;
  final TournamentStatus status;
  final int totalSlots;
  final int registeredTeams;
  final int teamSize;
  final int adsRequired;
  final RegistrationPolicy policy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TournamentModel.fromJson(Map<String, dynamic> json) {
    return TournamentModel(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Untitled Tournament',
      game: json['game']?.toString() ?? 'Unknown game',
      mode: json['mode']?.toString() ?? 'Custom',
      tournamentType: _type(json['tournament_type']),
      startsAt: DateTime.tryParse(json['starts_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      entryRequirement: json['entry_requirement']?.toString() ?? '',
      reward: json['reward']?.toString() ?? '',
      status: _status(json['status']),
      totalSlots: _int(json['total_slots']),
      registeredTeams: _int(json['registered_teams']),
      teamSize: _int(json['team_size'], fallback: 1),
      adsRequired: _int(json['ads_required']),
      policy: _policy(json['policy']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  static int _int(dynamic value, {int fallback = 0}) => int.tryParse(value?.toString() ?? '') ?? fallback;

  static TournamentStatus _status(dynamic value) => TournamentStatus.values.firstWhere(
        (item) => item.name == value?.toString(),
        orElse: () => TournamentStatus.draft,
      );

  static TournamentType _type(dynamic value) => TournamentType.values.firstWhere(
        (item) => item.name == value?.toString(),
        orElse: () => TournamentType.custom,
      );

  static RegistrationPolicy _policy(dynamic value) {
    switch (value?.toString()) {
      case 'captain_ads':
        return RegistrationPolicy.captainAds;
      default:
        return RegistrationPolicy.individualAds;
    }
  }

  String get typeLabel => switch (tournamentType) {
        TournamentType.solo => 'Solo',
        TournamentType.duo => 'Duo',
        TournamentType.squad => 'Squad',
        TournamentType.custom => 'Custom',
      };

  String get policyLabel => policy == RegistrationPolicy.captainAds ? 'Captain Ads' : 'Individual Ads';
}
