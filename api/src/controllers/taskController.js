const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const Notification = require('../models/Notification');
const {
  validateTaskInput,
  checkDateOrder,
  STATUSES,
} = require('../validators/taskValidator');
const { notifyUsers, involvedUserIds } = require('../services/notificationService');

const STATUS_TEXT = {
  todo: 'Cần làm',
  in_progress: 'Đang làm',
  completed: 'Hoàn thành',
};

function fmtDate(d) {
  const p = (n) => String(n).padStart(2, '0');
  return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()}`;
}

async function notifyInvolved(req, type, title, message) {
  const ids = await involvedUserIds(req.task);
  await notifyUsers({
    userIds: ids,
    actor: req.user,
    task: req.task,
    type,
    title,
    message,
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
      `${who} đã hoàn thành công việc "${task.title}"`
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

exports.list = async (req, res) => {
  try {
    const uid = req.user._id;
    const { scope, status, priority, q } = req.query;
    const sharedIds = (await TaskShare.find({ userId: uid })).map((s) => s.taskId);

    const access = {
      created: { createdBy: uid },
      assigned: { assigneeIds: uid },
      shared: { _id: { $in: sharedIds } },
    };
    const filter = access[scope]
      ? { ...access[scope] }
      : { $or: [access.created, access.assigned, access.shared] };

    if (status) filter.status = status;
    if (priority) filter.priority = priority;
    if (q) filter.title = { $regex: q, $options: 'i' };

    const tasks = await Task.find(filter)
      .sort({ dueDate: 1 })
      .populate('createdBy', 'fullName email')
      .populate('assigneeIds', 'fullName email');
    res.json(tasks);
  } catch (err) {
    res.status(500).json({ message: 'Lỗi máy chủ', error: err.message });
  }
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
      `${req.user.fullName} đã đổi hạn hoàn thành của "${task.title}" (${dueText})`
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
  await req.task.deleteOne();
  res.json({ message: 'Đã xóa công việc' });
};