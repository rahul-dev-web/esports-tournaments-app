import '../../../../core/services/api_client.dart';
import '../models/tournament_model.dart';

class TournamentRemoteDatasource {
  TournamentRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<TournamentModel>> list({
    String? game,
    TournamentStatus? status,
    int skip = 0,
    int limit = 20,
  }) async {
    final query = <String, String>{
      'skip': '$skip',
      'limit': '$limit',
      if (game != null && game.isNotEmpty) 'game': game,
      if (status != null) 'status': status.name,
    };
    // apiBaseUrl already contains /api. ApiClient prefixes the base URL, so
    // the path must start at the resource root rather than /api again.
    final path = Uri(path: '/tournaments', queryParameters: query).toString();
    final response = await _apiClient.getList(path);
    return response
        .whereType<Map<String, dynamic>>()
        .map(TournamentModel.fromJson)
        .toList();
  }

  Future<TournamentModel> getById(String id) async {
    final response = await _apiClient.get('/tournaments/$id');
    return TournamentModel.fromJson(response);
  }
}
