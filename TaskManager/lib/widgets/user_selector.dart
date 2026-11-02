import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/task_service.dart' show ApiException;
import '../services/user_service.dart';

// Ô tìm người theo tên hoặc email, chọn được nhiều người
class UserSelector extends StatefulWidget {
  final List<AppUser> selected;
  final Set<String> excludeIds;
  final ValueChanged<List<AppUser>> onChanged;

  const UserSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.excludeIds = const {},
  });

  @override
  State<UserSelector> createState() => _UserSelectorState();
}

class _UserSelectorState extends State<UserSelector> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<AppUser> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    _debounce?.cancel();
    final q = text.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await UserService.search(q);
      if (!mounted || _controller.text.trim() != q) return;
      setState(() {
        _results = users;
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

  bool _isSelected(AppUser u) => widget.selected.any((s) => s.id == u.id);

  void _toggle(AppUser u) {
    final list = [...widget.selected];
    if (_isSelected(u)) {
      list.removeWhere((s) => s.id == u.id);
    } else {
      list.add(u);
    }
    widget.onChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    final q = _controller.text.trim();
    final visible =
    _results.where((u) => !widget.excludeIds.contains(u.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onTextChanged,
          decoration: InputDecoration(
            labelText: 'Tìm theo tên hoặc email',
            hintText: 'Nhập ít nhất 2 ký tự',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _loading
                ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : null,
          ),
        ),
        if (widget.selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.selected
                  .map((u) => InputChip(
                label: Text(u.fullName),
                onDeleted: () => _toggle(u),
              ))
                  .toList(),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          )
        else if (!_loading && q.length >= 2 && visible.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Không tìm thấy người dùng phù hợp'),
          ),
        ...visible.map(
              (u) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _isSelected(u),
            onChanged: (_) => _toggle(u),
            title: Text(u.fullName),
            subtitle: Text(u.email),
          ),
        ),
      ],
    );
  }
}