const router = require('express').Router();
const c = require('../controllers/emailLogController');
const auth = require('../middleware/authMiddleware');

router.use(auth);
router.post('/:id/retry', c.retry);

module.exports = router;