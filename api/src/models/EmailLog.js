const mongoose = require('mongoose');

const emailLogSchema = new mongoose.Schema(
  {
    taskId: { type: mongoose.Schema.Types.ObjectId, ref: 'Task', required: true },
    recipientId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    recipientEmail: { type: String, required: true },
    actorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    type: { type: String, required: true },
    subject: { type: String, default: '' },
    status: { type: String, enum: ['pending', 'sent', 'failed'], default: 'pending' },
    errorMessage: { type: String, default: '' },
    retryCount: { type: Number, default: 0 },
    sentAt: { type: Date },
  },
  { timestamps: true }
);

emailLogSchema.index({ taskId: 1, createdAt: -1 });

module.exports = mongoose.model('EmailLog', emailLogSchema);