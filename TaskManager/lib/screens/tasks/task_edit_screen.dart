import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../widgets/task_form.dart';

class TaskEditScreen extends StatelessWidget {
  final Task task;
  const TaskEditScreen({super.key, required this.task});

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
          'Sửa công việc',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: TaskForm(
          initial: task,
          submitLabel: 'Lưu thay đổi',
          onSubmit: (data) async {
            try {
              await TaskService.updateTask(task.id, data);
              notifyTasksChanged();
              if (context.mounted) Navigator.pop(context, true);
              return null;
            } on ApiException catch (e) {
              return e.message;
            }
          },
        ),
      ),
    );
  }
}