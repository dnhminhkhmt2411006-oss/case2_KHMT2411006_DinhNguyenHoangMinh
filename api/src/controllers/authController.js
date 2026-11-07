const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const signToken = (user) =>
  jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '7d' });

const publicUser = (u) => ({ id: u._id, fullName: u.fullName, email: u.email });

exports.register = async (req, res) => {
  try {
    const { fullName, email, password } = req.body;
    if (!fullName || !email || !password) {
      return res.status(400).json({ message: 'Vui lòng nhập đủ họ tên, email, mật khẩu' });
    }
    if (!/^\S+@\S+\.\S+$/.test(email)) {
      return res.status(400).json({ message: 'Email không hợp lệ' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: 'Mật khẩu tối thiểu 6 ký tự' });
    }
    if (await User.findOne({ email: email.toLowerCase() })) {
      return res.status(409).json({ message: 'Email đã tồn tại' });
    }
    const user = await User.create({
      fullName,
      email,
      passwordHash: await bcrypt.hash(password, 10),
    });
    res.status(201).json({ token: signToken(user), user: publicUser(user) });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi máy chủ', error: err.message });
  }
};

exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email: (email || '').toLowerCase() });
    if (!user || !(await bcrypt.compare(password || '', user.passwordHash))) {
      return res.status(401).json({ message: 'Email hoặc mật khẩu không đúng' });
    }
    res.json({ token: signToken(user), user: publicUser(user) });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi máy chủ', error: err.message });
  }
};

exports.me = (req, res) => res.json(publicUser(req.user));
// PUT /auth/profile  { fullName }
exports.updateProfile = async (req, res) => {
  const fullName = String((req.body || {}).fullName ?? '').trim();
  if (!fullName) return res.status(400).json({ message: 'Họ tên không được để trống' });
  if (fullName.length > 100) {
    return res.status(400).json({ message: 'Họ tên tối đa 100 ký tự' });
  }
  await User.updateOne({ _id: req.user._id }, { $set: { fullName } });
  req.user.fullName = fullName;
  res.json(publicUser(req.user));
};

// PUT /auth/change-password  { currentPassword, newPassword }
exports.changePassword = async (req, res) => {
  const { currentPassword, newPassword } = req.body || {};
  if (!currentPassword || !newPassword) {
    return res.status(400).json({ message: 'Nhập mật khẩu hiện tại và mật khẩu mới' });
  }
  if (String(newPassword).length < 6) {
    return res.status(400).json({ message: 'Mật khẩu mới tối thiểu 6 ký tự' });
  }
  if (currentPassword === newPassword) {
    return res.status(400).json({ message: 'Mật khẩu mới phải khác mật khẩu hiện tại' });
  }
  const user = await User.findById(req.user._id);
  if (!user || !(await bcrypt.compare(String(currentPassword), user.passwordHash))) {
    return res.status(400).json({ message: 'Mật khẩu hiện tại không đúng' });
  }
  user.passwordHash = await bcrypt.hash(String(newPassword), 10);
  await user.save();
  res.json({ message: 'Đã đổi mật khẩu' });
};