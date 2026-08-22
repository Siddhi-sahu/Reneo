import { Response } from 'express';
import { createPublicSupabaseClient, createUserSupabaseClient } from '../config/supabase';
import { AuthRequest, CommerceRole } from '../types';
import { ApiError, asyncHandler } from '../middleware/errorHandler';

const sendAuthResponse = (
    res: Response,
    statusCode: number,
    data: {
        id: string;
        email?: string;
        role?: CommerceRole;
        full_name?: string | null;
        access_token?: string;
        refresh_token?: string;
    }
): void => {
    res.status(statusCode).json({
        success: true,
        data: {
        id: data.id,
        email: data.email,
        role: data.role,
        full_name: data.full_name,
    },
    session: data.access_token
        ? {
            access_token: data.access_token,
            refresh_token: data.refresh_token,
            token_type: 'bearer',
            }
        : null,
    });
};

export const register = asyncHandler<AuthRequest>(async (req, res) => {
    const { full_name, email, password, role = 'CUSTOMER' } = req.body as {
            full_name?: string;
            email: string;
            password: string;
            role?: CommerceRole;
        };

    const supabase = createPublicSupabaseClient();
    const { data, error } = await supabase.auth.signUp({
        email,
        password,
            options: {
            data: {
                full_name,
                role,
            },
            },
        });

    if (error) {
        throw new ApiError(error.status || 400, error.message);
    }

    if (!data.user) {
            throw new ApiError(500, 'Supabase did not return a user');
        }

        sendAuthResponse(res, 201, {
            id: data.user.id,
            email: data.user.email,
            role,
            full_name: full_name || null,
            access_token: data.session?.access_token,
            refresh_token: data.session?.refresh_token,
        });
});

export const login = asyncHandler<AuthRequest>(async (req, res) => {
    const { email, password } = req.body as { email: string; password: string };
    const supabase = createPublicSupabaseClient();

    const { data, error } = await supabase.auth.signInWithPassword({ email, password });

    if (error || !data.user || !data.session) {
        throw new ApiError(401, 'Invalid credentials');
    }

    const authedClient = createUserSupabaseClient(data.session.access_token);
    const { data: profile, error: profileError } = await authedClient
        .from('profiles')
        .select('id, full_name, role')
        .eq('id', data.user.id)
        .single<{ id: string; full_name: string | null; role: CommerceRole }>();

    if (profileError || !profile) {
        throw new ApiError(403, 'Authenticated user has no profile');
    }

    sendAuthResponse(res, 200, {
        id: data.user.id,
        email: data.user.email,
        role: profile.role,
        full_name: profile.full_name,
        access_token: data.session.access_token,
        refresh_token: data.session.refresh_token,
    });
});

export const getMe = asyncHandler<AuthRequest>(async (req, res) => {
    if (!req.user || !req.profile) {
        throw new ApiError(401, 'Not authorized');
    }

    res.status(200).json({
        success: true,
        data: {
        id: req.user.id,
        email: req.user.email,
        role: req.profile.role,
        full_name: req.profile.full_name,
        },
    });
});
