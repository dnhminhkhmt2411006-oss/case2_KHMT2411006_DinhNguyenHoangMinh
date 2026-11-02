const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const {
  validateTaskInput,
  checkDateOrder,
  STATUSES,
} = require('../validators/taskValidator');

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

  task.set(data);
  await task.save();
  res.json(task);
};

exports.updateStatus = async (req, res) => {
  const status = (req.body || {}).status;
  if (!STATUSES.includes(status)) {
    return res.status(400).json({ message: 'Trạng thái không hợp lệ' });
  }
  req.task.status = status;
  await req.task.save();
  res.json({ id: req.task._id, status: req.task.status });
};

exports.remove = async (req, res) => {
  await TaskShare.deleteMany({ taskId: req.task._id });
  await req.task.deleteOne();
  res.json({ message: 'Đã xóa công việc' });
};