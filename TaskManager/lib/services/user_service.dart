import '../models/user.dart';
import 'api_call.dart';
import 'api_client.dart';

class UserService {
  static Future<List<AppUser>> search(String q) async {
    final body = await callApi(
            () => ApiClient.get('/users/search?q=${Uri.encodeQueryComponent(q)}'));
    return (body as List)
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}