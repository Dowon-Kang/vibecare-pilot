import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

import '../models/models.dart';

class AuthSession {
  const AuthSession({
    required this.participant,
    required this.accessToken,
    required this.refreshToken,
  });

  final ParticipantProfile participant;
  final String accessToken;
  final String refreshToken;
}

abstract interface class AuthRepository {
  Future<AuthSession> login({
    required String participantCode,
    required String pin,
  });
}

abstract interface class SessionStore {
  Future<void> save(AuthSession session);
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> writeAccessToken(String token);
  Future<void> clear();
}

class BackendAuthRepository implements AuthRepository {
  BackendAuthRepository(this._dio);
  final Dio _dio;

  @override
  Future<AuthSession> login({
    required String participantCode,
    required String pin,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/pin',
      data: {'participantCode': participantCode, 'pin': pin},
    );
    final json = response.data!;
    final participant = json['participant'] as Map<String, dynamic>;
    return AuthSession(
      participant: ParticipantProfile(
        id: participant['id'] as String,
        code: participant['code'] as String,
        age: participant['age'] as int,
        sex: ParticipantSex.values.byName(participant['sex'] as String),
        heightCm: (participant['heightCm'] as num).toDouble(),
      ),
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }
}

class MockAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login({
    required String participantCode,
    required String pin,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (participantCode.trim().toUpperCase() != 'USER-001' || pin != '123456') {
      throw StateError('참여자 코드 또는 PIN을 확인해 주세요.');
    }
    return const AuthSession(
      participant: ParticipantProfile(
        id: 'USER-001',
        code: 'USER-001',
        age: 72,
        sex: ParticipantSex.female,
        heightCm: 150,
      ),
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
    );
  }
}

class SecureSessionStore implements SessionStore {
  const SecureSessionStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<void> save(AuthSession session) async {
    await _storage.write(key: 'access_token', value: session.accessToken);
    await _storage.write(key: 'refresh_token', value: session.refreshToken);
  }

  @override
  Future<String?> readAccessToken() => _storage.read(key: 'access_token');
  @override
  Future<String?> readRefreshToken() => _storage.read(key: 'refresh_token');
  @override
  Future<void> writeAccessToken(String token) =>
      _storage.write(key: 'access_token', value: token);

  @override
  Future<void> clear() => _storage.deleteAll();
}

class MemorySessionStore implements SessionStore {
  AuthSession? session;

  @override
  Future<void> save(AuthSession value) async => session = value;

  @override
  Future<String?> readAccessToken() async => session?.accessToken;
  @override
  Future<String?> readRefreshToken() async => session?.refreshToken;
  @override
  Future<void> writeAccessToken(String token) async {
    final current = session;
    if (current != null) {
      session = AuthSession(
        participant: current.participant,
        accessToken: token,
        refreshToken: current.refreshToken,
      );
    }
  }

  @override
  Future<void> clear() async => session = null;
}
