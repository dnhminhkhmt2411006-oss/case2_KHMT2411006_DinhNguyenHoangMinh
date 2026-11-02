import 'user.dart';

String permissionLabel(String p) => p == 'editor' ? 'Được chỉnh sửa' : 'Chỉ xem';

class TaskShare {
  final String id;
  final String permission;
  final AppUser? user;

  const TaskShare({required this.id, required this.permission, required this.user});

  factory TaskShare.fromJson(Map<String, dynamic> j) => TaskShare(
    id: (j['id'] ?? '').toString(),
    permission: (j['permission'] ?? 'viewer').toString(),
    user: j['user'] is Map<String, dynamic>
        ? AppUser.fromJson(j['user'] as Map<String, dynamic>)
        : null,
  );
}