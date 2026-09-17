import { AuthRequest } from '../types';
import { ApiError, asyncHandler } from '../middleware/errorHandler';

type ProductInput = {
    name: string;
    description?: string;
    category: string;
    sku?: string;
    price_amount: number;
    currency?: string;
};
//need seller's own id, so helper
const getOwnStoreId = async(req: AuthRequest): Promise<string> => {
    const {data : store, error} = await req.supabase!.from('stores').select('id').eq('seller_id', req.user!.id).single<{id: string}>();

    if (error || !store) {
    throw new ApiError(404, 'You do not have a store yet');
    }
    return store.id;
}

export const addProduct = asyncHandler<AuthRequest>(async(req, res) => {
    //seller can add a products only to their respective store
    const storeId = await getOwnStoreId(req);
    const body = req.body as ProductInput;

    const {data: product, error} = await req.supabase!.from('products').insert({
        store_id: storeId,
        name: body.name,
        description: body.description ?? null,
        category: body.category,
        sku: body.sku ?? null,
        price_amount: body.price_amount,
        currency: body.currency ?? 'XOF',
    }).select().single()

    if (error || !product) {
    throw new ApiError(400, error?.message || 'Could not create product');
    }

    res.status(201).json({ success: true, data: product });

});

export const listProducts = asyncHandler<AuthRequest>(async(req, res) =>{
    const storeId = await getOwnStoreId(req);

    const {data: products, error} = await req.supabase!.from('products').select('*').eq('store_id', storeId).order('created_at', { ascending: false });

    if (error){
        throw new ApiError(400, error.message);
    };

    res.status(200).json({ success: true, data: products});

});

export const getProduct = asyncHandler<AuthRequest>(async(req, res)=>{
    const storeId = await getOwnStoreId(req);
    const {id} = req.params;

    const {data:product, error} = await req.supabase!.from('products').select('*').eq('id', id).eq('store_id', storeId).single();

    if(error || !product){
        throw new ApiError(404, 'Product not found');
    };

    res.status(200).json({success: true, data: product});
});
