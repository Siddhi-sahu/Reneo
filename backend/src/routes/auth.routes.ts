import { Router } from 'express';
import { getMe, login, register } from '../controllers/auth.controller';
import { protect } from '../middleware/auth';
import { validateRequest } from '../middleware/validate';
import { loginValidator, registerValidator } from '../validators/auth.validators';

const router = Router();

router.post('/register', registerValidator, validateRequest, register);
router.post('/login', loginValidator, validateRequest, login);
router.get('/me', protect, getMe);

export default router;
