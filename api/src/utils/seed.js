require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');
const Task = require('../models/Task');

(async () => {
  await mongoose.connect(process.env.MONGO_URI);
  const user = await User.findOne({ email: 'minh@test.com' });
  if (!user) {
    console.log('Chưa có tài khoản minh@test.com, hãy đăng ký trước');
    return process.exit(1);
  }
  const day = (n) => new Date(Date.now() + n * 86400000);
  await Task.insertMany([
    { title: 'Viết báo cáo tuần', description: 'Tổng hợp tiến độ nhóm', createdBy: user._id, assigneeIds: [user._id], primaryAssigneeId: user._id, startDate: day(0), dueDate: day(3), priority: 'high', status: 'todo' },
    { title: 'Thiết kế màn hình đăng nhập', description: 'Bố cục Flutter', createdBy: user._id, assigneeIds: [user._id], primaryAssigneeId: user._id, startDate: day(-1), dueDate: day(5), priority: 'medium', status: 'in_progress' },
    { title: 'Họp nhóm thứ Sáu', description: 'Chốt phân công', createdBy: user._id, assigneeIds: [], startDate: day(-3), dueDate: day(-1), priority: 'low', status: 'completed' },
  ]);
  console.log('Đã tạo 3 công việc mẫu');
  process.exit(0);
})();