import 'package:flutter/material.dart';
import '../../models/task_share.dart';
import '../../models/user.dart';
import '../../services/task_service.dart';
import '../../services/task_share_service.dart';
import '../../widgets/user_selector.dart';

class TaskSharingScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final String? ownerId;
  const TaskSharingScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
    this.ownerId,
  });

  @override
  State<TaskSharingScreen> createState() => _TaskSharingScreenState();
}

class _TaskSharingScreenState extends State<TaskSharingScreen> {
  List<TaskShare> _shares = [];
  List<AppUser> _selected = [];
  String _newPermission = 'viewer';
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
      final list = await TaskShareService.list(widget.taskId);
      if (!mounted) return;
      setState(() {
        _shares = list;
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

  Future<void> _run(Future<List<TaskShare>> Function() action,
      {String? success, bool clearSelection = false}) async {
    setState(() => _busy = true);
    try {
      final list = await action();
      notifyTasksChanged();
      if (!mounted) return;
      setState(() {
        _shares = list;
        if (clearSelection) _selected = [];
      });
      if (success != null) _toast(success);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRevoke(TaskShare s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi quyền?'),
        content: Text(
            'Người này sẽ không còn truy cập được công việc: ${s.user?.fullName ?? 'Người dùng đã bị xóa'}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Thu hồi')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => TaskShareService.revoke(widget.taskId, s.id),
        success: 'Đã thu hồi quyền chia sẻ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chia sẻ công việc')),
      body: _buildBody(),
    );
  }

  Widget _permissionButton(String value, void Function(String) onPick,
      {required bool enabled}) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 'viewer', label: Text('Chỉ xem')),
        ButtonSegment(value: 'editor', label: Text('Chỉnh sửa')),
      ],
      selected: {value},
      onSelectionChanged:
      enabled ? (Set<String> v) => onPick(v.first) : null,
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

    final excluded = <String>{
      ..._shares.where((s) => s.user != null).map((s) => s.user!.id),
      if (widget.ownerId != null) widget.ownerId!,
    };

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
        Text('Đã chia sẻ (${_shares.length})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_shares.isEmpty) const Text('Chưa chia sẻ cho ai'),
        ..._shares.map(
              (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text((s.user?.fullName ?? '?').isNotEmpty
                      ? (s.user?.fullName ?? '?')[0].toUpperCase()
                      : '?'),
                ),
                title: Text(s.user?.fullName ?? 'Người dùng đã bị xóa',
                    overflow: TextOverflow.ellipsis),
                subtitle:
                Text(s.user?.email ?? '', overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Thu hồi quyền',
                  onPressed: _busy ? null : () => _confirmRevoke(s),
                ),
              ),
              _permissionButton(
                s.permission,
                    (v) => _run(
                      () => TaskShareService.updatePermission(
                      widget.taskId, s.id, v),
                  success: 'Đã đổi quyền: ${permissionLabel(v)}',
                ),
                enabled: !_busy,
              ),
              const Divider(height: 24),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Chia sẻ thêm',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        UserSelector(
          selected: _selected,
          excludeIds: excluded,
          onChanged: (list) => setState(() => _selected = list),
        ),
        const SizedBox(height: 16),
        const Text('Quyền cấp cho những người chọn'),
        const SizedBox(height: 8),
        _permissionButton(
          _newPermission,
              (v) => setState(() => _newPermission = v),
          enabled: !_busy,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: (_selected.isEmpty || _busy)
                ? null
                : () => _run(
                  () => TaskShareService.add(
                  widget.taskId,
                  _selected.map((u) => u.id).toList(),
                  _newPermission),
              success: 'Đã chia sẻ công việc',
              clearSelection: true,
            ),
            icon: const Icon(Icons.share_outlined),
            label: Text(_selected.isEmpty
                ? 'Chia sẻ'
                : 'Chia sẻ cho ${_selected.length} người'),
          ),
        ),
      ],
    );
  }
}