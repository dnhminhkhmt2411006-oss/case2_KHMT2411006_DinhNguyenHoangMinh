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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        return Icons.assignment_ind_outlined;
      case 'task_shared':
        return Icons.share_outlined;
      case 'share_updated':
        return Icons.manage_accounts_outlined;
      case 'share_revoked':
        return Icons.block;
      case 'status_changed':
        return Icons.autorenew;
      case 'due_changed':
        return Icons.event_outlined;
      default:
        return Icons.notifications_outlined;
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
    final hasUnread = _items.any((e) => !e.isRead);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: hasUnread ? _markAll : null,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(showSpinner: false),
      child: _items.isEmpty
          ? ListView(
        children: const [
          SizedBox(height: 200),
          Center(child: Text('Chưa có thông báo nào')),
        ],
      )
          : ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final n = _items[i];
          return ListTile(
            isThreeLine: true,
            tileColor: n.isRead
                ? null
                : Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.06),
            leading: CircleAvatar(child: Icon(_icon(n.type))),
            title: Text(
              n.title,
              style: TextStyle(
                  fontWeight:
                  n.isRead ? FontWeight.normal : FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.message),
                const SizedBox(height: 4),
                Text(
                  _timeAgo(n.createdAt),
                  style:
                  const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            trailing: n.isRead
                ? null
                : const Icon(Icons.circle, size: 10, color: Colors.indigo),
            onTap: () => _open(n),
          );
        },
      ),
    );
  }
}