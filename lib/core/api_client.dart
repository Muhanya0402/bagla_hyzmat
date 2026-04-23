import 'package:bagla/core/base_url.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:bagla/main.dart' show navigatorKey;

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;
  static const String _baseUrl = BaseUrl.url;

  bool _isRefreshing = false;
  List<Completer<void>> _refreshCompleters = [];

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode != 401 ||
              e.requestOptions.path.contains('/auth/refresh')) {
            return handler.next(e);
          }

          if (_isRefreshing) {
            final completer = Completer<void>();
            _refreshCompleters.add(completer);

            try {
              await completer.future;
              final response = await _retry(e.requestOptions);
              return handler.resolve(response);
            } catch (err) {
              return handler.next(e);
            }
          }

          _isRefreshing = true;

          try {
            final prefs = await SharedPreferences.getInstance();
            final refreshToken = prefs.getString('refresh_token');

            if (refreshToken == null) throw Exception("No refresh token");

            final refreshDio = Dio(BaseOptions(baseUrl: _baseUrl));
            final response = await refreshDio.post(
              '/auth/refresh',
              data: {'refresh_token': refreshToken},
            );

            final newAccessToken = response.data['data']['access_token'];
            final newRefreshToken = response.data['data']['refresh_token'];

            await prefs.setString('auth_token', newAccessToken);
            await prefs.setString('refresh_token', newRefreshToken);

            for (var completer in _refreshCompleters) {
              completer.complete();
            }
            _refreshCompleters.clear();

            final retryResponse = await _retry(e.requestOptions);
            return handler.resolve(retryResponse);
          } catch (err) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('auth_token');
            await prefs.remove('refresh_token');
            await prefs.setBool('is_logged_in', false);

            // Редирект на логин
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );

            return handler.next(e);
          } finally {
            _isRefreshing = false;
          }
        },
      ),
    );
  }

  Future<Response> _retry(RequestOptions requestOptions) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final options = Options(
      method: requestOptions.method,
      headers: {...requestOptions.headers, 'Authorization': 'Bearer $token'},
    );

    return dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
}
