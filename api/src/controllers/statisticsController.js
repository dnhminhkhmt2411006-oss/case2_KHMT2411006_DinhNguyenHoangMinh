const Task = require('../models/Task');
const { accessibleFilter } = require('../utils/taskAccess');

const DAY = 24 * 60 * 60 * 1000;

const emptyCounts = () => ({ total: 0, todo: 0, in_progress: 0, completed: 0 });

function countBy(tasks) {
  const c = emptyCounts();
  tasks.forEach((t) => {
    c.total += 1;
    if (c[t.status] !== undefined) c[t.status] += 1;
  });
  return c;
}

// Tất cả công việc người dùng được phép xem
async function loadTasks(userId) {
  const filter = await accessibleFilter(userId);
  return Task.find(filter)
    .select('title status priority dueDate createdBy assigneeIds primaryAssigneeId')
    .lean();
}

// Hạn tính đến hết ngày theo giờ của máy chủ
function endOfDay(d) {
  const x = new Date(d);
  x.setHours(23, 59, 59, 999);
  return x;
}

const toItem = (t) => ({
  id: t._id,
  title: t.title,
  dueDate: t.dueDate,
  status: t.status,
  priority: t.priority,
});

const byDueAsc = (a, b) => new Date(a.dueDate) - new Date(b.dueDate);

// GET /statistics/tasks
exports.byStatus = async (req, res) => {
  const tasks = await loadTasks(req.user._id);
  res.json(countBy(tasks));
};

// GET /statistics/assignments
exports.assignments = async (req, res) => {
  const uid = String(req.user._id);
  const tasks = await loadTasks(req.user._id);

  const assignedToMe = tasks.filter((t) => (t.assigneeIds || []).some((id) => String(id) === uid));
  const primaryForMe = tasks.filter((t) => t.primaryAssigneeId && String(t.primaryAssigneeId) === uid);
  const createdByMe = tasks.filter((t) => String(t.createdBy) === uid);

  res.json({
    assignedToMe: countBy(assignedToMe),
    primaryForMe: countBy(primaryForMe),
    createdByMe: countBy(createdByMe),
    assignedByMe: createdByMe.filter((t) => (t.assigneeIds || []).length > 0).length,
  });
};

// GET /statistics/deadlines?days=3
exports.deadlines = async (req, res) => {
  const days = Math.min(Math.max(parseInt(req.query.days, 10) || 3, 1), 30);
  const tasks = await loadTasks(req.user._id);

  const now = new Date();
  const todayStart = new Date(now);
  todayStart.setHours(0, 0, 0, 0);
  const todayEnd = endOfDay(now);
  const soonEnd = endOfDay(new Date(now.getTime() + days * DAY));

  const open = tasks.filter((t) => t.status !== 'completed');
  const withDue = open.filter((t) => t.dueDate);

  const overdue = withDue.filter((t) => endOfDay(t.dueDate) < now).sort(byDueAsc);
  const dueToday = withDue.filter((t) => {
    const d = new Date(t.dueDate);
    return d >= todayStart && d <= todayEnd;
  });
  const dueSoon = withDue
    .filter((t) => endOfDay(t.dueDate) >= now && new Date(t.dueDate) <= soonEnd)
    .sort(byDueAsc);

  res.json({
    days,
    overdue: { count: overdue.length, items: overdue.slice(0, 20).map(toItem) },
    dueToday: { count: dueToday.length },
    dueSoon: { count: dueSoon.length, items: dueSoon.slice(0, 20).map(toItem) },
    noDueDate: { count: open.filter((t) => !t.dueDate).length },
  });
};