import 'dart:convert';
import 'package:http/http.dart' as http;
import 'task_service.dart' show ApiException;

// Gọi API, trả về dữ liệu JSON hoặc ném ApiException kèm thông báo lỗi
Future<dynamic> callApi(Future<http.Response> Function() fn) async {
  try {
    final res = await fn();
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final message = body is Map
        ? (body['message'] ?? 'Có lỗi xảy ra').toString()
        : 'Có lỗi xảy ra';
    throw ApiException(res.statusCode, message);
  } on ApiException {
    rethrow;
  } catch (_) {
    throw ApiException(0, 'Không kết nối được máy chủ');
  }
}