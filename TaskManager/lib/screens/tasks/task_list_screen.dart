import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/task_filter.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/task_service.dart';
import '../../utils/format.dart';
import '../../widgets/task_card.dart';
import '../../widgets/task_filter_sheet.dart';
import '../auth/login_screen.dart';
import '../notifications/notification_screen.dart';
import '../profile/profile_screen.dart';
import 'task_create_screen.dart';
import 'task_detail_screen.dart';

Future<void> logoutAndGoToLogin(BuildContext context) async {
  await AuthService.logout();
  unreadCount.value = 0;
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
  );
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  Timer? _timer;
  Timer? _debounce;
  final _searchCtl = TextEditingController();
  TaskFilter _filter = const TaskFilter();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    NotificationService.refreshUnread();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
          (_) => NotificationService.refreshUnread(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _filter = _filter.withQuery(text.trim()));
    });
  }

  void _closeSearch() {
    _debounce?.cancel();
    _searchCtl.clear();
    setState(() {
      _searching = false;
      _filter = _filter.withQuery('');
    });
  }

  Future<void> _openFilter() async {
    final result = await showTaskFilterSheet(context, _filter);
    if (result != null && mounted) setState(() => _filter = result);
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationScreen()),
    );
    NotificationService.refreshUnread();
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    notifyTasksChanged();
  }

  Widget _activeFilters() {
    final chips = <Widget>[
      if (_filter.status != null)
        InputChip(
          label: Text(statusLabel(_filter.status!)),
          onDeleted: () => setState(() => _filter = _filter.withoutStatus()),
        ),
      if (_filter.priority != null)
        InputChip(
          label: Text(priorityLabel(_filter.priority!)),
          onDeleted: () => setState(() => _filter = _filter.withoutPriority()),
        ),
      if (_filter.assignee != null)
        InputChip(
          label: Text('Phụ trách: ${_filter.assignee!.fullName}'),
          onDeleted: () => setState(() => _filter = _filter.withoutAssignee()),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Wrap(spacing: 8, runSpacing: 4, children: chips),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterOn = _filter.status != null ||
        _filter.priority != null ||
        _filter.assignee != null ||
        _filter.isCustomSort;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
            controller: _searchCtl,
            autofocus: true,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Tìm theo tên công việc',
              border: InputBorder.none,
            ),
          )
              : const Text('Công việc'),
          actions: [
            if (_searching)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Đóng tìm kiếm',
                onPressed: _closeSearch,
              )
            else
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Tìm kiếm',
                onPressed: () => setState(() => _searching = true),
              ),
            IconButton(
              tooltip: 'Lọc và sắp xếp',
              onPressed: _openFilter,
              icon: Badge(
                isLabelVisible: filterOn,
                child: const Icon(Icons.filter_list),
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: unreadCount,
              builder: (context, count, _) => IconButton(
                tooltip: 'Thông báo',
                onPressed: _openNotifications,
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: 'Cá nhân và thống kê',
              onPressed: _openProfile,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Của tôi'),
              Tab(text: 'Được giao'),
              Tab(text: 'Được chia sẻ'),
            ],
          ),
        ),
        body: Column(
          children: [
            _activeFilters(),
            Expanded(
              child: TabBarView(
                children: [
                  TaskTab(scope: 'created', filter: _filter),
                  TaskTab(scope: 'assigned', filter: _filter),
                  TaskTab(scope: 'shared', filter: _filter),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TaskCreateScreen()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Thêm việc'),
        ),
      ),
    );
  }
}

class TaskTab extends StatefulWidget {
  final String scope;
  final TaskFilter filter;
  const TaskTab({super.key, required this.scope, required this.filter});

  @override
  State<TaskTab> createState() => _TaskTabState();
}

class _TaskTabState extends State<TaskTab> {
  late Future<List<Task>> _future;

  Future<List<Task>> _fetch() =>
      TaskService.fetchTasks(scope: widget.scope, filter: widget.filter);

  @override
  void initState() {
    super.initState();
    _future = _fetch();
    taskRefresh.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant TaskTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) _future = _fetch();
  }

  @override
  void dispose() {
    taskRefresh.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) _reload();
  }

  Future<void> _reload() async {
    final f = _fetch();
    setState(() {
      _future = f;
    });
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Task>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final err = snap.error;
          final expired = err is ApiException && err.statusCode == 401;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(err.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed:
                    expired ? () => logoutAndGoToLogin(context) : _reload,
                    child: Text(expired ? 'Đăng nhập lại' : 'Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }
        final tasks = snap.data ?? [];
        return RefreshIndicator(
          onRefresh: _reload,
          child: tasks.isEmpty
              ? ListView(
            children: [
              const SizedBox(height: 200),
              Center(
                child: Text(widget.filter.isActive
                    ? 'Không có công việc phù hợp với bộ lọc'
                    : 'Chưa có công việc nào'),
              ),
            ],
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
            itemCount: tasks.length,
            itemBuilder: (context, i) => TaskCard(
              task: tasks[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskDetailScreen(taskId: tasks[i].id),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}