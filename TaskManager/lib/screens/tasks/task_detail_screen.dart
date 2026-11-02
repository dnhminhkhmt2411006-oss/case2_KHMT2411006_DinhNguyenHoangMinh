import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../utils/format.dart';
import '../../widgets/task_card.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Future<Task> _future;

  @override
  void initState() {
    super.initState();
    _future = TaskService.fetchTask(widget.taskId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết công việc')),
      body: FutureBuilder<Task>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snap.error.toString(), textAlign: TextAlign.center),
              ),
            );
          }
          final t = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                t.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  TagLabel(
                      text: priorityLabel(t.priority),
                      color: priorityColor(t.priority)),
                  TagLabel(
                      text: statusLabel(t.status),
                      color: statusColor(t.status)),
                ],
              ),
              const Divider(height: 32),
              _InfoRow(
                  icon: Icons.play_circle_outline,
                  label: 'Bắt đầu',
                  value: formatDate(t.startDate)),
              _InfoRow(
                  icon: Icons.event,
                  label: 'Hạn hoàn thành',
                  value: formatDate(t.dueDate)),
              _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Người tạo',
                  value: t.createdBy?.fullName ?? 'Không rõ'),
              const Divider(height: 32),
              Text('Mô tả', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(t.description.isEmpty ? 'Không có mô tả' : t.description),
              const Divider(height: 32),
              Text('Người được giao',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (t.assignees.isEmpty) const Text('Chưa giao cho ai'),
              ...t.assignees.map(
                    (u) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(u.fullName.isNotEmpty
                        ? u.fullName[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(u.fullName),
                  subtitle: Text(u.email),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}