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

  Widget _filterChip({
    required IconData icon,
    required String label,
    required VoidCallback onDeleted,
  }) {
    return InputChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close_rounded, size: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _activeFilters(ThemeData theme) {
    final chips = <Widget>[
      if (_filter.status != null)
        _filterChip(
          icon: Icons.flag_outlined,
          label: statusLabel(_filter.status!),
          onDeleted: () => setState(() => _filter = _filter.withoutStatus()),
        ),
      if (_filter.priority != null)
        _filterChip(
          icon: Icons.label_outlined,
          label: priorityLabel(_filter.priority!),
          onDeleted: () => setState(() => _filter = _filter.withoutPriority()),
        ),
      if (_filter.assignee != null)
        _filterChip(
          icon: Icons.person_outline_rounded,
          label: 'Phụ trách: ${_filter.assignee!.fullName}',
          onDeleted: () => setState(() => _filter = _filter.withoutAssignee()),
        ),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: chips
              .map((chip) => Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: chip,
          ))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filterOn = _filter.status != null ||
        _filter.priority != null ||
        _filter.assignee != null ||
        _filter.isCustomSort;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 2,
          title: _searching
              ? TextField(
            controller: _searchCtl,
            autofocus: true,
            onChanged: _onSearchChanged,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên công việc...',
              hintStyle:
              TextStyle(color: theme.colorScheme.onSurfaceVariant),
              border: InputBorder.none,
            ),
          )
              : Text(
            'Công việc',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (_searching)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Đóng tìm kiếm',
                onPressed: _closeSearch,
              )
            else
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Tìm kiếm',
                onPressed: () => setState(() => _searching = true),
              ),
            IconButton(
              tooltip: 'Lọc và sắp xếp',
              onPressed: _openFilter,
              icon: Badge(
                isLabelVisible: filterOn,
                smallSize: 8,
                child: const Icon(Icons.filter_list_rounded),
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
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.normal),
            tabs: const [
              Tab(text: 'Của tôi'),
              Tab(text: 'Được giao'),
              Tab(text: 'Được chia sẻ'),
            ],
          ),
        ),
        body: Column(
          children: [
            _activeFilters(theme),
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
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Thêm việc',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
    final theme = Theme.of(context);

    return FutureBuilder<List<Task>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        if (snap.hasError) {
          final err = snap.error;
          final expired = err is ApiException && err.statusCode == 401;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer
                          .withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 44,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.tonal(
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
              ? LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints:
                BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.filter.isActive
                            ? Icons.filter_alt_off_outlined
                            : Icons.assignment_outlined,
                        size: 64,
                        color: theme.colorScheme.outline
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.filter.isActive
                            ? 'Không có công việc phù hợp với bộ lọc'
                            : 'Chưa có công việc nào',
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
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