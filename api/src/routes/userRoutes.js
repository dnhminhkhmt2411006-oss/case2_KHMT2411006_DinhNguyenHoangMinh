const router = require('express').Router();
const c = require('../controllers/userController');
const auth = require('../middleware/authMiddleware');

router.use(auth);
router.get('/search', c.search);
router.get('/:id', c.getById);

module.exports = router;