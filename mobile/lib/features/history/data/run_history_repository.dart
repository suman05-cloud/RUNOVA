import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:runova/core/network/api_client.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';

class RunHistoryRepository {
  RunHistoryRepository(this.dio);
  final Dio dio;
  Future<List<Map<String, dynamic>>> list() async {
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 100) {
      final response = await dio.get<List<dynamic>>(
        '/v1/runs',
        queryParameters: {'limit': 100, 'offset': offset},
      );
      final page = response.data!.cast<Map<String, dynamic>>();
      result.addAll(page);
      if (page.length < 100) return result;
    }
  }

  Future<Map<String, dynamic>> detail(String id, {bool route = false}) async =>
      (await dio.get<Map<String, dynamic>>(
        '/v1/runs/$id',
        queryParameters: {'include_route': route},
      )).data!;
}

final historyRepositoryProvider = Provider(
  (ref) => RunHistoryRepository(ref.watch(apiClientProvider)),
);
final runHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return [];
  return ref.watch(historyRepositoryProvider).list();
});
final runDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) {
      ref.watch(authControllerProvider.select((value) => value.value?.id));
      return ref.watch(historyRepositoryProvider).detail(id);
    });
