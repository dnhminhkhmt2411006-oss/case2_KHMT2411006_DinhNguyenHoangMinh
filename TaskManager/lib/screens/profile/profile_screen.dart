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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
    final theme = Theme.of(context);

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
          'Cá nhân và thống kê',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
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
    final user = _user!;
    final s = _stats!;
    return RefreshIndicator(
      onRefresh: () => _load(spinner: false),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          _profileCard(theme, user),
          const SizedBox(height: 24),
          _title(theme, 'Thống kê theo trạng thái'),
          _statusCard(theme, s.tasks),
          const SizedBox(height: 24),
          _title(theme, 'Việc được giao và phụ trách'),
          _assignmentCard(theme, s.assignments),
          const SizedBox(height: 24),
          _title(theme, 'Hạn hoàn thành'),
          _deadlineCards(theme, s.deadlines),
          _deadlineList(theme, 'Đã quá hạn', s.deadlines.overdue, Colors.redAccent),
          _deadlineList(
            theme,
            'Sắp đến hạn (${s.deadlines.days} ngày tới)',
            s.deadlines.dueSoon,
            Colors.orange,
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Đăng xuất',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _title(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 4),
    child: Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    ),
  );

  Widget _profileCard(ThemeData theme, AppUser user) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user.fullName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              user.email,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _editName,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Đổi tên'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _changePassword,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: const Text('Đổi mật khẩu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(ThemeData theme, StatusCounts c) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng số công việc',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${c.total}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 0.5),
            _StatBar(
              label: 'Cần làm',
              value: c.todo,
              total: c.total,
              color: statusColor('todo'),
            ),
            const SizedBox(height: 12),
            _StatBar(
              label: 'Đang làm',
              value: c.inProgress,
              total: c.total,
              color: statusColor('in_progress'),
            ),
            const SizedBox(height: 12),
            _StatBar(
              label: 'Hoàn thành',
              value: c.completed,
              total: c.total,
              color: statusColor('completed'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assignmentCard(ThemeData theme, AssignmentStats a) {
    Widget row(String label, String value, {bool isSub = false, bool isBold = false}) => Padding(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: isSub ? 12 : 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isSub ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isSub ? 13 : 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isBold ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            row('Được giao cho tôi', '${a.assignedToMe.total}', isBold: true),
            row('Đang làm', '${a.assignedToMe.inProgress}', isSub: true),
            row('Hoàn thành', '${a.assignedToMe.completed}', isSub: true),
            const Divider(height: 20, thickness: 0.5),
            row('Tôi phụ trách chính', '${a.primaryForMe.total}', isBold: true),
            const Divider(height: 20, thickness: 0.5),
            row('Tôi tạo', '${a.createdByMe.total}', isBold: true),
            row('Đã giao cho người khác', '${a.assignedByMe}', isSub: true),
          ],
        ),
      ),
    );
  }

  Widget _deadlineCards(ThemeData theme, DeadlineStats d) {
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: 'Quá hạn',
            value: d.overdueCount,
            color: Colors.redAccent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            label: 'Hôm nay',
            value: d.dueTodayCount,
            color: Colors.deepOrangeAccent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            label: 'Sắp tới',
            value: d.dueSoonCount,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            label: 'Chưa hạn',
            value: d.noDueDateCount,
            color: Colors.blueGrey,
          ),
        ),
      ],
    );
  }

  Widget _deadlineList(ThemeData theme, String title, List<DeadlineItem> items, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
                (it) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                dense: true,
                leading: Icon(Icons.event_rounded, color: color, size: 20),
                title: Text(
                  it.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('Hạn: ${formatDate(it.dueDate)}'),
                trailing: TagLabel(
                  text: statusLabel(it.status),
                  color: statusColor(it.status),
                ),
                onTap: () => _openTask(it.id),
              ),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : value / total,
            minHeight: 8,
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
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
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
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
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Đổi tên hiển thị'),
      content: TextField(
        controller: _ctl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Họ tên',
          prefixIcon: const Icon(Icons.person_outline_rounded),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctl.text.trim()),
          child: const Text('Lưu'),
        ),
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

  Widget _field(ThemeData theme, TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: c,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Đổi mật khẩu'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(theme, _current, 'Mật khẩu hiện tại'),
            _field(theme, _new, 'Mật khẩu mới'),
            _field(theme, _confirm, 'Xác nhận mật khẩu mới'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Đổi mật khẩu'),
        ),
      ],
    );
  }
}