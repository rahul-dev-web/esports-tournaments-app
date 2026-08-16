import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/registration_models.dart';
import '../data/registration_remote_datasource.dart';

final registrationDataSourceProvider = Provider<RegistrationRemoteDataSource>(
  (ref) => RegistrationRemoteDataSource(),
);

final myRegistrationsProvider = FutureProvider.autoDispose<List<RegistrationModel>>((ref) {
  return ref.watch(registrationDataSourceProvider).getMine();
});

final registrationProvider = FutureProvider.autoDispose.family<RegistrationModel, String>((ref, id) {
  return ref.watch(registrationDataSourceProvider).getById(id);
});

final registrationStatusProvider = FutureProvider.autoDispose.family<RegistrationStatusModel, String>((ref, id) {
  return ref.watch(registrationDataSourceProvider).getStatus(id);
});

final startRegistrationProvider = FutureProvider.autoDispose.family<RegistrationModel, RegistrationStartRequest>((ref, request) async {
  final result = await ref.watch(registrationDataSourceProvider).start(
    tournamentId: request.tournamentId,
    teamId: request.teamId,
  );
  ref.invalidate(myRegistrationsProvider);
  ref.invalidate(registrationProvider(result.id));
  ref.invalidate(registrationStatusProvider(result.id));
  return result;
});

class RegistrationStartRequest {
  const RegistrationStartRequest({required this.tournamentId, required this.teamId});

  final String tournamentId;
  final String teamId;

  @override
  bool operator ==(Object other) => other is RegistrationStartRequest && other.tournamentId == tournamentId && other.teamId == teamId;

  @override
  int get hashCode => Object.hash(tournamentId, teamId);
}
