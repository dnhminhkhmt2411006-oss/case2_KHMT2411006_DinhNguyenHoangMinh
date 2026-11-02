import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../widgets/task_card.dart';
import '../auth/login_screen.dart';
import 'task_create_screen.dart';
import 'task_detail_screen.dart';

Future<void> logoutAndGoToLogin(BuildContext context) async {
  await AuthService.logout();
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
  );
}

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Công việc'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Đăng xuất',
              onPressed: () => logoutAndGoToLogin(context),
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
        body: const TabBarView(
          children: [
            TaskTab(scope: 'created'),
            TaskTab(scope: 'assigned'),
            TaskTab(scope: 'shared'),
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
  const TaskTab({super.key, required this.scope});

  @override
  State<TaskTab> createState() => _TaskTabState();
}

class _TaskTabState extends State<TaskTab> {
  late Future<List<Task>> _future;

  @override
  void initState() {
    super.initState();
    _future = TaskService.fetchTasks(scope: widget.scope);
    taskRefresh.addListener(_onChanged);
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
    final f = TaskService.fetchTasks(scope: widget.scope);
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
            children: const [
              SizedBox(height: 200),
              Center(child: Text('Chưa có công việc nào')),
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