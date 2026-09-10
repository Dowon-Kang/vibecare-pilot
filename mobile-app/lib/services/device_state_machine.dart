import 'device_gateway.dart';

/// Validates the client-side lifecycle shared by every device adapter.
///
/// It is intentionally transport-agnostic: a future BLE/REST adapter must use
/// the same fail-closed transitions, but this class does not infer a protocol.
class DeviceStateMachine {
  DeviceConnectionState _state = DeviceConnectionState.disconnected;

  DeviceConnectionState get state => _state;

  void transition(DeviceConnectionState next) {
    if (next == _state) return;
    if (!_allowed[_state]!.contains(next)) {
      throw StateError('허용되지 않은 장치 상태 전이입니다: $_state → $next');
    }
    _state = next;
  }

  static const _allowed = <DeviceConnectionState, Set<DeviceConnectionState>>{
    DeviceConnectionState.disconnected: {
      DeviceConnectionState.connecting,
      DeviceConnectionState.error,
    },
    DeviceConnectionState.connecting: {
      DeviceConnectionState.ready,
      DeviceConnectionState.disconnected,
      DeviceConnectionState.error,
    },
    DeviceConnectionState.ready: {
      DeviceConnectionState.connecting,
      DeviceConnectionState.authorized,
      DeviceConnectionState.disconnected,
      DeviceConnectionState.error,
    },
    DeviceConnectionState.authorized: {
      DeviceConnectionState.starting,
      DeviceConnectionState.disconnected,
      DeviceConnectionState.error,
    },
    DeviceConnectionState.starting: {
      DeviceConnectionState.running,
      DeviceConnectionState.disconnected,
      DeviceConnectionState.error,
    },
    DeviceConnectionState.running: {
      DeviceConnectionState.stopping,
      DeviceConnectionState.disconnected,
      DeviceConnectionState.error,
    },
    DeviceConnectionState.stopping: {
      DeviceConnectionState.completed,
      DeviceConnectionState.disconnected,
      DeviceConnectionState.error,
    },
    DeviceConnectionState.completed: {
      DeviceConnectionState.ready,
      DeviceConnectionState.disconnected,
      DeviceConnectionState.error,
    },
    DeviceConnectionState.error: {
      DeviceConnectionState.connecting,
      DeviceConnectionState.stopping,
      DeviceConnectionState.disconnected,
    },
  };
}
