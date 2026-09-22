import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Points at the SchoolMS2 JWT API (SchoolMS.Web/Controllers/Api/*).
/// Exactly one of the two lines below should be active — swap when switching environments, then do a
/// full rebuild (`flutter build apk`), not just hot reload.
class ApiConfig {
  // Live server — fill in once SchoolMS2 is deployed with a real HTTPS domain.
  // static const String baseUrl = 'https://api.rkclasses.example.com';

  // Local dev machine — LAN IP (not "localhost", which on a real phone means the phone itself).
  // Run `dotnet run` in SchoolMS.Web, find this machine's Wi-Fi IPv4 (`ipconfig`), and put it here with
  // the port from launchSettings.json (e.g. http://192.168.0.124:2020).
 // static const String baseUrl = 'http://192.168.0.124:2020';
  static const String baseUrl = 'https://rkclasses.jmmportal.com/Api';
  // Same-machine dev/testing only (Flutter web preview + local dotnet run against RKClassesLive).
  // static const String baseUrl = 'http://127.0.0.1:5299';
}

const String _tokenPrefsKey = 'auth_token';

/// Thin Dio wrapper: attaches `Authorization: Bearer <token>` to every request once a token is set,
/// and exposes plain get/post/put/delete helpers the per-module services use. Bodies are sent as JSON
/// (Dio's default) — unlike a legacy MVC model-binder, the API controllers here are [ApiController]s
/// that bind JSON request bodies natively.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (status) => status != null && status < 500,
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
    ));
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;
  String? _token;

  Future<void> loadPersistedToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenPrefsKey);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenPrefsKey);
    } else {
      await prefs.setString(_tokenPrefsKey, token);
    }
  }

  bool get hasToken => _token != null;

  /// Exposed (read-only) for building a PDF view/download URL to hand to url_launcher — those open in
  /// the device's external browser, which can't carry the Authorization header, so the token travels
  /// as a `?token=` query param instead. The JWT middleware (Program.cs) already accepts that as a
  /// fallback for any /api path, purely to support this "open a link outside the app" case.
  String? get token => _token;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _wrap(() => _dio.get<T>(path, queryParameters: query));

  Future<Response<T>> post<T>(String path, {Map<String, dynamic>? data}) =>
      _wrap(() => _dio.post<T>(path, data: data));

  Future<Response<T>> put<T>(String path, {Map<String, dynamic>? data}) =>
      _wrap(() => _dio.put<T>(path, data: data));

  Future<Response<T>> delete<T>(String path, {Map<String, dynamic>? data}) =>
      _wrap(() => _dio.delete<T>(path, data: data));

  /// Every request funnels through here so the rest of the app only ever has to catch [ApiException] —
  /// without this, a timeout or dropped connection surfaces as a raw [DioException] that none of the
  /// screens' `on ApiException catch` blocks match, leaving loading spinners stuck forever with no
  /// error shown (confirmed live: an unfiltered attendance report request past the 20s receive timeout
  /// did exactly this).
  Future<Response<T>> _wrap<T>(Future<Response<T>> Function() call) async {
    try {
      final res = await call();
      _throwIfError(res);
      return res;
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw ApiException('The server took too long to respond. Please try again.');
        case DioExceptionType.connectionError:
          throw ApiException('Could not connect to server. Please check your internet connection.');
        case DioExceptionType.badResponse:
          throw ApiException(extractMessage(e.response?.data, 'Server error. Please try again later.'),
              statusCode: e.response?.statusCode);
        case DioExceptionType.cancel:
          rethrow;
        default:
          throw ApiException('Something went wrong. Please try again.');
      }
    }
  }

  /// The API returns 401/403/400 with a JSON `{error}` body rather than failing the request outright —
  /// Dio's validateStatus (status < 500) treats that as a normal response, so every service's
  /// `Model.fromJson(res.data)` would otherwise silently parse an error body into a model full of
  /// default/zero values instead of surfacing what went wrong.
  void _throwIfError(Response res) {
    final code = res.statusCode ?? 0;
    if (code >= 400) {
      final fallback = code == 401 ? 'Your session has expired. Please log in again.' : 'Something went wrong.';
      throw ApiException(extractMessage(res.data, fallback), statusCode: code);
    }
  }
}

/// Raised by service methods when the API returns a non-2xx body, carrying a user-presentable message
/// pulled from the API's own `{error}` JSON field where possible.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

String extractMessage(dynamic data, String fallback) {
  if (data is Map) {
    final m = data['error'] ?? data['message'] ?? data['Error'] ?? data['Message'];
    if (m != null) return m.toString();
  }
  return fallback;
}
