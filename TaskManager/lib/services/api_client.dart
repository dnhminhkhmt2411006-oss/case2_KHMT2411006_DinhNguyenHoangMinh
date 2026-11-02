import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiClient {
  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('token');
  }

  static Future<void> saveToken(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('token', token);
  }

  static Future<void> clearToken() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String path) async =>
      http.get(Uri.parse('$baseUrl$path'), headers: await _headers());

  static Future<http.Response> post(String path, Map<String, dynamic> body) async =>
      http.post(Uri.parse('$baseUrl$path'),
          headers: await _headers(), body: jsonEncode(body));

  static Future<http.Response> put(String path, Map<String, dynamic> body) async =>
      http.put(Uri.parse('$baseUrl$path'),
          headers: await _headers(), body: jsonEncode(body));

  static Future<http.Response> patch(String path, Map<String, dynamic> body) async =>
      http.patch(Uri.parse('$baseUrl$path'),
          headers: await _headers(), body: jsonEncode(body));

  static Future<http.Response> delete(String path) async =>
      http.delete(Uri.parse('$baseUrl$path'), headers: await _headers());
}