import '../models/user.dart';
import 'api_call.dart';
import 'api_client.dart';

class AssignmentService {
  static List<Assignee> _parse(dynamic body) => (body as List)
      .map((e) => Assignee.fromJson(e as Map<String, dynamic>))
      .toList();

  static Future<List<Assignee>> list(String taskId) async =>
      _parse(await callApi(() => ApiClient.get('/tasks/$taskId/assignees')));

  static Future<List<Assignee>> add(String taskId, List<String> userIds) async =>
      _parse(await callApi(
              () => ApiClient.post('/tasks/$taskId/assignees', {'userIds': userIds})));

  static Future<List<Assignee>> setPrimary(String taskId, String userId) async =>
      _parse(await callApi(
              () => ApiClient.patch('/tasks/$taskId/assignees/$userId', {})));

  static Future<List<Assignee>> remove(String taskId, String userId) async =>
      _parse(await callApi(
              () => ApiClient.delete('/tasks/$taskId/assignees/$userId')));
}