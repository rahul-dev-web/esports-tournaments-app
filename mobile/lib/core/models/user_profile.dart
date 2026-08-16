class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.bio = '',
    this.country = '',
    this.state = '',
    this.city = '',
    this.photoUrl,
    this.preferredGame = '',
    this.socialLinks = const {},
    this.inGameUid,
  });

  final String id;
  final String name;
  final String username;
  final String email;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String bio;
  final String country;
  final String state;
  final String city;
  final String? photoUrl;
  final String preferredGame;
  final Map<String, String> socialLinks;
  final String? inGameUid;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final links = json['social_links'];

    return UserProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      bio: json['bio']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString(),
      preferredGame: json['preferred_game']?.toString() ?? '',
      socialLinks: links is Map
          ? Map<String, String>.from(
              links.map((key, value) => MapEntry(key.toString(), value.toString())),
            )
          : const {},
      inGameUid: json['in_game_uid']?.toString(),
    );
  }
}
