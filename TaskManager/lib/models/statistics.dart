int _toInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

class StatusCounts {
  final int total;
  final int todo;
  final int inProgress;
  final int completed;

  const StatusCounts({
    required this.total,
    required this.todo,
    required this.inProgress,
    required this.completed,
  });

  factory StatusCounts.fromJson(Map<String, dynamic> j) => StatusCounts(
    total: _toInt(j['total']),
    todo: _toInt(j['todo']),
    inProgress: _toInt(j['in_progress']),
    completed: _toInt(j['completed']),
  );
}

class AssignmentStats {
  final StatusCounts assignedToMe;
  final StatusCounts primaryForMe;
  final StatusCounts createdByMe;
  final int assignedByMe;

  const AssignmentStats({
    required this.assignedToMe,
    required this.primaryForMe,
    required this.createdByMe,
    required this.assignedByMe,
  });

  factory AssignmentStats.fromJson(Map<String, dynamic> j) => AssignmentStats(
    assignedToMe:
    StatusCounts.fromJson(j['assignedToMe'] as Map<String, dynamic>),
    primaryForMe:
    StatusCounts.fromJson(j['primaryForMe'] as Map<String, dynamic>),
    createdByMe:
    StatusCounts.fromJson(j['createdByMe'] as Map<String, dynamic>),
    assignedByMe: _toInt(j['assignedByMe']),
  );
}

class DeadlineItem {
  final String id;
  final String title;
  final DateTime? dueDate;
  final String status;
  final String priority;

  const DeadlineItem({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.status,
    required this.priority,
  });

  factory DeadlineItem.fromJson(Map<String, dynamic> j) => DeadlineItem(
    id: (j['id'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    dueDate: j['dueDate'] == null
        ? null
        : DateTime.tryParse(j['dueDate'].toString())?.toLocal(),
    status: (j['status'] ?? 'todo').toString(),
    priority: (j['priority'] ?? 'medium').toString(),
  );
}

class DeadlineStats {
  final int days;
  final int overdueCount;
  final int dueTodayCount;
  final int dueSoonCount;
  final int noDueDateCount;
  final List<DeadlineItem> overdue;
  final List<DeadlineItem> dueSoon;

  const DeadlineStats({
    required this.days,
    required this.overdueCount,
    required this.dueTodayCount,
    required this.dueSoonCount,
    required this.noDueDateCount,
    required this.overdue,
    required this.dueSoon,
  });

  factory DeadlineStats.fromJson(Map<String, dynamic> j) {
    int count(dynamic s) => s is Map ? _toInt(s['count']) : 0;
    List<DeadlineItem> items(dynamic s) =>
        ((s is Map ? s['items'] : null) as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DeadlineItem.fromJson)
            .toList();
    return DeadlineStats(
      days: _toInt(j['days']),
      overdueCount: count(j['overdue']),
      dueTodayCount: count(j['dueToday']),
      dueSoonCount: count(j['dueSoon']),
      noDueDateCount: count(j['noDueDate']),
      overdue: items(j['overdue']),
      dueSoon: items(j['dueSoon']),
    );
  }
}

class Statistics {
  final StatusCounts tasks;
  final AssignmentStats assignments;
  final DeadlineStats deadlines;

  const Statistics({
    required this.tasks,
    required this.assignments,
    required this.deadlines,
  });
}