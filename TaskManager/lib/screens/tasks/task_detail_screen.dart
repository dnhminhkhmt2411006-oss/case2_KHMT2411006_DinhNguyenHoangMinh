import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../utils/format.dart';
import '../../widgets/task_card.dart';
import 'task_edit_screen.dart';

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

  void _reload() {
    setState(() {
      _future = TaskService.fetchTask(widget.taskId);
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _edit(Task t) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TaskEditScreen(task: t)),
    );
    if (changed == true && mounted) _reload();
  }

  Future<void> _delete(Task t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa công việc?'),
        content: Text(
            'Bạn có chắc muốn xóa "${t.title}"? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await TaskService.deleteTask(t.id);
      notifyTasksChanged();
      if (!mounted) return;
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _changeStatus(String status) async {
    try {
      await TaskService.updateStatus(widget.taskId, status);
      notifyTasksChanged();
      if (mounted) _reload();
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  String _roleText(MyAccess a) {
    if (a.isOwner) return 'Người tạo';
    if (a.shareRole == 'editor') return 'Được chia sẻ (được chỉnh sửa)';
    if (a.isAssignee) return 'Người được giao';
    return 'Được chia sẻ (chỉ xem)';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Task>(
      future: _future,
      builder: (context, snap) {
        final t = snap.data;
        final access = t?.access;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Chi tiết công việc'),
            actions: [
              if (t != null && access != null && access.canEdit)
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Sửa',
                  onPressed: () => _edit(t),
                ),
              if (t != null && access != null && access.canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Xóa',
                  onPressed: () => _delete(t),
                ),
            ],
          ),
          body: _body(snap),
        );
      },
    );
  }

  Widget _body(AsyncSnapshot<Task> snap) {
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
    final canStatus = t.access?.canChangeStatus ?? false;
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
                text: statusLabel(t.status), color: statusColor(t.status)),
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
        if (t.access != null)
          _InfoRow(
              icon: Icons.verified_user_outlined,
              label: 'Vai trò của bạn',
              value: _roleText(t.access!)),
        const Divider(height: 32),
        Text('Trạng thái', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['todo', 'in_progress', 'completed']
              .map((s) => ChoiceChip(
            label: Text(statusLabel(s)),
            selected: t.status == s,
            onSelected: canStatus ? (_) => _changeStatus(s) : null,
          ))
              .toList(),
        ),
        if (!canStatus)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Bạn chỉ có quyền xem công việc này.',
                style: TextStyle(color: Colors.grey)),
          ),
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
              child: Text(
                  u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?'),
            ),
            title: Text(u.fullName),
            subtitle: Text(u.email),
            trailing: u.id == t.primaryAssigneeId
                ? const TagLabel(text: 'Phụ trách chính', color: Colors.indigo)
                : null,
          ),
        ),
      ],
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