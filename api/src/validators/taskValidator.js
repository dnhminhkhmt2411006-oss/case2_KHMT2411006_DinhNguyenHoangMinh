const PRIORITIES = ['low', 'medium', 'high'];
const STATUSES = ['todo', 'in_progress', 'completed'];

function validateTaskInput(body = {}, { requireTitle = false } = {}) {
  const data = {};

  if (body.title !== undefined || requireTitle) {
    const title = String(body.title ?? '').trim();
    if (!title) return { error: 'Tên công việc không được để trống' };
    if (title.length > 200) return { error: 'Tên công việc tối đa 200 ký tự' };
    data.title = title;
  }
  if (body.description !== undefined) {
    data.description = String(body.description ?? '').trim();
  }
  if (body.priority !== undefined) {
    if (!PRIORITIES.includes(body.priority)) {
      return { error: 'Mức ưu tiên không hợp lệ (low, medium, high)' };
    }
    data.priority = body.priority;
  }
  if (body.status !== undefined) {
    if (!STATUSES.includes(body.status)) {
      return { error: 'Trạng thái không hợp lệ (todo, in_progress, completed)' };
    }
    data.status = body.status;
  }

  const dateLabels = { startDate: 'Ngày bắt đầu', dueDate: 'Hạn hoàn thành' };
  for (const key of Object.keys(dateLabels)) {
    if (body[key] === undefined) continue;
    if (body[key] === null || body[key] === '') {
      data[key] = null;
    } else {
      const d = new Date(body[key]);
      if (isNaN(d.getTime())) return { error: `${dateLabels[key]} không hợp lệ` };
      data[key] = d;
    }
  }
  return { data };
}

function checkDateOrder(start, due) {
  if (start && due && due < start) {
    return 'Hạn hoàn thành phải sau hoặc bằng ngày bắt đầu';
  }
  return null;
}

module.exports = { validateTaskInput, checkDateOrder, PRIORITIES, STATUSES };