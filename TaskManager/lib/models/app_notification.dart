class AppNotification {
  final String id;
  final String? taskId;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.taskId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: (j['id'] ?? '').toString(),
    taskId: j['taskId']?.toString(),
    type: (j['type'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    message: (j['message'] ?? '').toString(),
    isRead: j['isRead'] == true,
    createdAt: j['createdAt'] == null
        ? null
        : DateTime.tryParse(j['createdAt'].toString())?.toLocal(),
  );

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    taskId: taskId,
    type: type,
    title: title,
    message: message,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );
}