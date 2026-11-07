import 'user.dart';

class TaskFilter {
  final String query;
  final String? status;
  final String? priority;
  final AppUser? assignee;
  final String sortBy;
  final String order;

  const TaskFilter({
    this.query = '',
    this.status,
    this.priority,
    this.assignee,
    this.sortBy = 'dueDate',
    this.order = 'asc',
  });

  bool get isActive =>
      query.trim().isNotEmpty ||
          status != null ||
          priority != null ||
          assignee != null;

  bool get isCustomSort => sortBy != 'dueDate' || order != 'asc';

  TaskFilter withQuery(String q) => TaskFilter(
    query: q,
    status: status,
    priority: priority,
    assignee: assignee,
    sortBy: sortBy,
    order: order,
  );

  TaskFilter withoutStatus() => TaskFilter(
    query: query,
    priority: priority,
    assignee: assignee,
    sortBy: sortBy,
    order: order,
  );

  TaskFilter withoutPriority() => TaskFilter(
    query: query,
    status: status,
    assignee: assignee,
    sortBy: sortBy,
    order: order,
  );

  TaskFilter withoutAssignee() => TaskFilter(
    query: query,
    status: status,
    priority: priority,
    sortBy: sortBy,
    order: order,
  );

  // Tham số gửi lên GET /tasks
  Map<String, String> toQueryParams(String? scope) => {
    if (scope != null) 'scope': scope,
    if (query.trim().isNotEmpty) 'q': query.trim(),
    if (status != null) 'status': status!,
    if (priority != null) 'priority': priority!,
    if (assignee != null) 'assigneeId': assignee!.id,
    'sortBy': sortBy,
    'order': order,
  };

  @override
  bool operator ==(Object other) =>
      other is TaskFilter &&
          other.query == query &&
          other.status == status &&
          other.priority == priority &&
          other.assignee?.id == assignee?.id &&
          other.sortBy == sortBy &&
          other.order == order;

  @override
  int get hashCode =>
      Object.hash(query, status, priority, assignee?.id, sortBy, order);
}