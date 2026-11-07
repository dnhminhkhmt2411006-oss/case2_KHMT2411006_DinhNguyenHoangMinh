import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/models/task.dart';
import 'package:taskmanager/models/task_filter.dart';
import 'package:taskmanager/models/user.dart';
import 'package:taskmanager/utils/format.dart';

void main() {
  group('TaskFilter', () {
    test('mặc định không lọc và sắp xếp theo hạn tăng dần', () {
      const f = TaskFilter();
      expect(f.isActive, false);
      expect(f.isCustomSort, false);
      expect(f.toQueryParams('created'),
          {'scope': 'created', 'sortBy': 'dueDate', 'order': 'asc'});
    });

    test('toQueryParams chỉ chứa điều kiện đã chọn và cắt khoảng trắng', () {
      const user = AppUser(id: 'u1', fullName: 'Lan', email: 'lan@x.com');
      const f = TaskFilter(
        query: '  bao cao ',
        status: 'todo',
        priority: 'high',
        assignee: user,
        sortBy: 'priority',
        order: 'desc',
      );
      expect(f.isActive, true);
      expect(f.isCustomSort, true);
      expect(f.toQueryParams('assigned'), {
        'scope': 'assigned',
        'q': 'bao cao',
        'status': 'todo',
        'priority': 'high',
        'assigneeId': 'u1',
        'sortBy': 'priority',
        'order': 'desc',
      });
    });

    test('bỏ từng điều kiện lọc', () {
      const f = TaskFilter(status: 'todo', priority: 'high');
      expect(f.withoutStatus().status, isNull);
      expect(f.withoutStatus().priority, 'high');
      expect(f.withoutPriority().priority, isNull);
    });

    test('hai bộ lọc giống nhau thì bằng nhau', () {
      expect(const TaskFilter(status: 'todo'), const TaskFilter(status: 'todo'));
      expect(const TaskFilter(status: 'todo') == const TaskFilter(), false);
    });
  });

  group('Task.fromJson', () {
    test('đọc đủ thông tin công việc và quyền của người dùng', () {
      final task = Task.fromJson({
        '_id': 't1',
        'title': 'Báo cáo',
        'description': 'Nộp thứ Sáu',
        'createdBy': {'_id': 'u1', 'fullName': 'Minh', 'email': 'm@x.com'},
        'assigneeIds': [
          {'_id': 'u2', 'fullName': 'Lan', 'email': 'l@x.com'}
        ],
        'primaryAssigneeId': 'u2',
        'dueDate': '2026-11-20T00:00:00.000Z',
        'priority': 'high',
        'status': 'in_progress',
        'myAccess': {
          'isOwner': true,
          'isAssignee': false,
          'shareRole': null,
          'canEdit': true,
          'canChangeStatus': true,
          'canDelete': true,
          'canManage': true,
        },
      });
      expect(task.id, 't1');
      expect(task.createdBy?.fullName, 'Minh');
      expect(task.assignees.single.email, 'l@x.com');
      expect(task.primaryAssigneeId, 'u2');
      expect(task.priority, 'high');
      expect(task.status, 'in_progress');
      expect(task.dueDate, isNotNull);
      expect(task.access!.isOwner, true);
      expect(task.access!.canDelete, true);
    });

    test('thiếu dữ liệu thì dùng giá trị mặc định', () {
      final task = Task.fromJson({'_id': 't2', 'title': 'Trống'});
      expect(task.priority, 'medium');
      expect(task.status, 'todo');
      expect(task.assignees, isEmpty);
      expect(task.dueDate, isNull);
      expect(task.access, isNull);
    });
  });

  group('Định dạng hiển thị', () {
    test('formatDate', () {
      expect(formatDate(null), 'Chưa đặt');
      expect(formatDate(DateTime(2026, 11, 5)), '05/11/2026');
    });

    test('nhãn ưu tiên và trạng thái', () {
      expect(priorityLabel('high'), 'Ưu tiên cao');
      expect(priorityLabel('low'), 'Ưu tiên thấp');
      expect(statusLabel('completed'), 'Hoàn thành');
      expect(statusLabel('in_progress'), 'Đang làm');
      expect(statusLabel('todo'), 'Cần làm');
    });
  });
}