class UserInfo {
  final String id;
  final String fullName;
  final String email;

  UserInfo({required this.id, required this.fullName, required this.email});

  factory UserInfo.fromJson(Map<String, dynamic> j) => UserInfo(
    id: (j['_id'] ?? '').toString(),
    fullName: (j['fullName'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
  );
}

// Quyền của người đang đăng nhập với một công việc (backend trả về)
class MyAccess {
  final bool isOwner;
  final bool isAssignee;
  final String? shareRole;
  final bool canEdit;
  final bool canChangeStatus;
  final bool canDelete;
  final bool canManage;

  const MyAccess({
    required this.isOwner,
    required this.isAssignee,
    required this.shareRole,
    required this.canEdit,
    required this.canChangeStatus,
    required this.canDelete,
    required this.canManage,
  });

  factory MyAccess.fromJson(Map<String, dynamic> j) => MyAccess(
    isOwner: j['isOwner'] == true,
    isAssignee: j['isAssignee'] == true,
    shareRole: j['shareRole']?.toString(),
    canEdit: j['canEdit'] == true,
    canChangeStatus: j['canChangeStatus'] == true,
    canDelete: j['canDelete'] == true,
    canManage: j['canManage'] == true,
  );
}

class Task {
  final String id;
  final String title;
  final String description;
  final UserInfo? createdBy;
  final List<UserInfo> assignees;
  final String? primaryAssigneeId;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String priority;
  final String status;
  final MyAccess? access;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.assignees,
    required this.startDate,
    required this.dueDate,
    required this.priority,
    required this.status,
    this.primaryAssigneeId,
    this.access,
  });

  factory Task.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

    String? primary;
    final p = j['primaryAssigneeId'];
    if (p is Map) {
      primary = (p['_id'] ?? '').toString();
    } else if (p != null) {
      primary = p.toString();
    }

    return Task(
      id: (j['_id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      createdBy: j['createdBy'] is Map<String, dynamic>
          ? UserInfo.fromJson(j['createdBy'] as Map<String, dynamic>)
          : null,
      assignees: ((j['assigneeIds'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(UserInfo.fromJson)
          .toList(),
      primaryAssigneeId: primary,
      startDate: parseDate(j['startDate']),
      dueDate: parseDate(j['dueDate']),
      priority: (j['priority'] ?? 'medium').toString(),
      status: (j['status'] ?? 'todo').toString(),
      access: j['myAccess'] is Map<String, dynamic>
          ? MyAccess.fromJson(j['myAccess'] as Map<String, dynamic>)
          : null,
    );
  }
}