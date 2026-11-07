import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/format.dart';
import 'task_card.dart' show TagLabel;

class TaskForm extends StatefulWidget {
  final Task? initial;
  final String submitLabel;
  // Trả về null nếu thành công, ngược lại trả về thông báo lỗi
  final Future<String?> Function(Map<String, dynamic> data) onSubmit;

  const TaskForm({
    super.key,
    this.initial,
    required this.submitLabel,
    required this.onSubmit,
  });

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  DateTime? _start;
  DateTime? _due;
  late String _priority;
  late String _status;
  bool _saving = false;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _title = TextEditingController(text: t?.title ?? '');
    _desc = TextEditingController(text: t?.description ?? '');
    _start = t?.startDate;
    _due = t?.dueDate;
    _priority = t?.priority ?? 'medium';
    _status = t?.status ?? 'todo';
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final current = (isStart ? _start : _due) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _due = picked;
      }
      _dateError = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_start != null && _due != null && _due!.isBefore(_start!)) {
      setState(() => _dateError = 'Hạn hoàn thành phải sau ngày bắt đầu');
      return;
    }
    setState(() {
      _saving = true;
      _dateError = null;
    });
    final data = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'priority': _priority,
      'status': _status,
      'startDate': _start?.toUtc().toIso8601String(),
      'dueDate': _due?.toUtc().toIso8601String(),
    };
    final error = await widget.onSubmit(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _dateField(ThemeData theme, String label, DateTime? value, bool isStart) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _pickDate(isStart),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            isStart ? Icons.play_circle_outline_rounded : Icons.event_rounded,
            color: theme.colorScheme.primary,
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_rounded, size: 20)
              : IconButton(
            icon: const Icon(Icons.clear_rounded, size: 20),
            onPressed: () => setState(() {
              if (isStart) {
                _start = null;
              } else {
                _due = null;
              }
            }),
          ),
        ),
        child: Text(
          value == null ? 'Chưa đặt ngày' : formatDate(value),
          style: TextStyle(
            color: value == null
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
            fontWeight: value == null ? FontWeight.normal : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Tên công việc ---
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Tên công việc *',
                hintText: 'Ví dụ: Báo cáo doanh thu tháng',
                prefixIcon: const Icon(Icons.title_rounded),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.error),
                ),
              ),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên công việc' : null,
            ),
            const SizedBox(height: 18),

            // --- Mô tả công việc ---
            TextFormField(
              controller: _desc,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Mô tả chi tiết',
                hintText: 'Thêm ghi chú hoặc thông tin bổ sung...',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.description_outlined),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // --- Ngày bắt đầu & Ngày hạn ---
            _dateField(theme, 'Ngày bắt đầu', _start, true),
            const SizedBox(height: 18),
            _dateField(theme, 'Hạn hoàn thành', _due, false),
            if (_dateError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  _dateError!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 18),

            // --- Mức ưu tiên ---
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: InputDecoration(
                labelText: 'Mức ưu tiên',
                prefixIcon: const Icon(Icons.flag_outlined),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
              ),
              items: ['low', 'medium', 'high']
                  .map((p) => DropdownMenuItem(
                value: p,
                child: Row(
                  children: [
                    TagLabel(text: priorityLabel(p), color: priorityColor(p)),
                  ],
                ),
              ))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v ?? _priority),
            ),
            const SizedBox(height: 18),

            // --- Trạng thái ---
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: InputDecoration(
                labelText: 'Trạng thái',
                prefixIcon: const Icon(Icons.label_outlined),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
              ),
              items: ['todo', 'in_progress', 'completed']
                  .map((s) => DropdownMenuItem(
                value: s,
                child: Row(
                  children: [
                    TagLabel(text: statusLabel(s), color: statusColor(s)),
                  ],
                ),
              ))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 32),

            // --- Button Submit ---
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
                    : Text(
                  widget.submitLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}