import { createClient, SupabaseClient } from '@supabase/supabase-js';

//helper func
const requiredEnv = (name: string): string => {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is not configured`);
  }

  return value;
};

export const getSupabaseUrl = (): string => requiredEnv('SUPABASE_URL');

export const getSupabaseAnonKey = (): string => requiredEnv('SUPABASE_ANON_KEY');

export const createPublicSupabaseClient = (): SupabaseClient =>
  createClient(getSupabaseUrl(), getSupabaseAnonKey(), {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

export const createUserSupabaseClient = (accessToken: string): SupabaseClient =>
  createClient(getSupabaseUrl(), getSupabaseAnonKey(), {
    global: {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
