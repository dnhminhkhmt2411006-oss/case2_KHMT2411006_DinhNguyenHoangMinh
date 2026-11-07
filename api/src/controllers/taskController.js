const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const Notification = require('../models/Notification');
const EmailLog = require('../models/EmailLog');
const {
  validateTaskInput,
  checkDateOrder,
  STATUSES,
  PRIORITIES,
} = require('../validators/taskValidator');
const { notifyUsers, involvedUserIds } = require('../services/notificationService');
const { accessibleFilter, escapeRegex } = require('../utils/taskAccess');

const STATUS_TEXT = {
  todo: 'Cần làm',
  in_progress: 'Đang làm',
  completed: 'Hoàn thành',
};

const SCOPES = ['created', 'assigned', 'shared'];
const SORT_FIELDS = ['dueDate', 'startDate', 'createdAt', 'title', 'priority', 'status'];
const PRIORITY_RANK = { low: 1, medium: 2, high: 3 };
const STATUS_RANK = { todo: 1, in_progress: 2, completed: 3 };

function fmtDate(d) {
  const p = (n) => String(n).padStart(2, '0');
  return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()}`;
}

function sortValue(task, sortBy) {
  switch (sortBy) {
    case 'priority':
      return PRIORITY_RANK[task.priority] || 0;
    case 'status':
      return STATUS_RANK[task.status] || 0;
    case 'title':
      return (task.title || '').toLowerCase();
    case 'createdAt':
      return task.createdAt ? task.createdAt.getTime() : null;
    case 'startDate':
      return task.startDate ? task.startDate.getTime() : null;
    default:
      return task.dueDate ? task.dueDate.getTime() : null;
  }
}

// Sắp xếp trong bộ nhớ; công việc chưa có ngày luôn nằm cuối danh sách
function sortTasks(tasks, sortBy, order) {
  const dir = order === 'desc' ? -1 : 1;
  return tasks.sort((a, b) => {
    const x = sortValue(a, sortBy);
    const y = sortValue(b, sortBy);
    if (x === null && y === null) return 0;
    if (x === null) return 1;
    if (y === null) return -1;
    if (typeof x === 'string') return x.localeCompare(y, 'vi') * dir;
    return (x - y) * dir;
  });
}

async function notifyInvolved(req, type, title, message, emailType) {
  const ids = await involvedUserIds(req.task);
  await notifyUsers({
    userIds: ids,
    actor: req.user,
    task: req.task,
    type,
    title,
    message,
    emailType,
  });
}

async function notifyStatusChange(req) {
  const who = req.user.fullName;
  const task = req.task;
  if (task.status === 'completed') {
    await notifyInvolved(
      req,
      'status_changed',
      'Công việc đã hoàn thành',
      `${who} đã hoàn thành công việc "${task.title}"`,
      'task_completed'
    );
  } else {
    await notifyInvolved(
      req,
      'status_changed',
      'Trạng thái công việc thay đổi',
      `${who} đã chuyển "${task.title}" sang "${STATUS_TEXT[task.status]}"`
    );
  }
}

// GET /tasks?scope=&status=&priority=&q=&assigneeId=&sortBy=&order=
exports.list = async (req, res) => {
  const { scope, status, priority, q, assigneeId, sortBy = 'dueDate', order = 'asc' } = req.query;

  if (scope && !SCOPES.includes(scope)) {
    return res.status(400).json({ message: 'scope phải là created, assigned hoặc shared' });
  }
  if (status && !STATUSES.includes(status)) {
    return res.status(400).json({ message: 'Trạng thái lọc không hợp lệ' });
  }
  if (priority && !PRIORITIES.includes(priority)) {
    return res.status(400).json({ message: 'Mức ưu tiên lọc không hợp lệ' });
  }
  if (!SORT_FIELDS.includes(sortBy)) {
    return res.status(400).json({ message: `sortBy phải là một trong: ${SORT_FIELDS.join(', ')}` });
  }
  if (!['asc', 'desc'].includes(order)) {
    return res.status(400).json({ message: 'order phải là asc hoặc desc' });
  }
  if (assigneeId && !mongoose.isValidObjectId(assigneeId)) {
    return res.status(400).json({ message: 'assigneeId không hợp lệ' });
  }

  const filter = await accessibleFilter(req.user._id, scope);
  if (status) filter.status = status;
  if (priority) filter.priority = priority;
  if (assigneeId) filter.assigneeIds = assigneeId;
  const keyword = String(q || '').trim();
  if (keyword) filter.title = { $regex: escapeRegex(keyword), $options: 'i' };

  const tasks = await Task.find(filter)
    .populate('createdBy', 'fullName email')
    .populate('assigneeIds', 'fullName email');
  res.json(sortTasks(tasks, sortBy, order));
};

exports.detail = async (req, res) => {
  await req.task.populate([
    { path: 'createdBy', select: 'fullName email' },
    { path: 'assigneeIds', select: 'fullName email' },
    { path: 'primaryAssigneeId', select: 'fullName email' },
  ]);
  res.json({ ...req.task.toObject(), myAccess: req.access });
};

exports.create = async (req, res) => {
  const { error, data } = validateTaskInput(req.body, { requireTitle: true });
  if (error) return res.status(400).json({ message: error });
  const dateError = checkDateOrder(data.startDate, data.dueDate);
  if (dateError) return res.status(400).json({ message: dateError });

  const task = await Task.create({ ...data, createdBy: req.user._id });
  res.status(201).json(task);
};

exports.update = async (req, res) => {
  const { error, data } = validateTaskInput(req.body);
  if (error) return res.status(400).json({ message: error });
  if (!Object.keys(data).length) {
    return res.status(400).json({ message: 'Không có dữ liệu để cập nhật' });
  }

  const task = req.task;
  const start = data.startDate !== undefined ? data.startDate : task.startDate;
  const due = data.dueDate !== undefined ? data.dueDate : task.dueDate;
  const dateError = checkDateOrder(start, due);
  if (dateError) return res.status(400).json({ message: dateError });

  const oldStatus = task.status;
  const oldDue = task.dueDate ? task.dueDate.getTime() : null;

  task.set(data);
  await task.save();

  if (task.status !== oldStatus) await notifyStatusChange(req);

  const newDue = task.dueDate ? task.dueDate.getTime() : null;
  if (newDue !== oldDue) {
    const dueText = task.dueDate ? fmtDate(task.dueDate) : 'không còn hạn';
    await notifyInvolved(
      req,
      'due_changed',
      'Hạn hoàn thành thay đổi',
      `${req.user.fullName} đã đổi hạn hoàn thành của "${task.title}" (${dueText})`,
      'due_changed'
    );
  }
  res.json(task);
};

exports.updateStatus = async (req, res) => {
  const status = (req.body || {}).status;
  if (!STATUSES.includes(status)) {
    return res.status(400).json({ message: 'Trạng thái không hợp lệ' });
  }
  const oldStatus = req.task.status;
  req.task.status = status;
  await req.task.save();
  if (status !== oldStatus) await notifyStatusChange(req);
  res.json({ id: req.task._id, status: req.task.status });
};

exports.remove = async (req, res) => {
  await TaskShare.deleteMany({ taskId: req.task._id });
  await Notification.deleteMany({ taskId: req.task._id });
  await EmailLog.deleteMany({ taskId: req.task._id });
  await req.task.deleteOne();
  res.json({ message: 'Đã xóa công việc' });
};