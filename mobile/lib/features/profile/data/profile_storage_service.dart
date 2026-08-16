import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config.dart';

class ProfileStorageService {
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<String> uploadProfileImage({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final normalizedExtension = extension.toLowerCase().replaceFirst('.', '');
    final safeExtension = switch (normalizedExtension) {
      'jpg' || 'jpeg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };

    final path = '$userId/avatar.$safeExtension';

    await _supabase.storage.from(supabaseProfileBucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: 'image/$safeExtension',
      ),
    );

    return _supabase.storage.from(supabaseProfileBucket).getPublicUrl(path);
  }
}

final profileStorageService = ProfileStorageService();
