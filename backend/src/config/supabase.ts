import "dotenv/config";
import { createClient, SupabaseClient, User } from "@supabase/supabase-js";

const supabaseUrl = process.env.SUPABASE_URL || "";
const supabaseKey =
  process.env.SUPABASE_PUBLISHABLE_KEY ||
  process.env.SUPABASE_ANON_KEY ||
  "";

if (!supabaseUrl || !supabaseKey) {
  console.warn(
    "WARNING: SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY is missing. Token verification may fail."
  );
}

export const supabase: SupabaseClient = createClient(supabaseUrl, supabaseKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
});

/**
 * Validates a Supabase JWT access token using Supabase Auth server.
 * Returns the verified user object, or throws an error.
 */
export async function verifySupabaseToken(token: string): Promise<User> {
  const { data, error } = await supabase.auth.getUser(token);

  if (error || !data.user) {
    throw new Error(error?.message || "Invalid authentication token");
  }

  return data.user;
}
