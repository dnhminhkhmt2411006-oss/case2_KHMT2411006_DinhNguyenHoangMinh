import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../widgets/task_form.dart';

class TaskEditScreen extends StatelessWidget {
  final Task task;
  const TaskEditScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sửa công việc')),
      body: TaskForm(
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
    );
  }
}