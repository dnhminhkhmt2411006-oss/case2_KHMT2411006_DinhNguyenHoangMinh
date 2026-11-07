import 'package:flutter/material.dart';
import '../../services/task_service.dart';
import '../../widgets/task_form.dart';

class TaskCreateScreen extends StatelessWidget {
  const TaskCreateScreen({super.key});

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
          'Thêm công việc mới',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: TaskForm(
          submitLabel: 'Tạo công việc',
          onSubmit: (data) async {
            try {
              await TaskService.createTask(data);
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