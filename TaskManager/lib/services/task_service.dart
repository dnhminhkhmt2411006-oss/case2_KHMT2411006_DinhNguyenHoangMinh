import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import '../models/task_filter.dart';
import 'api_client.dart';

// Tăng giá trị này để các danh sách tự tải lại sau khi thêm, sửa, xóa
final ValueNotifier<int> taskRefresh = ValueNotifier<int>(0);
void notifyTasksChanged() => taskRefresh.value++;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class TaskService {
  static Future<dynamic> _call(Future<http.Response> Function() fn) async {
    try {
      final res = await fn();
      final body = res.body.isEmpty ? null : jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) return body;
      throw ApiException(res.statusCode, _message(body));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(0, 'Không kết nối được máy chủ');
    }
  }

  static String _message(dynamic data) => data is Map
      ? (data['message'] ?? 'Có lỗi xảy ra').toString()
      : 'Có lỗi xảy ra';

  static Future<List<Task>> fetchTasks({
    String? scope,
    TaskFilter filter = const TaskFilter(),
  }) async {
    final query = Uri(queryParameters: filter.toQueryParams(scope)).query;
    final body = await _call(() => ApiClient.get('/tasks?$query'));
    return (body as List)
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Task> fetchTask(String id) async {
    final body = await _call(() => ApiClient.get('/tasks/$id'));
    return Task.fromJson(body as Map<String, dynamic>);
  }

  static Future<void> createTask(Map<String, dynamic> data) async {
    await _call(() => ApiClient.post('/tasks', data));
  }

  static Future<void> updateTask(String id, Map<String, dynamic> data) async {
    await _call(() => ApiClient.put('/tasks/$id', data));
  }

  static Future<void> updateStatus(String id, String status) async {
    await _call(() => ApiClient.patch('/tasks/$id/status', {'status': status}));
  }

  static Future<void> deleteTask(String id) async {
    await _call(() => ApiClient.delete('/tasks/$id'));
  }
}