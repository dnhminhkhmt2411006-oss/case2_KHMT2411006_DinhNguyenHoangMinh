const router = require('express').Router();
const c = require('../controllers/taskController');
const auth = require('../middleware/authMiddleware');
const { loadTask } = require('../middleware/permissionMiddleware');

router.use(auth);

router.get('/', c.list);
router.post('/', c.create);

router.use('/:id/assignees', require('./assignmentRoutes'));
router.use('/:id/shares', require('./taskShareRoutes'));

router.get('/:id', loadTask('view'), c.detail);
router.put('/:id', loadTask('edit'), c.update);
router.patch('/:id/status', loadTask('status'), c.updateStatus);
router.delete('/:id', loadTask('delete'), c.remove);

module.exports = router;