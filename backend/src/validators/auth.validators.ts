import { body } from 'express-validator';

export const registerValidator = [
  body('full_name')
    .optional()
    .trim()
    .isLength({ min: 2, max: 120 })
    .withMessage('Full name must be between 2 and 120 characters'),
  body('email').trim().isEmail().withMessage('A valid email is required').normalizeEmail(),
  body('password')
    .isLength({ min: 6, max: 72 })
    .withMessage('Password must be between 6 and 72 characters'),
  body('role')
    .optional()
    .isIn(['SELLER', 'CUSTOMER'])
    .withMessage('Role must be either SELLER or CUSTOMER'),
];

export const loginValidator = [
  body('email').trim().isEmail().withMessage('A valid email is required').normalizeEmail(),
  body('password').notEmpty().withMessage('Password is required'),
];
