import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/format.dart';

class TagLabel extends StatelessWidget {
  final String text;
  final Color color;
  const TagLabel({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  const TaskCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        task.status != 'completed';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Tiêu đề công việc ---
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),

                // --- Ngày hạn hoàn thành ---
                Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 16,
                      color: isOverdue
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Hạn: ${formatDate(task.dueDate)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                        color: isOverdue
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // --- Tag Độ ưu tiên & Trạng thái ---
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    TagLabel(
                      text: priorityLabel(task.priority),
                      color: priorityColor(task.priority),
                    ),
                    TagLabel(
                      text: statusLabel(task.status),
                      color: statusColor(task.status),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}