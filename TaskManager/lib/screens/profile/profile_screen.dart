import 'package:flutter/material.dart';
import '../../models/statistics.dart';
import '../../models/user.dart';
import '../../services/account_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/statistics_service.dart';
import '../../services/task_service.dart' show ApiException;
import '../../utils/format.dart';
import '../../widgets/task_card.dart' show TagLabel;
import '../auth/login_screen.dart';
import '../tasks/task_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppUser? _user;
  Statistics? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool spinner = true}) async {
    if (spinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        AccountService.me(),
        StatisticsService.load(),
      ]);
      if (!mounted) return;
      setState(() {
        _user = results[0] as AppUser;
        _stats = results[1] as Statistics;
        _loading = false;
        _error = null;
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

  Future<void> _logout() async {
    await AuthService.logout();
    unreadCount.value = 0;
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  Future<void> _editName() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: _user?.fullName ?? ''),
    );
    if (name == null || name.isEmpty || name == _user?.fullName) return;
    try {
      final u = await AccountService.updateProfile(name);
      if (!mounted) return;
      setState(() => _user = u);
      _toast('Đã cập nhật họ tên');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _changePassword() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (ok == true && mounted) _toast('Đã đổi mật khẩu');
  }

  Future<void> _openTask(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: id)),
    );
    if (mounted) _load(spinner: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân và thống kê')),
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
    final user = _user!;
    final s = _stats!;
    return RefreshIndicator(
      onRefresh: () => _load(spinner: false),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _profileCard(user),
          const SizedBox(height: 20),
          _title('Thống kê theo trạng thái'),
          _statusCard(s.tasks),
          const SizedBox(height: 20),
          _title('Việc được giao và phụ trách'),
          _assignmentCard(s.assignments),
          const SizedBox(height: 20),
          _title('Hạn hoàn thành'),
          _deadlineCards(s.deadlines),
          _deadlineList('Đã quá hạn', s.deadlines.overdue, Colors.red),
          _deadlineList('Sắp đến hạn (${s.deadlines.days} ngày tới)',
              s.deadlines.dueSoon, Colors.orange),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _profileCard(AppUser user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(height: 12),
            Text(user.fullName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(user.email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _editName,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Đổi tên'),
                ),
                OutlinedButton.icon(
                  onPressed: _changePassword,
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Đổi mật khẩu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(StatusCounts c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(child: Text('Tổng số công việc')),
                Text('${c.total}',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            _StatBar(
                label: 'Cần làm',
                value: c.todo,
                total: c.total,
                color: statusColor('todo')),
            const SizedBox(height: 10),
            _StatBar(
                label: 'Đang làm',
                value: c.inProgress,
                total: c.total,
                color: statusColor('in_progress')),
            const SizedBox(height: 10),
            _StatBar(
                label: 'Hoàn thành',
                value: c.completed,
                total: c.total,
                color: statusColor('completed')),
          ],
        ),
      ),
    );
  }

  Widget _assignmentCard(AssignmentStats a) {
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            row('Được giao cho tôi', '${a.assignedToMe.total}'),
            row('   đang làm', '${a.assignedToMe.inProgress}'),
            row('   hoàn thành', '${a.assignedToMe.completed}'),
            const Divider(),
            row('Tôi phụ trách chính', '${a.primaryForMe.total}'),
            const Divider(),
            row('Tôi tạo', '${a.createdByMe.total}'),
            row('   đã giao cho người khác', '${a.assignedByMe}'),
          ],
        ),
      ),
    );
  }

  Widget _deadlineCards(DeadlineStats d) {
    return Row(
      children: [
        Expanded(child: _MiniStat(label: 'Quá hạn', value: d.overdueCount, color: Colors.red)),
        const SizedBox(width: 8),
        Expanded(child: _MiniStat(label: 'Hôm nay', value: d.dueTodayCount, color: Colors.deepOrange)),
        const SizedBox(width: 8),
        Expanded(child: _MiniStat(label: 'Sắp đến hạn', value: d.dueSoonCount, color: Colors.orange)),
        const SizedBox(width: 8),
        Expanded(child: _MiniStat(label: 'Chưa có hạn', value: d.noDueDateCount, color: Colors.blueGrey)),
      ],
    );
  }

  Widget _deadlineList(String title, List<DeadlineItem> items, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ...items.map(
                (it) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.event, color: color),
              title: Text(it.title, overflow: TextOverflow.ellipsis),
              subtitle: Text('Hạn: ${formatDate(it.dueDate)}'),
              trailing: TagLabel(
                  text: statusLabel(it.status), color: statusColor(it.status)),
              onTap: () => _openTask(it.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  const _StatBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('$value'),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : value / total,
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  final String initial;
  const _NameDialog({required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _ctl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi tên hiển thị'),
      content: TextField(
        controller: _ctl,
        autofocus: true,
        decoration: const InputDecoration(
            labelText: 'Họ tên', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _ctl.text.trim()),
            child: const Text('Lưu')),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty) {
      setState(() => _error = 'Nhập mật khẩu hiện tại');
      return;
    }
    if (_new.text.length < 6) {
      setState(() => _error = 'Mật khẩu mới tối thiểu 6 ký tự');
      return;
    }
    if (_new.text != _confirm.text) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AccountService.changePassword(_current.text, _new.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Widget _field(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: c,
      obscureText: true,
      decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi mật khẩu'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_current, 'Mật khẩu hiện tại'),
            _field(_new, 'Mật khẩu mới'),
            _field(_confirm, 'Xác nhận mật khẩu mới'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Hủy')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Đổi mật khẩu'),
        ),
      ],
    );
  }
}