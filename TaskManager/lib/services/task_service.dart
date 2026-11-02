import 'dart:convert';
import '../models/task.dart';
import 'api_client.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class TaskService {
  static Future<List<Task>> fetchTasks({String? scope}) async {
    final path = scope == null ? '/tasks' : '/tasks?scope=$scope';
    try {
      final res = await ApiClient.get(path);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return (data as List)
            .map((e) => Task.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ApiException(res.statusCode, _message(data));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(0, 'Không kết nối được máy chủ');
    }
  }

  static Future<Task> fetchTask(String id) async {
    try {
      final res = await ApiClient.get('/tasks/$id');
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return Task.fromJson(data as Map<String, dynamic>);
      }
      throw ApiException(res.statusCode, _message(data));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(0, 'Không kết nối được máy chủ');
    }
  }

  static String _message(dynamic data) =>
      data is Map ? (data['message'] ?? 'Lỗi tải dữ liệu').toString() : 'Lỗi tải dữ liệu';
}