const router = require('express').Router();
const c = require('../controllers/notificationController');
const auth = require('../middleware/authMiddleware');

router.use(auth);
router.get('/', c.list);
router.get('/unread-count', c.unreadCount);
router.patch('/read-all', c.markAllRead);
router.patch('/:id/read', c.markRead);

module.exports = router;