const router = require('express').Router({ mergeParams: true });
const c = require('../controllers/taskShareController');
const { loadTask } = require('../middleware/permissionMiddleware');

router.get('/', loadTask('view'), c.list);
router.post('/', loadTask('manage'), c.add);
router.patch('/:shareId', loadTask('manage'), c.updatePermission);
router.delete('/:shareId', loadTask('manage'), c.revoke);

module.exports = router;