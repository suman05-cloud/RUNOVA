import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runova/features/auth/domain/user_profile.dart';
import 'package:runova/features/leaderboard/data/leaderboard_repository.dart';

import 'test_support.dart';

void main() {
  test(
    'territory rankings request each regional scope, not fitness XP',
    () async {
      final dio = Dio();
      addTearDown(dio.close);
      for (final scope in ['GLOBAL', 'COUNTRY', 'STATE', 'CITY']) {
        dio.httpClientAdapter = TestAdapter((request) {
          expect(request.queryParameters['scope'], scope);
          expect(request.queryParameters['category'], 'TERRITORY_POINTS');
          return (
            200,
            {
              'entries': [
                {
                  'rank': 1,
                  'username': 'runner',
                  'score': 300,
                  'is_current_user': true,
                },
              ],
            },
          );
        });
        final entries = await LeaderboardRepository(dio).territoryPoints(scope);
        expect(entries.single.score, 300);
        expect(entries.single.isCurrentUser, isTrue);
      }
    },
  );

  test(
    'profile keeps state for regional rankings and supports older profiles',
    () {
      expect(UserProfile.fromJson(testProfile).stateRegion, isNull);
      expect(
        UserProfile.fromJson({...testProfile, 'state_region': 'West Bengal'})
            .stateRegion,
        'West Bengal',
      );
    },
  );
}
