import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/task_share.dart';
import '../../services/task_service.dart';
import '../../services/task_share_service.dart';
import '../../utils/format.dart';
import '../../widgets/task_card.dart';
import '../assignment/assign_task_screen.dart';
import '../sharing/task_sharing_screen.dart';
import 'task_edit_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Future<Task> _future;
  late Future<List<TaskShare>> _sharesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = TaskService.fetchTask(widget.taskId);
    _sharesFuture = TaskShareService.list(widget.taskId);
  }

  void _reload() {
    setState(_load);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _edit(Task t) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TaskEditScreen(task: t)),
    );
    if (changed == true && mounted) _reload();
  }

  Future<void> _openAssign(Task t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignTaskScreen(taskId: t.id, taskTitle: t.title),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _openSharing(Task t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskSharingScreen(
          taskId: t.id,
          taskTitle: t.title,
          ownerId: t.createdBy?.id,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _delete(Task t) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa công việc?'),
        content: Text(
          'Bạn có chắc muốn xóa "${t.title}"? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
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
    if (a.shareRole == 'editor') return 'Được chia sẻ (Được chỉnh sửa)';
    if (a.isAssignee) return 'Người được giao';
    return 'Được chia sẻ (Chỉ xem)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<Task>(
      future: _future,
      builder: (context, snap) {
        final t = snap.data;
        final access = t?.access;
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 2,
            title: const Text('Chi tiết công việc'),
            actions: [
              if (t != null && access != null && access.canEdit)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Sửa',
                  onPressed: () => _edit(t),
                ),
              if (t != null && access != null && access.canDelete)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                  tooltip: 'Xóa',
                  onPressed: () => _delete(t),
                ),
              const SizedBox(width: 4),
            ],
          ),
          body: _body(snap, theme),
        );
      },
    );
  }

  Widget _sectionHeader(
      ThemeData theme,
      String title, {
        VoidCallback? onManage,
        String? label,
        IconData? icon,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (onManage != null)
          TextButton.icon(
            onPressed: onManage,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            icon: Icon(icon ?? Icons.edit_outlined, size: 18),
            label: Text(label ?? 'Quản lý'),
          ),
      ],
    );
  }

  Widget _sharesSection(ThemeData theme) {
    return FutureBuilder<List<TaskShare>>(
      future: _sharesFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }
        if (snap.hasError) {
          return Text(
            'Không tải được danh sách chia sẻ',
            style: TextStyle(color: theme.colorScheme.error),
          );
        }
        final shares = snap.data ?? [];
        if (shares.isEmpty) {
          return Text(
            'Chưa chia sẻ cho ai',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          );
        }
        return Column(
          children: shares
              .map(
                (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Text(
                  (s.user?.fullName ?? '?').isNotEmpty
                      ? (s.user?.fullName ?? '?')[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                s.user?.fullName ?? 'Người dùng đã bị xóa',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(s.user?.email ?? ''),
              trailing: TagLabel(
                text: permissionLabel(s.permission),
                color: s.permission == 'editor' ? Colors.orange : Colors.blueGrey,
              ),
            ),
          )
              .toList(),
        );
      },
    );
  }

  Widget _body(AsyncSnapshot<Task> snap, ThemeData theme) {
    if (snap.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snap.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            snap.error.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      );
    }
    final t = snap.data!;
    final canStatus = t.access?.canChangeStatus ?? false;
    final canManage = t.access?.canManage ?? false;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Title & Priority/Status Badges ---
          Text(
            t.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TagLabel(
                text: priorityLabel(t.priority),
                color: priorityColor(t.priority),
              ),
              TagLabel(
                text: statusLabel(t.status),
                color: statusColor(t.status),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- Card Thông tin thời gian & người tạo ---
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.play_circle_outline_rounded,
                    label: 'Bắt đầu',
                    value: formatDate(t.startDate),
                  ),
                  const Divider(height: 12, thickness: 0.5),
                  _InfoRow(
                    icon: Icons.event_rounded,
                    label: 'Hạn hoàn thành',
                    value: formatDate(t.dueDate),
                  ),
                  const Divider(height: 12, thickness: 0.5),
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Người tạo',
                    value: t.createdBy?.fullName ?? 'Không rõ',
                  ),
                  if (t.access != null) ...[
                    const Divider(height: 12, thickness: 0.5),
                    _InfoRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Vai trò của bạn',
                      value: _roleText(t.access!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- Phần Trạng thái ---
          Text(
            'Trạng thái công việc',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['todo', 'in_progress', 'completed'].map((s) {
                final selected = t.status == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(statusLabel(s)),
                    selected: selected,
                    showCheckmark: true,
                    selectedColor: theme.colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: canStatus ? (_) => _changeStatus(s) : null,
                  ),
                );
              }).toList(),
            ),
          ),
          if (!canStatus)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Bạn chỉ có quyền xem công việc này.',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 24),

          // --- Phần Mô tả ---
          Text(
            'Mô tả',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              t.description.isEmpty ? 'Không có mô tả cho công việc này.' : t.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: t.description.isEmpty
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- Người được giao ---
          _sectionHeader(
            theme,
            'Người được giao',
            onManage: canManage ? () => _openAssign(t) : null,
            label: 'Giao việc',
            icon: Icons.group_add_outlined,
          ),
          const SizedBox(height: 6),
          if (t.assignees.isEmpty)
            Text(
              'Chưa giao cho ai',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ...t.assignees.map(
                (u) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                u.fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(u.email),
              trailing: u.id == t.primaryAssigneeId
                  ? const TagLabel(text: 'Phụ trách chính', color: Colors.indigo)
                  : null,
            ),
          ),
          const SizedBox(height: 24),

          // --- Người được chia sẻ ---
          _sectionHeader(
            theme,
            'Người được chia sẻ',
            onManage: canManage ? () => _openSharing(t) : null,
            label: 'Chia sẻ',
            icon: Icons.share_outlined,
          ),
          const SizedBox(height: 6),
          _sharesSection(theme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}