import 'package:flutter/material.dart';

String formatDate(DateTime? d) {
  if (d == null) return 'Chưa đặt';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

String priorityLabel(String p) {
  switch (p) {
    case 'high':
      return 'Ưu tiên cao';
    case 'low':
      return 'Ưu tiên thấp';
    default:
      return 'Ưu tiên vừa';
  }
}

Color priorityColor(String p) {
  switch (p) {
    case 'high':
      return Colors.red;
    case 'low':
      return Colors.green;
    default:
      return Colors.orange;
  }
}

String statusLabel(String s) {
  switch (s) {
    case 'in_progress':
      return 'Đang làm';
    case 'completed':
      return 'Hoàn thành';
    default:
      return 'Cần làm';
  }
}

Color statusColor(String s) {
  switch (s) {
    case 'in_progress':
      return Colors.blue;
    case 'completed':
      return Colors.green;
    default:
      return Colors.blueGrey;
  }
}