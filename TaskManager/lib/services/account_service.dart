import '../models/user.dart';
import 'api_call.dart';
import 'api_client.dart';

class AccountService {
  static Future<AppUser> me() async {
    final body = await callApi(() => ApiClient.get('/auth/me'));
    return AppUser.fromJson(body as Map<String, dynamic>);
  }

  static Future<AppUser> updateProfile(String fullName) async {
    final body = await callApi(
            () => ApiClient.put('/auth/profile', {'fullName': fullName}));
    return AppUser.fromJson(body as Map<String, dynamic>);
  }

  static Future<void> changePassword(String current, String next) async {
    await callApi(() => ApiClient.put('/auth/change-password',
        {'currentPassword': current, 'newPassword': next}));
  }
}