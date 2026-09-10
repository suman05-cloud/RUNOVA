import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:runova/core/network/api_client.dart';
import 'package:runova/features/auth/data/auth_repository.dart';
import 'package:runova/features/auth/domain/user_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(authStoreProvider),
  ),
);

final authControllerProvider =
    AsyncNotifierProvider<AuthController, UserProfile?>(AuthController.new);

class AuthController extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final store = ref.watch(authStoreProvider);
    void expired() => state = const AsyncData(null);
    store.addListener(expired);
    ref.onDispose(() => store.removeListener(expired));
    return ref.read(authRepositoryProvider).restore();
  }

  Future<void> updateProfile(Map<String, dynamic> changes) async {
    final profile = await ref.read(authRepositoryProvider).update(changes);
    state = AsyncData(profile);
  }

  Future<bool> login({
    required String email,
    required String username,
    String? displayName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .directLogin(
            email: email,
            username: username,
            displayName: displayName,
          ),
    );
    return !state.hasError;
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}
