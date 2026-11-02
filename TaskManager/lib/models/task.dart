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

class Task {
  final String id;
  final String title;
  final String description;
  final UserInfo? createdBy;
  final List<UserInfo> assignees;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String priority;
  final String status;

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
  });

  factory Task.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

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
      startDate: parseDate(j['startDate']),
      dueDate: parseDate(j['dueDate']),
      priority: (j['priority'] ?? 'medium').toString(),
      status: (j['status'] ?? 'todo').toString(),
    );
  }
}