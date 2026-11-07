require('dotenv').config();
const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const User = require('../src/models/User');
const Task = require('../src/models/Task');
const TaskShare = require('../src/models/TaskShare');
const Notification = require('../src/models/Notification');
const EmailLog = require('../src/models/EmailLog');

const BASE = process.env.API_URL || 'http://localhost:3000/api';
const DAY = 24 * 60 * 60 * 1000;
const iso = (days) => new Date(Date.now() + days * DAY).toISOString();

async function call(method, path, { token, body } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let data = null;
  try {
    data = await res.json();
  } catch (_) {}
  return { status: res.status, data };
}

const ids = (r) => r.data.map((x) => x._id);
const sorted = (a) => [...a].sort();

describe('Task Manager API - kiem thu tich hop', () => {
  const stamp = Date.now();
  const mk = (name) => ({
    fullName: `Nguoi ${name}`,
    email: `${name}_${stamp}@integration.invalid`,
    password: 'secret123',
  });
  const users = { owner: mk('owner'), member: mk('member'), stranger: mk('stranger') };
  const t = {}; // id các công việc thử
  const tok = (k) => users[k].token;

  before(async () => {
    const res = await call('GET', '/health');
    assert.equal(res.status, 200, 'Server chua chay tai ' + BASE);
    await mongoose.connect(process.env.MONGO_URI);
  });

  after(async () => {
    try {
      if (mongoose.connection.readyState === 1) {
        const userIds = Object.values(users).map((u) => u.id).filter(Boolean);
        const tasks = await Task.find({ createdBy: { $in: userIds } }).select('_id');
        const taskIds = tasks.map((x) => x._id);
        await TaskShare.deleteMany({ taskId: { $in: taskIds } });
        await EmailLog.deleteMany({ taskId: { $in: taskIds } });
        await Notification.deleteMany({
          $or: [{ taskId: { $in: taskIds } }, { userId: { $in: userIds } }],
        });
        await Task.deleteMany({ _id: { $in: taskIds } });
        await User.deleteMany({ _id: { $in: userIds } });
      }
    } finally {
      await mongoose.disconnect();
    }
  });

  it('1. dang ky 3 tai khoan; email trung, mat khau yeu, email sai bi tu choi', async () => {
    for (const key of Object.keys(users)) {
      const r = await call('POST', '/auth/register', { body: users[key] });
      assert.equal(r.status, 201);
      assert.ok(r.data.token);
      users[key].token = r.data.token;
      users[key].id = r.data.user.id;
    }
    const dup = await call('POST', '/auth/register', { body: users.owner });
    assert.equal(dup.status, 409);
    const weak = await call('POST', '/auth/register', {
      body: { fullName: 'A', email: `weak_${stamp}@integration.invalid`, password: '123' },
    });
    assert.equal(weak.status, 400);
    const bad = await call('POST', '/auth/register', {
      body: { fullName: 'A', email: 'khong-phai-email', password: '123456' },
    });
    assert.equal(bad.status, 400);
  });

  it('2. dang nhap dung/sai va xac thuc token', async () => {
    const ok = await call('POST', '/auth/login', {
      body: { email: users.owner.email, password: users.owner.password },
    });
    assert.equal(ok.status, 200);
    assert.ok(ok.data.token);
    const wrong = await call('POST', '/auth/login', {
      body: { email: users.owner.email, password: 'sai-mat-khau' },
    });
    assert.equal(wrong.status, 401);
    const unknown = await call('POST', '/auth/login', {
      body: { email: `khong_co_${stamp}@integration.invalid`, password: 'secret123' },
    });
    assert.equal(unknown.status, 401);
    assert.equal((await call('GET', '/auth/me')).status, 401);
    assert.equal((await call('GET', '/auth/me', { token: 'token-gia' })).status, 401);
    const me = await call('GET', '/auth/me', { token: tok('owner') });
    assert.equal(me.status, 200);
    assert.equal(me.data.email, users.owner.email);
    assert.equal(me.data.passwordHash, undefined);
  });

  it('3. tao cong viec: du lieu dau vao khong hop le bi tu choi', async () => {
    const post = (body, token = tok('owner')) => call('POST', '/tasks', { token, body });
    assert.equal((await post({ title: '' })).status, 400);
    assert.equal((await post({ title: 'X', startDate: iso(5), dueDate: iso(1) })).status, 400);
    assert.equal((await post({ title: 'X', priority: 'khan-cap' })).status, 400);
    assert.equal((await post({ title: 'X', status: 'xong' })).status, 400);
    assert.equal((await post({ title: 'X' }, null)).status, 401);
  });

  it('4. tao 4 cong viec mau', async () => {
    const make = async (key, body) => {
      const r = await call('POST', '/tasks', { token: tok('owner'), body });
      assert.equal(r.status, 201);
      t[key] = r.data._id;
    };
    await make('t1', { title: 'Bao cao tuan', priority: 'high', dueDate: iso(2) });
    await make('t2', { title: 'Thiet ke giao dien', priority: 'medium', dueDate: iso(-2) });
    await make('t3', { title: 'Hop nhom', priority: 'low', status: 'in_progress' });
    await make('t4', { title: 'Viec da xong', priority: 'medium', status: 'completed', dueDate: iso(-5) });
  });

  it('5. xem chi tiet va phan quyen co ban', async () => {
    const own = await call('GET', `/tasks/${t.t1}`, { token: tok('owner') });
    assert.equal(own.status, 200);
    assert.equal(own.data.myAccess.isOwner, true);
    assert.equal((await call('GET', `/tasks/${t.t1}`, { token: tok('stranger') })).status, 403);
    assert.equal((await call('GET', '/tasks/abc', { token: tok('owner') })).status, 400);
    const fake = new mongoose.Types.ObjectId().toString();
    assert.equal((await call('GET', `/tasks/${fake}`, { token: tok('owner') })).status, 404);
  });

  it('6. sua cong viec: chi nguoi co quyen moi sua duoc', async () => {
    const ok = await call('PUT', `/tasks/${t.t1}`, { token: tok('owner'), body: { title: 'Bao cao tuan 2' } });
    assert.equal(ok.status, 200);
    assert.equal(ok.data.title, 'Bao cao tuan 2');
    assert.equal((await call('PUT', `/tasks/${t.t1}`, { token: tok('stranger'), body: { title: 'Hack' } })).status, 403);
    assert.equal((await call('PUT', `/tasks/${t.t1}`, { token: tok('owner'), body: {} })).status, 400);
  });

  it('7. tim kiem theo ten (khong phan biet hoa thuong, an toan voi ky tu dac biet)', async () => {
    const list = (qs) => call('GET', `/tasks?${qs}`, { token: tok('owner') });
    let r = await list('q=bao');
    assert.equal(r.status, 200);
    assert.deepEqual(ids(r), [t.t1]);
    assert.deepEqual(ids(await list('q=BAO')), [t.t1]);
    assert.deepEqual(ids(await list('q=hop%20nhom')), [t.t3]);
    r = await list('q=' + encodeURIComponent('.'));
    assert.equal(r.status, 200);
    assert.equal(r.data.length, 0);
    r = await list('q=' + encodeURIComponent('('));
    assert.equal(r.status, 200);
    assert.equal(r.data.length, 0);
    assert.equal((await list('q=khongtontai')).data.length, 0);
  });

  it('8. loc theo trang thai, uu tien, pham vi; tham so sai bi tu choi', async () => {
    const list = (qs) => call('GET', `/tasks?${qs}`, { token: tok('owner') });
    assert.deepEqual(ids(await list('status=in_progress')), [t.t3]);
    assert.deepEqual(ids(await list('priority=high')), [t.t1]);
    assert.deepEqual(ids(await list('status=completed&priority=medium')), [t.t4]);
    assert.equal((await list('scope=created')).data.length, 4);
    assert.equal((await list('scope=assigned')).data.length, 0);
    assert.equal((await list('scope=shared')).data.length, 0);
    assert.equal((await list('status=xong')).status, 400);
    assert.equal((await list('priority=khan')).status, 400);
    assert.equal((await list('scope=abc')).status, 400);
    assert.equal((await list('assigneeId=abc')).status, 400);
  });

  it('9. sap xep theo han, uu tien, ten (cong viec khong co han luon o cuoi)', async () => {
    const list = (qs) => call('GET', `/tasks?${qs}`, { token: tok('owner') });
    assert.deepEqual(ids(await list('sortBy=dueDate&order=asc')), [t.t4, t.t2, t.t1, t.t3]);
    assert.deepEqual(ids(await list('sortBy=dueDate&order=desc')), [t.t1, t.t2, t.t4, t.t3]);
    const byPriority = await list('sortBy=priority&order=desc');
    assert.deepEqual(byPriority.data.map((x) => x.priority), ['high', 'medium', 'medium', 'low']);
    const byTitle = await list('sortBy=title&order=asc');
    const titles = byTitle.data.map((x) => x.title);
    assert.deepEqual(titles, [...titles].sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase(), 'vi')));
    assert.equal((await list('sortBy=abc')).status, 400);
    assert.equal((await list('order=up')).status, 400);
  });

  it('10. giao viec nhieu nguoi, nguoi phu trach chinh, huy giao viec', async () => {
    const post = (taskId, body, token = tok('owner')) =>
      call('POST', `/tasks/${taskId}/assignees`, { token, body });
    const a1 = await post(t.t1, { emails: [users.member.email] });
    assert.equal(a1.status, 200);
    assert.equal(a1.data.length, 1);
    assert.equal(a1.data[0].isPrimary, true);

    assert.equal((await post(t.t1, { emails: [users.stranger.email] }, tok('member'))).status, 403);
    assert.equal((await post(t.t1, { emails: [`khong_co_${stamp}@integration.invalid`] })).status, 404);
    assert.equal((await post(t.t1, {})).status, 400);

    const a2 = await post(t.t2, { userIds: [users.member.id, users.owner.id] });
    assert.equal(a2.data.length, 2);
    const prim = await call('PATCH', `/tasks/${t.t2}/assignees/${users.member.id}`, { token: tok('owner'), body: {} });
    assert.equal(prim.status, 200);
    assert.equal(prim.data.find((x) => x.id === users.member.id).isPrimary, true);
    const rem = await call('DELETE', `/tasks/${t.t2}/assignees/${users.owner.id}`, { token: tok('owner') });
    assert.equal(rem.status, 200);
    assert.equal(rem.data.length, 1);
    assert.equal(rem.data[0].isPrimary, true);

    const byAssignee = await call('GET', `/tasks?assigneeId=${users.member.id}`, { token: tok('owner') });
    assert.deepEqual(sorted(ids(byAssignee)), sorted([t.t1, t.t2]));
    const mine = await call('GET', '/tasks?scope=assigned', { token: tok('member') });
    assert.deepEqual(sorted(ids(mine)), sorted([t.t1, t.t2]));
  });

  it('11. chia se viewer/editor va kiem tra phan quyen o backend', async () => {
    const share = (body, token = tok('owner')) =>
      call('POST', `/tasks/${t.t3}/shares`, { token, body });
    const s = await share({ userIds: [users.stranger.id], permission: 'viewer' });
    assert.equal(s.status, 200);
    assert.equal(s.data.length, 1);
    assert.equal(s.data[0].permission, 'viewer');
    const shareId = s.data[0].id;

    const view = await call('GET', `/tasks/${t.t3}`, { token: tok('stranger') });
    assert.equal(view.status, 200);
    assert.equal(view.data.myAccess.shareRole, 'viewer');
    assert.equal(view.data.myAccess.canEdit, false);
    const putV = await call('PUT', `/tasks/${t.t3}`, { token: tok('stranger'), body: { description: 'x' } });
    assert.equal(putV.status, 403);
    const stV = await call('PATCH', `/tasks/${t.t3}/status`, { token: tok('stranger'), body: { status: 'completed' } });
    assert.equal(stV.status, 403);
    assert.equal((await call('DELETE', `/tasks/${t.t3}`, { token: tok('stranger') })).status, 403);
    assert.equal((await share({ userIds: [users.member.id], permission: 'viewer' }, tok('stranger'))).status, 403);

    assert.equal((await share({ userIds: [users.member.id], permission: 'admin' })).status, 400);
    assert.equal((await share({ userIds: [users.owner.id], permission: 'viewer' })).status, 400);

    const up = await call('PATCH', `/tasks/${t.t3}/shares/${shareId}`, { token: tok('owner'), body: { permission: 'editor' } });
    assert.equal(up.status, 200);
    assert.equal(up.data[0].permission, 'editor');
    const putE = await call('PUT', `/tasks/${t.t3}`, { token: tok('stranger'), body: { description: 'Editor da sua' } });
    assert.equal(putE.status, 200);
    assert.equal((await call('DELETE', `/tasks/${t.t3}`, { token: tok('stranger') })).status, 403);
    assert.equal((await share({ userIds: [users.member.id], permission: 'viewer' }, tok('stranger'))).status, 403);

    const rev = await call('DELETE', `/tasks/${t.t3}/shares/${shareId}`, { token: tok('owner') });
    assert.equal(rev.status, 200);
    assert.equal(rev.data.length, 0);
    assert.equal((await call('GET', `/tasks/${t.t3}`, { token: tok('stranger') })).status, 403);
  });

  it('12. doi trang thai: nguoi duoc giao doi duoc, nguoi ngoai thi khong', async () => {
    const patch = (body, token) => call('PATCH', `/tasks/${t.t1}/status`, { token, body });
    const ok = await patch({ status: 'in_progress' }, tok('member'));
    assert.equal(ok.status, 200);
    assert.equal(ok.data.status, 'in_progress');
    assert.equal((await patch({ status: 'xong' }, tok('member'))).status, 400);
    assert.equal((await patch({ status: 'completed' }, tok('stranger'))).status, 403);
  });

  it('13. thong bao trong ung dung', async () => {
    const count = async (k) => (await call('GET', '/notifications/unread-count', { token: tok(k) })).data.count;
    const before = await count('member');
    assert.ok(before >= 2, 'Member phai co it nhat 2 thong bao giao viec');

    const unread = await call('GET', '/notifications?unread=true', { token: tok('member') });
    assert.equal(unread.status, 200);
    assert.ok(unread.data.every((n) => n.isRead === false));
    assert.ok(unread.data.some((n) => n.type === 'task_assigned' && n.taskId));

    assert.equal((await call('PATCH', `/notifications/${unread.data[0].id}/read`, { token: tok('stranger') })).status, 404);
    assert.equal((await call('PATCH', `/notifications/${unread.data[0].id}/read`, { token: tok('member') })).status, 200);
    assert.equal(await count('member'), before - 1);
    await call('PATCH', '/notifications/read-all', { token: tok('member') });
    assert.equal(await count('member'), 0);

    const ownerTypes = (await call('GET', '/notifications', { token: tok('owner') })).data.map((n) => n.type);
    assert.ok(ownerTypes.includes('status_changed'), 'Owner phai nhan thong bao khi member doi trang thai');
    const strangerTypes = (await call('GET', '/notifications', { token: tok('stranger') })).data.map((n) => n.type);
    for (const type of ['task_shared', 'share_updated', 'share_revoked']) {
      assert.ok(strangerTypes.includes(type), `Stranger thieu thong bao ${type}`);
    }
  });

  it('14. lich su email: chi nguoi tao xem duoc, gui lai co kiem soat', async () => {
    const logs = await call('GET', `/tasks/${t.t1}/email-logs`, { token: tok('owner') });
    assert.equal(logs.status, 200);
    const assigned = logs.data.find((l) => l.type === 'task_assigned');
    assert.ok(assigned, 'Thieu log email giao viec');
    assert.equal(assigned.recipientEmail, users.member.email);
    assert.ok(['pending', 'sent', 'failed'].includes(assigned.status));

    const shared = await call('GET', `/tasks/${t.t3}/email-logs`, { token: tok('owner') });
    assert.ok(shared.data.some((l) => l.type === 'task_shared'));

    assert.equal((await call('GET', `/tasks/${t.t1}/email-logs`, { token: tok('member') })).status, 403);
    assert.equal((await call('POST', `/email-logs/${assigned.id}/retry`, { token: tok('member') })).status, 403);
    assert.equal((await call('POST', '/email-logs/abc/retry', { token: tok('owner') })).status, 400);
    const fake = new mongoose.Types.ObjectId().toString();
    assert.equal((await call('POST', `/email-logs/${fake}/retry`, { token: tok('owner') })).status, 404);
  });

  it('15. thong ke theo trang thai, giao viec va han hoan thanh', async () => {
    assert.equal((await call('GET', '/statistics/tasks')).status, 401);

    const stats = await call('GET', '/statistics/tasks', { token: tok('owner') });
    assert.equal(stats.status, 200);
    const all = (await call('GET', '/tasks', { token: tok('owner') })).data;
    const expected = { total: all.length, todo: 0, in_progress: 0, completed: 0 };
    all.forEach((x) => (expected[x.status] += 1));
    assert.deepEqual(stats.data, expected);
    assert.equal(stats.data.total, 4);

    const ownerAs = (await call('GET', '/statistics/assignments', { token: tok('owner') })).data;
    assert.equal(ownerAs.createdByMe.total, 4);
    assert.equal(ownerAs.assignedByMe, 2);
    const memberAs = (await call('GET', '/statistics/assignments', { token: tok('member') })).data;
    assert.equal(memberAs.assignedToMe.total, 2);
    assert.equal(memberAs.assignedToMe.in_progress, 1);
    assert.equal(memberAs.assignedToMe.todo, 1);
    assert.equal(memberAs.primaryForMe.total, 2);

    const dl = (await call('GET', '/statistics/deadlines', { token: tok('owner') })).data;
    assert.equal(dl.overdue.count, 1);
    assert.equal(dl.overdue.items[0].id, t.t2);
    assert.equal(dl.dueSoon.count, 1);
    assert.equal(dl.dueSoon.items[0].id, t.t1);
    assert.equal(dl.dueToday.count, 0);
    assert.equal(dl.noDueDate.count, 1);
    const dl1 = (await call('GET', '/statistics/deadlines?days=1', { token: tok('owner') })).data;
    assert.equal(dl1.dueSoon.count, 0);
  });

  it('16. cap nhat ho so va doi mat khau', async () => {
    const put = (path, body) => call('PUT', path, { token: tok('owner'), body });
    const prof = await put('/auth/profile', { fullName: 'Chu Viec Moi' });
    assert.equal(prof.status, 200);
    assert.equal(prof.data.fullName, 'Chu Viec Moi');
    assert.equal((await put('/auth/profile', { fullName: '  ' })).status, 400);
    const me = await call('GET', '/auth/me', { token: tok('owner') });
    assert.equal(me.data.fullName, 'Chu Viec Moi');

    assert.equal((await put('/auth/change-password', { currentPassword: 'sai', newPassword: 'newpass123' })).status, 400);
    assert.equal((await put('/auth/change-password', { currentPassword: users.owner.password, newPassword: '123' })).status, 400);
    assert.equal((await put('/auth/change-password', { currentPassword: users.owner.password, newPassword: users.owner.password })).status, 400);
    assert.equal((await put('/auth/change-password', { currentPassword: users.owner.password, newPassword: 'newpass123' })).status, 200);

    const oldLogin = await call('POST', '/auth/login', { body: { email: users.owner.email, password: users.owner.password } });
    assert.equal(oldLogin.status, 401);
    const newLogin = await call('POST', '/auth/login', { body: { email: users.owner.email, password: 'newpass123' } });
    assert.equal(newLogin.status, 200);
  });

  it('17. xoa cong viec: chi nguoi tao xoa duoc va du lieu lien quan bi don', async () => {
    assert.equal((await call('DELETE', `/tasks/${t.t1}`, { token: tok('member') })).status, 403);
    assert.equal((await call('DELETE', `/tasks/${t.t1}`, { token: tok('stranger') })).status, 403);
    assert.equal((await call('DELETE', `/tasks/${t.t1}`, { token: tok('owner') })).status, 200);
    assert.equal((await call('GET', `/tasks/${t.t1}`, { token: tok('owner') })).status, 404);
    assert.equal(await Notification.countDocuments({ taskId: t.t1 }), 0);
    assert.equal(await EmailLog.countDocuments({ taskId: t.t1 }), 0);
    assert.equal(await TaskShare.countDocuments({ taskId: t.t1 }), 0);
  });
});