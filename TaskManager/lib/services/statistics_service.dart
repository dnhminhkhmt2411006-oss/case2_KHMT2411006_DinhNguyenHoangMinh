import '../models/statistics.dart';
import 'api_call.dart';
import 'api_client.dart';

class StatisticsService {
  static Future<Statistics> load() async {
    final results = await Future.wait<dynamic>([
      callApi(() => ApiClient.get('/statistics/tasks')),
      callApi(() => ApiClient.get('/statistics/assignments')),
      callApi(() => ApiClient.get('/statistics/deadlines')),
    ]);
    return Statistics(
      tasks: StatusCounts.fromJson(results[0] as Map<String, dynamic>),
      assignments: AssignmentStats.fromJson(results[1] as Map<String, dynamic>),
      deadlines: DeadlineStats.fromJson(results[2] as Map<String, dynamic>),
    );
  }
}