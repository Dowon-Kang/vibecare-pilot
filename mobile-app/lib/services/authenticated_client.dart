import 'package:dio/dio.dart';
import 'auth_repository.dart';

Dio createAuthenticatedClient(String baseUrl, SessionStore store) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  Future<String?>? refreshing;
  Future<String?> refresh() async {
    final refreshToken = await store.readRefreshToken();
    if (refreshToken == null) return null;
    final response = await dio.post<Map<String, dynamic>>(
      '/v1/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final token = response.data?['accessToken'] as String?;
    // A logout or new login while refreshing must not restore an old session.
    if (token == null || await store.readRefreshToken() != refreshToken) {
      return null;
    }
    await store.writeAccessToken(token);
    return token;
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (!options.path.startsWith('/v1/auth/')) {
          final token = await store.readAccessToken();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        if (error.response?.statusCode != 401 ||
            request.path.startsWith('/v1/auth/') ||
            request.extra['refreshed'] == true) {
          handler.next(error);
          return;
        }
        try {
          final saved = await store.readAccessToken();
          String? token;
          if (saved != null &&
              request.headers['Authorization'] != 'Bearer $saved') {
            token = saved;
          } else {
            refreshing ??= refresh().whenComplete(() => refreshing = null);
            token = await refreshing;
          }
          if (token == null) {
            handler.next(error);
            return;
          }
          request.extra['refreshed'] = true;
          request.headers['Authorization'] = 'Bearer $token';
          handler.resolve(await dio.fetch<dynamic>(request));
        } on DioException catch (retryError) {
          handler.next(retryError);
        } catch (_) {
          handler.next(error);
        }
      },
    ),
  );
  return dio;
}
