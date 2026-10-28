import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl:        ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'Accept':       'application/json',
      'Content-Type': 'application/json',
    },
  ))
    ..interceptors.add(_AuthInterceptor());

  static Dio get dio => _dio;

  static Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  static Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  static Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  static Future<Response> delete(String path, {dynamic data}) =>
      _dio.delete(path, data: data);
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      StorageService.deleteToken();
    }
    handler.next(err);
  }
}

/// Extract a human-readable error message from a DioException.
String apiErrorMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    if (data['message'] != null) return data['message'].toString();
    if (data['errors'] != null) {
      final errors = data['errors'] as Map;
      final first  = errors.values.first;
      return first is List ? first.first.toString() : first.toString();
    }
  }
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Connection timed out. Please check your internet.';
    case DioExceptionType.connectionError:
      return 'Cannot connect to server. Is the backend running?';
    default:
      return e.message ?? 'Something went wrong. Please try again.';
  }
}
