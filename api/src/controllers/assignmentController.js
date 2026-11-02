const resolveUsers = require('../utils/resolveUsers');

async function respond(task, res) {
  await task.populate('assigneeIds', 'fullName email');
  const primary = task.primaryAssigneeId ? String(task.primaryAssigneeId) : null;
  res.json(
    task.assigneeIds.map((u) => ({
      id: u._id,
      fullName: u.fullName,
      email: u.email,
      isPrimary: primary === String(u._id),
    }))
  );
}

exports.list = (req, res) => respond(req.task, res);

// Giao việc cho một hoặc nhiều người: { userIds: [], emails: [], primaryUserId? }
exports.add = async (req, res) => {
  const body = req.body || {};
  const { users, missing, requested } = await resolveUsers(body);
  if (!requested) {
    return res.status(400).json({ message: 'Chưa chọn người để giao việc' });
  }
  if (missing.length) {
    return res
      .status(404)
      .json({ message: `Không tìm thấy người dùng: ${missing.join(', ')}` });
  }

  const task = req.task;
  const current = new Set(task.assigneeIds.map(String));
  users.forEach((u) => {
    if (!current.has(String(u._id))) task.assigneeIds.push(u._id);
  });

  if (body.primaryUserId) {
    const inList = task.assigneeIds.map(String).includes(String(body.primaryUserId));
    if (!inList) {
      return res
        .status(400)
        .json({ message: 'Người phụ trách chính phải nằm trong danh sách được giao' });
    }
    task.primaryAssigneeId = body.primaryUserId;
  } else if (!task.primaryAssigneeId && task.assigneeIds.length) {
    task.primaryAssigneeId = task.assigneeIds[0];
  }

  await task.save();
  await respond(task, res);
};

// Đặt người phụ trách chính
exports.setPrimary = async (req, res) => {
  const { userId } = req.params;
  const task = req.task;
  if (!task.assigneeIds.map(String).includes(userId)) {
    return res.status(404).json({ message: 'Người này chưa được giao việc' });
  }
  task.primaryAssigneeId = userId;
  await task.save();
  await respond(task, res);
};

// Hủy giao việc cho một người
exports.remove = async (req, res) => {
  const { userId } = req.params;
  const task = req.task;
  const before = task.assigneeIds.length;
  task.assigneeIds = task.assigneeIds.filter((id) => String(id) !== userId);
  if (task.assigneeIds.length === before) {
    return res.status(404).json({ message: 'Người này chưa được giao việc' });
  }
  if (String(task.primaryAssigneeId) === userId) {
    task.primaryAssigneeId = task.assigneeIds[0] || null;
  }
  await task.save();
  await respond(task, res);
};