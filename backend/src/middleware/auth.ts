import { Response, NextFunction } from 'express';
import { createUserSupabaseClient } from '../config/supabase';
import { AuthRequest, Profile } from '../types';

export const protect = async (
    req: AuthRequest,
    res: Response,
    next: NextFunction
): Promise<void> => {
    const authHeader = req.headers.authorization;

    if (!authHeader?.startsWith('Bearer ')) {
        res.status(401).json({ success: false, message: 'Not authorized, no token' });
        return;
    }

  try {
    const accessToken = authHeader.split(' ')[1];
    const supabase = createUserSupabaseClient(accessToken);

        const {
        data: { user },
        error: userError,
    } = await supabase.auth.getUser(accessToken);

    if (userError || !user) {
        res.status(401).json({ success: false, message: 'Token invalid or expired' });
        return;
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, full_name, role, created_at, updated_at')
        .eq('id', user.id)
        .single<Profile>();

    if (profileError || !profile) {
        res.status(403).json({ success: false, message: 'Authenticated user has no profile' });
        return;
    }

    req.accessToken = accessToken;
    req.supabase = supabase;
    req.authUser = user;
    req.profile = profile;
    req.user = { id: user.id, email: user.email, role: profile.role };

    next();
  } catch (error) {
    next(error);
  }
};

export const sellerOnly = (req: AuthRequest, res: Response, next: NextFunction): void => {
    if (req.user?.role !== 'SELLER') {
        res.status(403).json({ success: false, message: 'Seller access required' });
        return;
    }

    next();
};

export const customerOnly = (req: AuthRequest, res: Response, next: NextFunction): void => {
  if (req.user?.role !== 'CUSTOMER') {
    res.status(403).json({ success: false, message: 'Customer access required' });
        return;
    }

  next();
};
