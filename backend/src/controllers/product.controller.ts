import { createPublicSupabaseClient } from "../config/supabase"

export const getProducts = async(req:any, res:any) =>{
    //query db and get products

    const supabase = createPublicSupabaseClient();

    // supabase.

}

export const addProducts = async(req: any, res:any) => {
    //seller can add a products only to their respective store
}