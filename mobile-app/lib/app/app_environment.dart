import 'package:flutter_riverpod/flutter_riverpod.dart';

const apiBaseUrl = String.fromEnvironment('VIBECARE_API_BASE_URL');
const supabaseUrl = String.fromEnvironment('VIBECARE_SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'VIBECARE_SUPABASE_PUBLISHABLE_KEY',
);

enum DataConnectionMode { sample, backend, supabase }

enum DeviceExecutionMode { simulator }

class AppEnvironment {
  const AppEnvironment({
    required this.apiBaseUrl,
    this.supabaseUrl = '',
    this.supabasePublishableKey = '',
    this.sourceDeviceId = 'FITRUS-PLUS-01',
    this.targetDeviceId = 'VIBECARE-SIM-01',
  });

  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabasePublishableKey;
  final String sourceDeviceId;
  final String targetDeviceId;

  DataConnectionMode get dataConnectionMode =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty
      ? DataConnectionMode.supabase
      : apiBaseUrl.isEmpty
      ? DataConnectionMode.sample
      : DataConnectionMode.backend;

  // Both local and backend gateways currently simulate execution. A real
  // device mode must be introduced explicitly after its protocol is verified.
  DeviceExecutionMode get deviceExecutionMode => DeviceExecutionMode.simulator;

  bool get usesSampleData => dataConnectionMode == DataConnectionMode.sample;
  bool get usesBackendApi => dataConnectionMode == DataConnectionMode.backend;
  bool get usesSupabase => dataConnectionMode == DataConnectionMode.supabase;
  bool get usesDeviceSimulator =>
      deviceExecutionMode == DeviceExecutionMode.simulator;
}

const buildEnvironment = AppEnvironment(
  apiBaseUrl: apiBaseUrl,
  supabaseUrl: supabaseUrl,
  supabasePublishableKey: supabasePublishableKey,
);

final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => buildEnvironment,
);
