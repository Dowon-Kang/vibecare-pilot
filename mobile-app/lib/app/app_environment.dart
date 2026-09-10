import 'package:flutter_riverpod/flutter_riverpod.dart';

const apiBaseUrl = String.fromEnvironment('VIBECARE_API_BASE_URL');

enum DataConnectionMode { sample, backend }

enum DeviceExecutionMode { simulator }

class AppEnvironment {
  const AppEnvironment({
    required this.apiBaseUrl,
    this.sourceDeviceId = 'FITRUS-PLUS-01',
    this.targetDeviceId = 'VIBECARE-SIM-01',
  });

  final String apiBaseUrl;
  final String sourceDeviceId;
  final String targetDeviceId;

  DataConnectionMode get dataConnectionMode => apiBaseUrl.isEmpty
      ? DataConnectionMode.sample
      : DataConnectionMode.backend;

  // Both local and backend gateways currently simulate execution. A real
  // device mode must be introduced explicitly after its protocol is verified.
  DeviceExecutionMode get deviceExecutionMode => DeviceExecutionMode.simulator;

  bool get usesSampleData => dataConnectionMode == DataConnectionMode.sample;
  bool get usesBackendApi => dataConnectionMode == DataConnectionMode.backend;
  bool get usesDeviceSimulator =>
      deviceExecutionMode == DeviceExecutionMode.simulator;
}

const buildEnvironment = AppEnvironment(apiBaseUrl: apiBaseUrl);

final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => buildEnvironment,
);
