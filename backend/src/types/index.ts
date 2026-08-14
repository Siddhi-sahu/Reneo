import { Request } from 'express';
import { SupabaseClient, User } from '@supabase/supabase-js';

export type CommerceRole = 'SELLER' | 'CUSTOMER';

export interface Profile {
  id: string;
  full_name: string | null;
  role: CommerceRole;
  created_at: string;
  updated_at: string;
}

export interface AuthPayload {
  id: string;
  email?: string;
  role: CommerceRole;
}

export interface AuthRequest extends Request {
  user?: AuthPayload;
  authUser?: User;
  profile?: Profile;
  supabase?: SupabaseClient;
  accessToken?: string;
}
