const PRIORITY = { low: 'Thấp', medium: 'Trung bình', high: 'Cao' };
const STATUS = { todo: 'Cần làm', in_progress: 'Đang làm', completed: 'Hoàn thành' };
const PERMISSION = { viewer: 'chỉ xem', editor: 'được chỉnh sửa' };

const escapeHtml = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])
  );

function fmtDate(d) {
  if (!d) return 'Chưa đặt';
  const x = new Date(d);
  const p = (n) => String(n).padStart(2, '0');
  return `${p(x.getDate())}/${p(x.getMonth() + 1)}/${x.getFullYear()}`;
}

// Trả về { subject, html, text } cho từng loại email
function buildEmail(type, { task, actor, recipient, extra = {} }) {
  const who = actor?.fullName || 'Một người dùng';
  const defs = {
    task_assigned: {
      heading: 'Bạn được giao một công việc mới',
      intro: `${who} đã giao cho bạn công việc "${task.title}".`,
    },
    task_shared: {
      heading: 'Một công việc được chia sẻ với bạn',
      intro: `${who} đã chia sẻ công việc "${task.title}" với bạn (${
        PERMISSION[extra.permission] || 'chỉ xem'
      }).`,
    },
    due_changed: {
      heading: 'Hạn hoàn thành đã thay đổi',
      intro: `${who} đã thay đổi hạn hoàn thành của công việc "${task.title}".`,
    },
    task_completed: {
      heading: 'Công việc đã hoàn thành',
      intro: `${who} đã đánh dấu hoàn thành công việc "${task.title}".`,
    },
  };
  const def = defs[type];
  if (!def) throw new Error(`Loại email không hợp lệ: ${type}`);

  const rows = [
    ['Công việc', task.title],
    ['Hạn hoàn thành', fmtDate(task.dueDate)],
    ['Mức ưu tiên', PRIORITY[task.priority] || task.priority],
    ['Trạng thái', STATUS[task.status] || task.status],
  ];
  if (task.description) rows.push(['Mô tả', task.description]);

  const subject = `[Task Manager] ${def.heading}: ${task.title}`;
  const html = `
<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;border:1px solid #e0e0e0;border-radius:8px;overflow:hidden">
  <div style="background:#3f51b5;color:#fff;padding:16px 20px;font-size:18px">${escapeHtml(def.heading)}</div>
  <div style="padding:20px">
    <p>Xin chào ${escapeHtml(recipient?.fullName || '')},</p>
    <p>${escapeHtml(def.intro)}</p>
    <table style="width:100%;border-collapse:collapse">
      ${rows
        .map(
          ([k, v]) =>
            `<tr><td style="padding:6px 0;color:#666;width:140px">${escapeHtml(k)}</td><td style="padding:6px 0">${escapeHtml(v)}</td></tr>`
        )
        .join('')}
    </table>
    <p style="color:#999;font-size:12px;margin-top:24px">Email tự động từ Task Manager.</p>
  </div>
</div>`;
  const text = [def.heading, '', def.intro, '', ...rows.map(([k, v]) => `${k}: ${v}`)].join('\n');
  return { subject, html, text };
}

module.exports = { buildEmail };