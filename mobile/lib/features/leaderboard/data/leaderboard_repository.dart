import 'package:dio/dio.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.username,
    required this.score,
    required this.isCurrentUser,
  });

  final int rank;
  final String username;
  final double score;
  final bool isCurrentUser;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: json['rank'] as int,
        username: json['username'] as String,
        score: (json['score'] as num).toDouble(),
        isCurrentUser: json['is_current_user'] as bool,
      );
}

class LeaderboardRepository {
  const LeaderboardRepository(this._dio);

  final Dio _dio;

  Future<List<LeaderboardEntry>> territoryPoints(String scope) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/leaderboards',
      queryParameters: {'scope': scope, 'category': 'TERRITORY_POINTS'},
    );
    return (response.data!['entries'] as List<dynamic>)
        .map(
          (entry) => LeaderboardEntry.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
  }
}
