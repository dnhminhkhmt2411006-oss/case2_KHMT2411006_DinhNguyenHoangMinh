const Task = require('../models/Task');
const User = require('../models/User');
const TaskShare = require('../models/TaskShare');
const EmailLog = require('../models/EmailLog');
const { isEmailConfigured, getTransporter, getFrom } = require('../config/email');
const { buildEmail } = require('./emailTemplates');

const MAX_RETRY = 3;

async function composeMessage({ emailType, task, actor, recipient }) {
  const extra = {};
  if (emailType === 'task_shared') {
    const share = await TaskShare.findOne({ taskId: task._id, userId: recipient._id });
    extra.permission = share ? share.permission : 'viewer';
  }
  return buildEmail(emailType, { task, actor, recipient, extra });
}

// Gửi một email và cập nhật trạng thái sent/failed vào log
async function deliver(log, message) {
  try {
    if (process.env.EMAIL_ENABLED === 'false') throw new Error('Gửi email đang tắt (EMAIL_ENABLED=false)');
    if (!isEmailConfigured()) throw new Error('Chưa cấu hình SMTP trong file .env');
    await getTransporter().sendMail({
      from: getFrom(),
      to: log.recipientEmail,
      subject: log.subject,
      html: message.html,
      text: message.text,
    });
    log.status = 'sent';
    log.errorMessage = '';
    log.sentAt = new Date();
  } catch (err) {
    log.status = 'failed';
    log.errorMessage = String(err.message || err).slice(0, 500);
  }
  await log.save();
}

// Tạo log rồi gửi ngầm, không làm chậm hoặc làm hỏng thao tác chính
async function queueEmails({ userIds, actor, task, emailType }) {
  try {
    const recipients = await User.find({ _id: { $in: userIds } }).select('fullName email');
    for (const recipient of recipients) {
      const message = await composeMessage({ emailType, task, actor, recipient });
      const log = await EmailLog.create({
        taskId: task._id,
        recipientId: recipient._id,
        recipientEmail: recipient.email,
        actorId: actor._id,
        type: emailType,
        subject: message.subject,
        status: 'pending',
      });
      deliver(log, message).catch((err) => console.error('Lỗi gửi email:', err.message));
    }
  } catch (err) {
    console.error('Không tạo được email:', err.message);
  }
}

// Gửi lại một email thất bại
async function retryEmail(log) {
  const task = await Task.findById(log.taskId);
  const recipient = await User.findById(log.recipientId).select('fullName email');
  const actor = log.actorId ? await User.findById(log.actorId).select('fullName') : null;
  if (!task || !recipient) {
    log.status = 'failed';
    log.errorMessage = 'Công việc hoặc người nhận không còn tồn tại';
    await log.save();
    return log;
  }
  log.retryCount += 1;
  log.status = 'pending';
  await log.save();
  const message = await composeMessage({ emailType: log.type, task, actor, recipient });
  log.subject = message.subject;
  await deliver(log, message);
  return log;
}

module.exports = { queueEmails, retryEmail, MAX_RETRY };