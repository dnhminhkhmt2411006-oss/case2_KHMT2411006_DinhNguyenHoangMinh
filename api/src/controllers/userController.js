const mongoose = require('mongoose');
const User = require('../models/User');

const toPublic = (u) => ({ id: u._id, fullName: u.fullName, email: u.email });

exports.search = async (req, res) => {
  const q = String(req.query.q || '').trim();
  if (q.length < 2) return res.json([]);
  const safe = q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const users = await User.find({
    $or: [
      { fullName: { $regex: safe, $options: 'i' } },
      { email: { $regex: safe, $options: 'i' } },
    ],
  })
    .select('fullName email')
    .limit(10);
  res.json(users.map(toPublic));
};

exports.getById = async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) {
    return res.status(400).json({ message: 'ID không hợp lệ' });
  }
  const user = await User.findById(req.params.id).select('fullName email');
  if (!user) return res.status(404).json({ message: 'Không tìm thấy người dùng' });
  res.json(toPublic(user));
};