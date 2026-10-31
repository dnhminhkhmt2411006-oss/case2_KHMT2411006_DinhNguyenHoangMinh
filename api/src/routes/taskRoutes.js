const router = require('express').Router();
const c = require('../controllers/taskController');
const auth = require('../middleware/authMiddleware');

router.use(auth);
router.get('/', c.list);
router.get('/:id', c.detail);

module.exports = router;