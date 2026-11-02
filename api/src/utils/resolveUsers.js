const mongoose = require('mongoose');
const User = require('../models/User');

// Tìm người dùng theo userIds hoặc emails trong body
module.exports = async function resolveUsers(body = {}) {
  const rawIds = Array.isArray(body.userIds) ? body.userIds.map(String) : [];
  const rawEmails = Array.isArray(body.emails)
    ? body.emails.map((e) => String(e).trim().toLowerCase()).filter(Boolean)
    : [];
  const validIds = rawIds.filter((id) => mongoose.isValidObjectId(id));

  const users = await User.find({
    $or: [{ _id: { $in: validIds } }, { email: { $in: rawEmails } }],
  }).select('fullName email');

  const foundIds = new Set(users.map((u) => String(u._id)));
  const foundEmails = new Set(users.map((u) => u.email));
  const missing = [
    ...rawIds.filter((id) => !foundIds.has(id)),
    ...rawEmails.filter((e) => !foundEmails.has(e)),
  ];
  return { users, missing, requested: rawIds.length + rawEmails.length };
};