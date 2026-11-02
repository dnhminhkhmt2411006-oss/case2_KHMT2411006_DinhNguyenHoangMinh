import '../models/task_share.dart';
import 'api_call.dart';
import 'api_client.dart';

class TaskShareService {
  static List<TaskShare> _parse(dynamic body) => (body as List)
      .map((e) => TaskShare.fromJson(e as Map<String, dynamic>))
      .toList();

  static Future<List<TaskShare>> list(String taskId) async =>
      _parse(await callApi(() => ApiClient.get('/tasks/$taskId/shares')));

  static Future<List<TaskShare>> add(
      String taskId, List<String> userIds, String permission) async =>
      _parse(await callApi(() => ApiClient.post(
          '/tasks/$taskId/shares', {'userIds': userIds, 'permission': permission})));

  static Future<List<TaskShare>> updatePermission(
      String taskId, String shareId, String permission) async =>
      _parse(await callApi(() => ApiClient.patch(
          '/tasks/$taskId/shares/$shareId', {'permission': permission})));

  static Future<List<TaskShare>> revoke(String taskId, String shareId) async =>
      _parse(await callApi(
              () => ApiClient.delete('/tasks/$taskId/shares/$shareId')));
}