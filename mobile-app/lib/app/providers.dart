import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_repository.dart';
import '../services/authenticated_client.dart';
import '../services/backend_device_gateway.dart';
import '../services/device_gateway.dart';
import '../services/feedback_repository.dart';
import '../services/fitrus_repository.dart';
import '../services/mock_device_gateway.dart';
import 'app_environment.dart';

final sessionStoreProvider = Provider<SessionStore>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  return environment.usesSampleData
      ? MemorySessionStore()
      : const SecureSessionStore();
});

final dioProvider = Provider<Dio>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  final dio = createAuthenticatedClient(
    environment.apiBaseUrl,
    ref.read(sessionStoreProvider),
  );
  ref.onDispose(dio.close);
  return dio;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  return environment.usesSampleData
      ? MockAuthRepository()
      : BackendAuthRepository(ref.read(dioProvider));
});

final fitrusRepositoryProvider = Provider<FitrusRepository>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  return environment.usesSampleData
      ? MockFitrusRepository()
      : BackendFitrusRepository(ref.read(dioProvider));
});

final deviceGatewayProvider = Provider<DeviceGateway>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  // API-backed execution is still a server-side simulator. This switch only
  // selects where simulation is coordinated; it never enables real hardware.
  final gateway = environment.usesSampleData
      ? MockDeviceGateway()
      : BackendDeviceGateway(ref.read(dioProvider));
  ref.onDispose(gateway.dispose);
  return gateway;
});

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  return FeedbackRepository(
    environment.usesSampleData ? null : ref.read(dioProvider),
  );
});
