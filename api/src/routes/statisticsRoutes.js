const router = require('express').Router();
const c = require('../controllers/statisticsController');
const auth = require('../middleware/authMiddleware');

router.use(auth);
router.get('/tasks', c.byStatus);
router.get('/assignments', c.assignments);
router.get('/deadlines', c.deadlines);

module.exports = router;