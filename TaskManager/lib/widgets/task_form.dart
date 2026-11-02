import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/format.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _dateField(String label, DateTime? value, bool isStart) {
    return InkWell(
      onTap: () => _pickDate(isStart),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today)
              : IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() {
              if (isStart) {
                _start = null;
              } else {
                _due = null;
              }
            }),
          ),
        ),
        child: Text(value == null ? 'Chưa đặt' : formatDate(value)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Tên công việc *', border: OutlineInputBorder()),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Nhập tên công việc' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _desc,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            _dateField('Ngày bắt đầu', _start, true),
            const SizedBox(height: 16),
            _dateField('Hạn hoàn thành', _due, false),
            if (_dateError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_dateError!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12)),
                ),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(
                  labelText: 'Mức ưu tiên', border: OutlineInputBorder()),
              items: ['low', 'medium', 'high']
                  .map((p) =>
                  DropdownMenuItem(value: p, child: Text(priorityLabel(p))))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v ?? _priority),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                  labelText: 'Trạng thái', border: OutlineInputBorder()),
              items: ['todo', 'in_progress', 'completed']
                  .map((s) =>
                  DropdownMenuItem(value: s, child: Text(statusLabel(s))))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.submitLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}