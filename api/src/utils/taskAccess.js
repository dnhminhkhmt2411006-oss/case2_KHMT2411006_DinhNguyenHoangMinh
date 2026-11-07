const TaskShare = require('../models/TaskShare');

// Điều kiện lọc: công việc do tôi tạo, được giao cho tôi hoặc được chia sẻ cho tôi
async function accessibleFilter(userId, scope) {
  const shares = await TaskShare.find({ userId }).select('taskId');
  const access = {
    created: { createdBy: userId },
    assigned: { assigneeIds: userId },
    shared: { _id: { $in: shares.map((s) => s.taskId) } },
  };
  if (scope && access[scope]) return { ...access[scope] };
  return { $or: [access.created, access.assigned, access.shared] };
}

// Thoát ký tự đặc biệt để người dùng nhập "(" hay "." không làm lỗi tìm kiếm
const escapeRegex = (s) => String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

module.exports = { accessibleFilter, escapeRegex };