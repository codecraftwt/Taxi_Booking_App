const express = require('express');
const router = express.Router();

router.use('/driver', require('./driver/driver_router'));
router.use('/user', require('./user/user_router'));
router.use('/ride', require('./user/ride_router'));
router.use('/auth', require('./shared/auth_router'));
router.use('/payment', require('./shared/payment_router'));

module.exports = router;
