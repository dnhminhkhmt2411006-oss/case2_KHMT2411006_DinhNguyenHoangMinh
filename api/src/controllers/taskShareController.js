const mongoose = require('mongoose');
const TaskShare = require('../models/TaskShare');
const resolveUsers = require('../utils/resolveUsers');
const { notifyUsers } = require('../services/notificationService');

const PERMISSIONS = ['viewer', 'editor'];
const permText = (p) => (p === 'editor' ? 'được chỉnh sửa' : 'chỉ xem');

async function respond(taskId, res) {
  const shares = await TaskShare.find({ taskId })
    .populate('userId', 'fullName email')
    .sort({ createdAt: 1 });
  res.json(
    shares.map((s) => ({
      id: s._id,
      permission: s.permission,
      user: s.userId
        ? { id: s.userId._id, fullName: s.userId.fullName, email: s.userId.email }
        : null,
      createdAt: s.createdAt,
    }))
  );
}

exports.list = (req, res) => respond(req.task._id, res);

// Chia sẻ cho một hoặc nhiều người: { userIds: [], emails: [], permission }
exports.add = async (req, res) => {
  const body = req.body || {};
  const permission = body.permission || 'viewer';
  if (!PERMISSIONS.includes(permission)) {
    return res.status(400).json({ message: 'Quyền phải là viewer hoặc editor' });
  }
  const { users, missing, requested } = await resolveUsers(body);
  if (!requested) {
    return res.status(400).json({ message: 'Chưa chọn người để chia sẻ' });
  }
  if (missing.length) {
    return res
      .status(404)
      .json({ message: `Không tìm thấy người dùng: ${missing.join(', ')}` });
  }

  const ownerId = String(req.task.createdBy);
  const targets = users.filter((u) => String(u._id) !== ownerId);
  if (!targets.length) {
    return res
      .status(400)
      .json({ message: 'Không thể chia sẻ cho chính người tạo công việc' });
  }

  const existing = await TaskShare.find({
    taskId: req.task._id,
    userId: { $in: targets.map((u) => u._id) },
  });
  const oldPerm = new Map(existing.map((s) => [String(s.userId), s.permission]));
  const changed = targets.filter((u) => oldPerm.get(String(u._id)) !== permission);

  await Promise.all(
    targets.map((u) =>
      TaskShare.findOneAndUpdate(
        { taskId: req.task._id, userId: u._id },
        { $set: { permission, sharedBy: req.user._id } },
        { upsert: true }
      )
    )
  );

  await notifyUsers({
    userIds: changed.map((u) => u._id),
    actor: req.user,
    task: req.task,
    type: 'task_shared',
    title: 'Công việc được chia sẻ với bạn',
    message: `${req.user.fullName} đã chia sẻ công việc "${req.task.title}" với bạn (${permText(permission)})`,
  });
  await respond(req.task._id, res);
};

exports.updatePermission = async (req, res) => {
  const { shareId } = req.params;
  const permission = (req.body || {}).permission;
  if (!PERMISSIONS.includes(permission)) {
    return res.status(400).json({ message: 'Quyền phải là viewer hoặc editor' });
  }
  if (!mongoose.isValidObjectId(shareId)) {
    return res.status(400).json({ message: 'ID chia sẻ không hợp lệ' });
  }
  const share = await TaskShare.findOne({ _id: shareId, taskId: req.task._id });
  if (!share) return res.status(404).json({ message: 'Không tìm thấy bản ghi chia sẻ' });

  const changed = share.permission !== permission;
  share.permission = permission;
  await share.save();
  if (changed) {
    await notifyUsers({
      userIds: [share.userId],
      actor: req.user,
      task: req.task,
      type: 'share_updated',
      title: 'Quyền truy cập được thay đổi',
      message: `${req.user.fullName} đã đổi quyền của bạn trên "${req.task.title}" (${permText(permission)})`,
    });
  }
  await respond(req.task._id, res);
};

exports.revoke = async (req, res) => {
  const { shareId } = req.params;
  if (!mongoose.isValidObjectId(shareId)) {
    return res.status(400).json({ message: 'ID chia sẻ không hợp lệ' });
  }
  const share = await TaskShare.findOneAndDelete({
    _id: shareId,
    taskId: req.task._id,
  });
  if (!share) return res.status(404).json({ message: 'Không tìm thấy bản ghi chia sẻ' });

  await notifyUsers({
    userIds: [share.userId],
    actor: req.user,
    task: req.task,
    type: 'share_revoked',
    title: 'Quyền chia sẻ bị thu hồi',
    message: `${req.user.fullName} đã thu hồi quyền chia sẻ công việc "${req.task.title}" với bạn`,
  });
  await respond(req.task._id, res);
};