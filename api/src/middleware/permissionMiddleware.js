const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');

const RULES = {
  view: 'canView',
  edit: 'canEdit',
  status: 'canChangeStatus',
  delete: 'canDelete',
  manage: 'canManage',
};

const DENIED = {
  edit: 'Bạn chỉ có quyền xem, không được sửa công việc này',
  status: 'Bạn không có quyền đổi trạng thái công việc này',
  delete: 'Chỉ người tạo mới được xóa công việc',
  manage: 'Chỉ người tạo mới được giao việc hoặc quản lý chia sẻ',
};

async function computeAccess(task, userId) {
  const uid = String(userId);
  const isOwner = String(task.createdBy) === uid;
  const isAssignee = task.assigneeIds.some((id) => String(id) === uid);
  const share = await TaskShare.findOne({ taskId: task._id, userId });
  const shareRole = share ? share.permission : null;
  const canEdit = isOwner || shareRole === 'editor';

  return {
    isOwner,
    isAssignee,
    shareRole,
    canView: isOwner || isAssignee || !!share,
    canEdit,
    canChangeStatus: canEdit || isAssignee,
    canDelete: isOwner,
    canManage: isOwner,
  };
}

// loadTask('view' | 'edit' | 'status' | 'delete' | 'manage')
exports.loadTask = (rule = 'view') => async (req, res, next) => {
  try {
    const { id } = req.params;
    if (!mongoose.isValidObjectId(id)) {
      return res.status(400).json({ message: 'ID không hợp lệ' });
    }
    const task = await Task.findById(id);
    if (!task) return res.status(404).json({ message: 'Không tìm thấy công việc' });

    const access = await computeAccess(task, req.user._id);
    if (!access.canView) {
      return res.status(403).json({ message: 'Không có quyền truy cập công việc này' });
    }
    if (!access[RULES[rule]]) {
      return res.status(403).json({ message: DENIED[rule] });
    }
    req.task = task;
    req.access = access;
    next();
  } catch (err) {
    next(err);
  }
};