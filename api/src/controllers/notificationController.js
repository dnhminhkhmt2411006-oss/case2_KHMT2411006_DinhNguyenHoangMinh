const mongoose = require('mongoose');
const Notification = require('../models/Notification');

const toDto = (n) => ({
  id: n._id,
  taskId: n.taskId || null,
  type: n.type,
  title: n.title,
  message: n.message,
  isRead: n.isRead,
  createdAt: n.createdAt,
});

exports.list = async (req, res) => {
  const filter = { userId: req.user._id };
  if (req.query.unread === 'true') filter.isRead = false;
  const items = await Notification.find(filter).sort({ createdAt: -1 }).limit(50);
  res.json(items.map(toDto));
};

exports.unreadCount = async (req, res) => {
  const count = await Notification.countDocuments({
    userId: req.user._id,
    isRead: false,
  });
  res.json({ count });
};

exports.markRead = async (req, res) => {
  const { id } = req.params;
  if (!mongoose.isValidObjectId(id)) {
    return res.status(400).json({ message: 'ID không hợp lệ' });
  }
  const n = await Notification.findOneAndUpdate(
    { _id: id, userId: req.user._id },
    { $set: { isRead: true } }
  );
  if (!n) return res.status(404).json({ message: 'Không tìm thấy thông báo' });
  res.json({ id: n._id, isRead: true });
};

exports.markAllRead = async (req, res) => {
  const result = await Notification.updateMany(
    { userId: req.user._id, isRead: false },
    { $set: { isRead: true } }
  );
  res.json({ updated: result.modifiedCount });
};