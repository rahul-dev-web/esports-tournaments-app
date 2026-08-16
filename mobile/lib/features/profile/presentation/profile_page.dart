import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/profile_storage_service.dart';
import 'providers/profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _countryController;
  late final TextEditingController _stateController;
  late final TextEditingController _cityController;
  late final TextEditingController _gameController;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  Map<String, dynamic>? _loadedProfile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
    _countryController = TextEditingController();
    _stateController = TextEditingController();
    _cityController = TextEditingController();
    _gameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _gameController.dispose();
    super.dispose();
  }

  String _value(dynamic value) => value?.toString() ?? '';

  void _loadProfile(Map<String, dynamic> profile) {
    if (_loadedProfile == profile) return;
    _loadedProfile = profile;
    _nameController.text = _value(profile['name']);
    _usernameController.text = _value(profile['username']);
    _bioController.text = _value(profile['bio']);
    _countryController.text = _value(profile['country']);
    _stateController.text = _value(profile['state']);
    _cityController.text = _value(profile['city']);
    _gameController.text = _value(profile['preferred_game']);
  }

  void _restoreProfile() {
    final profile = _loadedProfile;
    if (profile == null) return;
    _nameController.text = _value(profile['name']);
    _usernameController.text = _value(profile['username']);
    _bioController.text = _value(profile['bio']);
    _countryController.text = _value(profile['country']);
    _stateController.text = _value(profile['state']);
    _cityController.text = _value(profile['city']);
    _gameController.text = _value(profile['preferred_game']);
  }

  Future<void> _pickAndUploadPhoto(Map<String, dynamic> profile) async {
    if (_isUploadingPhoto) return;
    final userId = _value(profile['id']);
    if (userId.isEmpty) return;

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final bytes = await image.readAsBytes();
      final extension = image.name.contains('.') ? image.name.split('.').last : 'jpg';
      final url = await profileStorageService.uploadProfileImage(
        userId: userId,
        bytes: bytes,
        extension: extension,
      );

      await ref.read(updateProfileProvider({'photo_url': url}).future);
      if (!mounted) return;
      ref.invalidate(userProfileProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to upload photo: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await ref.read(updateProfileProvider({
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'country': _countryController.text.trim(),
        'state': _stateController.text.trim(),
        'city': _cityController.text.trim(),
        'preferred_game': _gameController.text.trim(),
      }).future);

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isSaving = false;
        _loadedProfile = null;
      });
      ref.invalidate(userProfileProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update profile: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  void _startEditing(Map<String, dynamic> profile) {
    _loadProfile(profile);
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    _restoreProfile();
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF070A13),
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            profileAsync.maybeWhen(
              data: (profile) => IconButton(
                tooltip: 'Edit profile',
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => _startEditing(profile),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(userProfileProvider),
        color: const Color(0xFF9B6CFF),
        backgroundColor: const Color(0xFF12182A),
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _ErrorState(
            message: err.toString().replaceFirst('Exception: ', ''),
            onRetry: () => ref.invalidate(userProfileProvider),
          ),
          data: (profile) {
            _loadProfile(profile);
            return Form(
              key: _formKey,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildHero(profile),
                  const SizedBox(height: 16),
                  if (_isEditing) _buildEditSection() else _buildOverview(profile),
                  const SizedBox(height: 16),
                  _buildAccountSection(profile),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(Map<String, dynamic> profile) {
    final name = _value(profile['name']);
    final username = _value(profile['username']);
    final photoUrl = _value(profile['photo_url']);
    final role = _value(profile['role']).isEmpty ? 'USER' : _value(profile['role']).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1538), Color(0xFF10192D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Color(0x339B6CFF)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pickAndUploadPhoto(profile),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFFB56CFF), Color(0xFF43D9FF)]),
                  ),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: const Color(0xFF0B1020),
                    backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty ? const Icon(Icons.person_rounded, size: 38, color: Colors.white54) : null,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Color(0xFF9B6CFF), shape: BoxShape.circle),
                  child: _isUploadingPhoto
                      ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Arena Player' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                if (username.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text('@$username', style: const TextStyle(color: Colors.white54)),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFF9B6CFF).withOpacity(.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(role, style: const TextStyle(color: Color(0xFFC8B4FF), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)),
                ),
              ],
            ),
          ),
          if (!_isEditing)
            IconButton(
              tooltip: 'Edit profile',
              onPressed: () => _startEditing(profile),
              icon: const Icon(Icons.edit_rounded, color: Color(0xFFBFA5FF)),
            ),
        ],
      ),
    );
  }

  Widget _buildOverview(Map<String, dynamic> profile) {
    return _SectionCard(
      title: 'Player Profile',
      icon: Icons.sports_esports_rounded,
      child: Column(
        children: [
          _InfoRow('Bio', _value(profile['bio']).isEmpty ? 'No bio yet' : _value(profile['bio'])),
          _InfoRow('Preferred game', _value(profile['preferred_game']).isEmpty ? '-' : _value(profile['preferred_game'])),
          _InfoRow('Country', _value(profile['country']).isEmpty ? '-' : _value(profile['country'])),
          _InfoRow('State', _value(profile['state']).isEmpty ? '-' : _value(profile['state'])),
          _InfoRow('City', _value(profile['city']).isEmpty ? '-' : _value(profile['city'])),
        ],
      ),
    );
  }

  Widget _buildEditSection() {
    return _SectionCard(
      title: 'Edit Profile',
      icon: Icons.tune_rounded,
      child: Column(
        children: [
          _field(_nameController, 'Name', Icons.badge_outlined, maxLength: 80, required: true),
          _field(_usernameController, 'Username', Icons.alternate_email_rounded, maxLength: 40, required: true),
          _field(_bioController, 'Bio', Icons.notes_rounded, maxLines: 3, maxLength: 250),
          _field(_countryController, 'Country', Icons.public_rounded, maxLength: 60),
          _field(_stateController, 'State / Province', Icons.map_outlined, maxLength: 80),
          _field(_cityController, 'City', Icons.location_city_rounded, maxLength: 80),
          _field(_gameController, 'Preferred Game', Icons.sports_esports_rounded, maxLength: 60),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: _isSaving ? null : _cancelEditing, child: const Text('Cancel'))),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
                  label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(Map<String, dynamic> profile) {
    return _SectionCard(
      title: 'Account',
      icon: Icons.verified_user_outlined,
      child: Column(
        children: [
          _InfoRow('Email', _value(profile['email']).isEmpty ? '-' : _value(profile['email'])),
          _InfoRow('User ID', _value(profile['id']).isEmpty ? '-' : _value(profile['id'])),
          _InfoRow('In-game UID', _value(profile['in_game_uid']).isEmpty ? 'Not set' : _value(profile['in_game_uid'])),
          _InfoRow('Registration date', _formatDate(profile['created_at'])),
        ],
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '-';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {int maxLines = 1, int? maxLength, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        validator: required ? (value) => value == null || value.trim().isEmpty ? '$label is required' : null : null,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF101625), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(.07))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 19, color: const Color(0xFF9B6CFF)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 118, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.white38),
        const SizedBox(height: 16),
        const Text('Could not load your profile', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 20),
        Center(child: ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again'))),
      ],
    );
  }
}
