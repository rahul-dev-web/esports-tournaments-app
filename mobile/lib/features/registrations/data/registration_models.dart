enum RegistrationStatus { pending, adVerification, registered, rejected, expired }

RegistrationStatus _statusFromJson(String value) {
  switch (value) {
    case 'ad_verification':
      return RegistrationStatus.adVerification;
    case 'registered':
      return RegistrationStatus.registered;
    case 'rejected':
      return RegistrationStatus.rejected;
    case 'expired':
      return RegistrationStatus.expired;
    default:
      return RegistrationStatus.pending;
  }
}

class RegistrationModel {
  const RegistrationModel({
    required this.id,
    required this.tournamentId,
    required this.teamId,
    required this.captainId,
    required this.status,
    required this.adsRequired,
    required this.adsCompleted,
    required this.completedBy,
    this.slot,
  });

  final String id;
  final String tournamentId;
  final String teamId;
  final String captainId;
  final RegistrationStatus status;
  final int adsRequired;
  final int adsCompleted;
  final List<String> completedBy;
  final int? slot;

  factory RegistrationModel.fromJson(Map<String, dynamic> json) => RegistrationModel(
        id: json['id'].toString(),
        tournamentId: json['tournament_id'].toString(),
        teamId: json['team_id'].toString(),
        captainId: json['captain_id'].toString(),
        status: _statusFromJson(json['status']?.toString() ?? 'pending'),
        adsRequired: (json['ads_required'] as num?)?.toInt() ?? 0,
        adsCompleted: (json['ads_completed'] as num?)?.toInt() ?? 0,
        completedBy: List<String>.from(json['completed_by'] ?? const []),
        slot: (json['slot'] as num?)?.toInt(),
      );

  bool get isRegistered => status == RegistrationStatus.registered;
  bool get isPendingAds => status == RegistrationStatus.pending || status == RegistrationStatus.adVerification;
  double get adProgress => adsRequired == 0 ? 0 : (adsCompleted / adsRequired).clamp(0.0, 1.0);

  String get statusLabel {
    switch (status) {
      case RegistrationStatus.adVerification:
        return 'Ad verification';
      case RegistrationStatus.registered:
        return 'Registered';
      case RegistrationStatus.rejected:
        return 'Rejected';
      case RegistrationStatus.expired:
        return 'Expired';
      case RegistrationStatus.pending:
        return 'Pending';
    }
  }
}

class RegistrationStatusModel {
  const RegistrationStatusModel({
    required this.registrationId,
    required this.status,
    required this.adsRequired,
    required this.adsCompleted,
    required this.membersCompleted,
    required this.isComplete,
    this.slot,
  });

  final String registrationId;
  final RegistrationStatus status;
  final int adsRequired;
  final int adsCompleted;
  final List<String> membersCompleted;
  final bool isComplete;
  final int? slot;

  factory RegistrationStatusModel.fromJson(Map<String, dynamic> json) => RegistrationStatusModel(
        registrationId: json['registration_id'].toString(),
        status: _statusFromJson(json['status']?.toString() ?? 'pending'),
        adsRequired: (json['ads_required'] as num?)?.toInt() ?? 0,
        adsCompleted: (json['ads_completed'] as num?)?.toInt() ?? 0,
        membersCompleted: List<String>.from(json['members_completed'] ?? const []),
        isComplete: json['is_complete'] == true,
        slot: (json['slot'] as num?)?.toInt(),
      );
}
