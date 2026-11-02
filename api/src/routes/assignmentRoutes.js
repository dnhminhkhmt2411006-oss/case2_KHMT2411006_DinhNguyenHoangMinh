const router = require('express').Router({ mergeParams: true });
const c = require('../controllers/assignmentController');
const { loadTask } = require('../middleware/permissionMiddleware');

router.get('/', loadTask('view'), c.list);
router.post('/', loadTask('manage'), c.add);
router.patch('/:userId', loadTask('manage'), c.setPrimary);
router.delete('/:userId', loadTask('manage'), c.remove);

module.exports = router;