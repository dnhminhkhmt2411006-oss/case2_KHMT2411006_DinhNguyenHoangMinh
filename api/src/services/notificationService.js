const Notification = require('../models/Notification');
const TaskShare = require('../models/TaskShare');
const { queueEmails } = require('./emailService');

// Tạo thông báo; lỗi ở đây không được làm hỏng thao tác chính
async function createNotifications(items) {
  if (!items.length) return [];
  try {
    return await Notification.insertMany(items);
  } catch (err) {
    console.error('Không tạo được thông báo:', err.message);
    return [];
  }
}

// Gửi thông báo trong app (và email nếu có emailType), bỏ qua chính người thực hiện
async function notifyUsers({ userIds, actor, task, type, title, message, emailType }) {
  const actorId = String(actor._id);
  const unique = [...new Set(userIds.map(String))].filter((id) => id !== actorId);
  const created = await createNotifications(
    unique.map((userId) => ({ userId, taskId: task._id, type, title, message }))
  );
  if (emailType && unique.length) {
    await queueEmails({ userIds: unique, actor, task, emailType });
  }
  return created;
}

// Người liên quan: người tạo, người được giao, người được chia sẻ
async function involvedUserIds(task) {
  const shares = await TaskShare.find({ taskId: task._id }).select('userId');
  return [task.createdBy, ...task.assigneeIds, ...shares.map((s) => s.userId)].map(String);
}

module.exports = { createNotifications, notifyUsers, involvedUserIds };