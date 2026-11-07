const mongoose = require('mongoose');
const EmailLog = require('../models/EmailLog');
const Task = require('../models/Task');
const { retryEmail, MAX_RETRY } = require('../services/emailService');

const toDto = (l) => ({
  id: l._id,
  taskId: l.taskId,
  recipientEmail: l.recipientEmail,
  type: l.type,
  subject: l.subject,
  status: l.status,
  errorMessage: l.errorMessage,
  retryCount: l.retryCount,
  sentAt: l.sentAt,
  createdAt: l.createdAt,
});

// Xem lịch sử gửi email của một công việc (chỉ người tạo)
exports.listByTask = async (req, res) => {
  const logs = await EmailLog.find({ taskId: req.task._id })
    .sort({ createdAt: -1 })
    .limit(100);
  res.json(logs.map(toDto));
};

// Thử gửi lại email thất bại (chỉ người tạo công việc)
exports.retry = async (req, res) => {
  const { id } = req.params;
  if (!mongoose.isValidObjectId(id)) {
    return res.status(400).json({ message: 'ID không hợp lệ' });
  }
  const log = await EmailLog.findById(id);
  if (!log) return res.status(404).json({ message: 'Không tìm thấy bản ghi email' });

  const task = await Task.findById(log.taskId);
  if (!task) return res.status(404).json({ message: 'Công việc không còn tồn tại' });
  if (String(task.createdBy) !== String(req.user._id)) {
    return res
      .status(403)
      .json({ message: 'Chỉ người tạo công việc mới được gửi lại email' });
  }
  if (log.status === 'sent') {
    return res.status(400).json({ message: 'Email đã gửi thành công, không cần gửi lại' });
  }
  if (log.status === 'pending') {
    return res.status(400).json({ message: 'Email đang được gửi, vui lòng chờ' });
  }
  if (log.retryCount >= MAX_RETRY) {
    return res.status(400).json({ message: 'Đã vượt quá số lần gửi lại cho phép' });
  }
  const updated = await retryEmail(log);
  res.json(toDto(updated));
};