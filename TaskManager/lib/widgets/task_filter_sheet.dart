import 'package:flutter/material.dart';
import '../models/task_filter.dart';
import '../models/user.dart';
import '../utils/format.dart';
import 'user_selector.dart';

const Map<String, String> _sortLabels = {
  'dueDate': 'Hạn hoàn thành',
  'startDate': 'Ngày bắt đầu',
  'createdAt': 'Ngày tạo',
  'title': 'Tên công việc',
  'priority': 'Mức ưu tiên',
  'status': 'Trạng thái',
};

// Hộp thoại lọc và sắp xếp; trả về bộ lọc mới, hoặc null nếu đóng mà không áp dụng
Future<TaskFilter?> showTaskFilterSheet(
    BuildContext context, TaskFilter current) {
  return showModalBottomSheet<TaskFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _FilterSheet(initial: current),
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  final TaskFilter initial;
  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _status = widget.initial.status;
  late String? _priority = widget.initial.priority;
  late AppUser? _assignee = widget.initial.assignee;
  late String _sortBy = widget.initial.sortBy;
  late String _order = widget.initial.order;

  void _reset() {
    setState(() {
      _status = null;
      _priority = null;
      _assignee = null;
      _sortBy = 'dueDate';
      _order = 'asc';
    });
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
  );

  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Lọc và sắp xếp',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                TextButton(onPressed: _reset, child: const Text('Đặt lại')),
              ],
            ),
            _section('Trạng thái'),
            Wrap(
              spacing: 8,
              children: [
                _chip('Tất cả', _status == null,
                        () => setState(() => _status = null)),
                ...['todo', 'in_progress', 'completed'].map((s) => _chip(
                    statusLabel(s), _status == s,
                        () => setState(() => _status = s))),
              ],
            ),
            _section('Mức ưu tiên'),
            Wrap(
              spacing: 8,
              children: [
                _chip('Tất cả', _priority == null,
                        () => setState(() => _priority = null)),
                ...['high', 'medium', 'low'].map((p) => _chip(
                    priorityLabel(p), _priority == p,
                        () => setState(() => _priority = p))),
              ],
            ),
            _section('Người phụ trách'),
            UserSelector(
              selected: _assignee == null ? [] : [_assignee!],
              onChanged: (list) =>
                  setState(() => _assignee = list.isEmpty ? null : list.last),
            ),
            _section('Sắp xếp theo'),
            DropdownButtonFormField<String>(
              initialValue: _sortBy,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _sortLabels.entries
                  .map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _sortBy = v ?? _sortBy),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'asc', label: Text('Tăng dần')),
                ButtonSegment(value: 'desc', label: Text('Giảm dần')),
              ],
              selected: {_order},
              onSelectionChanged: (v) => setState(() => _order = v.first),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  TaskFilter(
                    query: widget.initial.query,
                    status: _status,
                    priority: _priority,
                    assignee: _assignee,
                    sortBy: _sortBy,
                    order: _order,
                  ),
                ),
                child: const Text('Áp dụng'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}