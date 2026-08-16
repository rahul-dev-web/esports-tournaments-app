import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../data/datasources/tournament_remote_datasource.dart';
import '../../data/models/tournament_model.dart';

final tournamentDatasourceProvider = Provider<TournamentRemoteDatasource>(
  (ref) => TournamentRemoteDatasource(ApiClient()),
);

final tournamentListProvider = FutureProvider.autoDispose.family<List<TournamentModel>, TournamentListFilter>(
  (ref, filter) async {
    final datasource = ref.watch(tournamentDatasourceProvider);
    return datasource.list(game: filter.game, status: filter.status);
  },
);

final tournamentDetailsProvider = FutureProvider.autoDispose.family<TournamentModel, String>(
  (ref, id) => ref.watch(tournamentDatasourceProvider).getById(id),
);

class TournamentListFilter {
  const TournamentListFilter({this.game, this.status});

  final String? game;
  final TournamentStatus? status;

  @override
  bool operator ==(Object other) =>
      other is TournamentListFilter && other.game == game && other.status == status;

  @override
  int get hashCode => Object.hash(game, status);
}
