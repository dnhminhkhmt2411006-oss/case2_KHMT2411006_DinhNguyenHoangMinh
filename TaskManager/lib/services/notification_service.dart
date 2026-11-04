import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import 'api_call.dart';
import 'api_client.dart';

// Số thông báo chưa đọc, dùng cho biểu tượng chuông
final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

class NotificationService {
  static Future<List<AppNotification>> list() async {
    final body = await callApi(() => ApiClient.get('/notifications'));
    return (body as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<int> fetchUnreadCount() async {
    final body =
    await callApi(() => ApiClient.get('/notifications/unread-count'));
    final c = (body as Map)['count'];
    return c is int ? c : int.tryParse(c.toString()) ?? 0;
  }

  // Cập nhật số trên chuông; bỏ qua lỗi mạng
  static Future<void> refreshUnread() async {
    try {
      unreadCount.value = await fetchUnreadCount();
    } catch (_) {}
  }

  static Future<void> markRead(String id) async {
    await callApi(() => ApiClient.patch('/notifications/$id/read', {}));
  }

  static Future<void> markAllRead() async {
    await callApi(() => ApiClient.patch('/notifications/read-all', {}));
  }
}