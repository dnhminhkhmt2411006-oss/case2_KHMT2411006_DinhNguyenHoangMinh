const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');

exports.list = async (req, res) => {
  try {
    const uid = req.user._id;
    const { scope, status, priority, q } = req.query;
    const sharedIds = (await TaskShare.find({ userId: uid })).map(s => s.taskId);

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
  try {
    const task = await Task.findById(req.params.id)
      .populate('createdBy', 'fullName email')
      .populate('assigneeIds', 'fullName email');
    if (!task) return res.status(404).json({ message: 'Không tìm thấy công việc' });

    const uid = String(req.user._id);
    const share = await TaskShare.findOne({ taskId: task._id, userId: uid });
    const allowed = String(task.createdBy._id) === uid
      || task.assigneeIds.some(u => String(u._id) === uid)
      || share;
    if (!allowed) return res.status(403).json({ message: 'Không có quyền truy cập' });

    res.json(task);
  } catch (err) {
    res.status(400).json({ message: 'ID không hợp lệ' });
  }
};