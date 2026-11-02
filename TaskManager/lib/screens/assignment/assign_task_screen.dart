import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/assignment_service.dart';
import '../../services/task_service.dart';
import '../../widgets/task_card.dart' show TagLabel;
import '../../widgets/user_selector.dart';

class AssignTaskScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  const AssignTaskScreen(
      {super.key, required this.taskId, required this.taskTitle});

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  List<Assignee> _assignees = [];
  List<AppUser> _selected = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AssignmentService.list(widget.taskId);
      if (!mounted) return;
      setState(() {
        _assignees = list;
        _loading = false;
      });
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

  Future<void> _run(Future<List<Assignee>> Function() action,
      {String? success, bool clearSelection = false}) async {
    setState(() => _busy = true);
    try {
      final list = await action();
      notifyTasksChanged();
      if (!mounted) return;
      setState(() {
        _assignees = list;
        if (clearSelection) _selected = [];
      });
      if (success != null) _toast(success);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRemove(Assignee a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy giao việc?'),
        content: Text('Bỏ giao việc cho ${a.user.fullName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đồng ý')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => AssignmentService.remove(widget.taskId, a.user.id),
        success: 'Đã hủy giao việc');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giao việc')),
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

    final excluded = _assignees.map((a) => a.user.id).toSet();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.taskTitle,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text('Người được giao (${_assignees.length})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_assignees.isEmpty) const Text('Chưa giao cho ai'),
        ..._assignees.map(
              (a) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(a.user.fullName.isNotEmpty
                  ? a.user.fullName[0].toUpperCase()
                  : '?'),
            ),
            title: Text(a.user.fullName, overflow: TextOverflow.ellipsis),
            subtitle: Text(a.user.email, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (a.isPrimary)
                  const TagLabel(text: 'Phụ trách chính', color: Colors.indigo)
                else
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                          () => AssignmentService.setPrimary(
                          widget.taskId, a.user.id),
                      success: 'Đã đặt người phụ trách chính',
                    ),
                    child: const Text('Đặt làm chính'),
                  ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: 'Hủy giao việc',
                  onPressed: _busy ? null : () => _confirmRemove(a),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 32),
        Text('Giao thêm cho người khác',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        UserSelector(
          selected: _selected,
          excludeIds: excluded,
          onChanged: (list) => setState(() => _selected = list),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: (_selected.isEmpty || _busy)
                ? null
                : () => _run(
                  () => AssignmentService.add(widget.taskId,
                  _selected.map((u) => u.id).toList()),
              success: 'Đã giao việc',
              clearSelection: true,
            ),
            icon: const Icon(Icons.group_add_outlined),
            label: Text(_selected.isEmpty
                ? 'Giao việc'
                : 'Giao việc cho ${_selected.length} người'),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nếu công việc chưa có người phụ trách chính, người đầu tiên được giao sẽ là người phụ trách chính.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}