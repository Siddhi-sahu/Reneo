import { body, param } from 'express-validator';

export const createProductValidator = [
    body('name')
        .trim()
        .isLength({ min: 2, max: 160 })
        .withMessage('Name must be between 2 and 160 characters'),
    body('description')
        .optional()
        .trim()
        .isLength({ max: 2000 })
        .withMessage('Description must be under 2000 characters'),
    body('category')
        .trim()
        .isLength({ min: 2, max: 80 })
        .withMessage('Category must be between 2 and 80 characters'),
    body('sku')
        .optional()
        .trim()
        .isLength({ min: 1, max: 64 })
        .withMessage('SKU must be between 1 and 64 characters'),
    body('price_amount')
        .isInt({ min: 1 })
        .withMessage('Price must be a positive whole number (smallest currency unit, e.g. cents)'),
    body('currency')
        .optional()
        .trim()
        .matches(/^[A-Z]{3}$/)
        .withMessage('Currency must be a 3-letter ISO code, e.g. XOF'),
];

export const updateProductValidator = [
    param('id').isUUID().withMessage('Invalid product id'),
    body('name')
        .optional()
        .trim()
        .isLength({ min: 2, max: 160 })
        .withMessage('Name must be between 2 and 160 characters'),
    body('description')
        .optional()
        .trim()
        .isLength({ max: 2000 })
        .withMessage('Description must be under 2000 characters'),
    body('category')
        .optional()
        .trim()
        .isLength({ min: 2, max: 80 })
        .withMessage('Category must be between 2 and 80 characters'),
    body('sku')
        .optional()
        .trim()
        .isLength({ min: 1, max: 64 })
        .withMessage('SKU must be between 1 and 64 characters'),
    body('price_amount')
        .optional()
        .isInt({ min: 1 })
        .withMessage('Price must be a positive whole number'),
    body('currency')
        .optional()
        .trim()
        .matches(/^[A-Z]{3}$/)
        .withMessage('Currency must be a 3-letter ISO code, e.g. XOF'),
    body('status')
        .optional()
        .isIn(['ACTIVE', 'ARCHIVED'])
        .withMessage('Status must be ACTIVE or ARCHIVED'),
];

export const productIdParamValidator = [param('id').isUUID().withMessage('Invalid product id')];