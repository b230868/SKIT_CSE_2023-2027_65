import "dotenv/config";
import { createClient, SupabaseClient, User } from "@supabase/supabase-js";

const supabaseUrl = process.env.SUPABASE_URL || "";
const supabaseKey =
  process.env.SUPABASE_PUBLISHABLE_KEY ||
  process.env.SUPABASE_ANON_KEY ||
  "";

if (!supabaseUrl || !supabaseKey) {
  console.warn(
    "WARNING: SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY is missing. Token verification will fail until configured."
  );
}

export const supabase: SupabaseClient | null =
  supabaseUrl && supabaseKey
    ? createClient(supabaseUrl, supabaseKey, {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      })
    : null;

/**
 * Validates a Supabase JWT access token using Supabase Auth server.
 * Returns the verified user object, or throws an error.
 */
export async function verifySupabaseToken(token: string): Promise<User> {
  if (!supabase) {
    throw new Error(
      "Supabase Auth is not configured (missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY)"
    );
  }

  const { data, error } = await supabase.auth.getUser(token);

  if (error || !data.user) {
    throw new Error(error?.message || "Invalid authentication token");
  }

  return data.user;
}
