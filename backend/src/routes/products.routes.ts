import { Router } from 'express';
import { protect, sellerOnly } from '../middleware/auth';
import { addProduct, getProduct, listProducts } from '../controllers/product.controller';
import { createProductValidator, productIdParamValidator } from '../validators/products.validators';
import { validateRequest } from '../middleware/validate';

const router = Router();

router.use(protect, sellerOnly);

router.get("/", listProducts);
router.post("/", createProductValidator, validateRequest, addProduct);
router.delete("/:id")
router.get("/:id", productIdParamValidator, validateRequest, getProduct);
router.patch("/:id",)

export default router;