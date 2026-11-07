const router = require('express').Router();
const c = require('../controllers/authController');
const auth = require('../middleware/authMiddleware');

router.post('/register', c.register);
router.post('/login', c.login);
router.get('/me', auth, c.me);
router.put('/profile', auth, c.updateProfile);
router.put('/change-password', auth, c.changePassword);

module.exports = router;