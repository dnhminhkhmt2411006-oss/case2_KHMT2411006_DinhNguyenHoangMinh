import 'dart:convert';
import 'api_client.dart';

class AuthService {
  // Trả về null nếu thành công, ngược lại trả về thông báo lỗi
  static Future<String?> login(String email, String password) async {
    try {
      final res = await ApiClient.post(
          '/auth/login', {'email': email, 'password': password});
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await ApiClient.saveToken(data['token']);
        return null;
      }
      return data['message'] ?? 'Đăng nhập thất bại';
    } catch (e) {
      return 'Không kết nối được máy chủ';
    }
  }

  static Future<String?> register(
      String fullName, String email, String password) async {
    try {
      final res = await ApiClient.post('/auth/register',
          {'fullName': fullName, 'email': email, 'password': password});
      final data = jsonDecode(res.body);
      if (res.statusCode == 201) {
        await ApiClient.saveToken(data['token']);
        return null;
      }
      return data['message'] ?? 'Đăng ký thất bại';
    } catch (e) {
      return 'Không kết nối được máy chủ';
    }
  }

  static Future<void> logout() => ApiClient.clearToken();
}