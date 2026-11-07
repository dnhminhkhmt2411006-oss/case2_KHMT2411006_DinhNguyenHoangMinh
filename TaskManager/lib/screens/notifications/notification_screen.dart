import 'package:flutter/material.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../services/task_service.dart' show ApiException;
import '../../utils/format.dart';
import '../tasks/task_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await NotificationService.list();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
      NotificationService.refreshUnread();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
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

  Future<void> _markAll() async {
    try {
      await NotificationService.markAllRead();
      if (!mounted) return;
      setState(() {
        _items = _items.map((e) => e.copyWith(isRead: true)).toList();
      });
      unreadCount.value = 0;
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      setState(() {
        _items = _items
            .map((e) => e.id == n.id ? e.copyWith(isRead: true) : e)
            .toList();
      });
      try {
        await NotificationService.markRead(n.id);
      } catch (_) {}
      NotificationService.refreshUnread();
    }
    if (!mounted) return;
    if (n.type == 'share_revoked') {
      _toast('Bạn không còn quyền truy cập công việc này');
      return;
    }
    if (n.taskId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: n.taskId!)),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.assignment_ind_rounded;
      case 'task_shared':
        return Icons.share_rounded;
      case 'share_updated':
        return Icons.manage_accounts_rounded;
      case 'share_revoked':
        return Icons.block_rounded;
      case 'status_changed':
        return Icons.published_with_changes_rounded;
      case 'due_changed':
        return Icons.event_repeat_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _iconColor(ThemeData theme, String type) {
    switch (type) {
      case 'task_assigned':
        return Colors.blue;
      case 'task_shared':
        return Colors.teal;
      case 'share_updated':
        return Colors.amber.shade800;
      case 'share_revoked':
        return theme.colorScheme.error;
      case 'status_changed':
        return Colors.purple;
      case 'due_changed':
        return Colors.orange;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _timeAgo(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return formatDate(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = _items.any((e) => !e.isRead);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Thông báo',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.done_all_rounded,
              color: hasUnread
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: hasUnread ? _markAll : null,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(showSpinner: false),
      child: _items.isEmpty
          ? LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có thông báo nào',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      )
          : ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final n = _items[i];
          final color = _iconColor(theme, n.type);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: n.isRead
                  ? theme.colorScheme.surface
                  : theme.colorScheme.primaryContainer.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: n.isRead
                    ? theme.colorScheme.outlineVariant.withOpacity(0.3)
                    : theme.colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(_icon(n.type), color: color, size: 22),
              ),
              title: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                  ),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.message,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo(n.createdAt),
                    style: TextStyle(
                      color: theme.colorScheme.outline,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              trailing: n.isRead
                  ? null
                  : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              onTap: () => _open(n),
            ),
          );
        },
      ),
    );
  }
}