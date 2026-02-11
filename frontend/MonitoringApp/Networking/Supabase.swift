import Foundation
import Supabase

/// Global Supabase client instance
/// Configure with your project URL and anon key from Supabase dashboard
/// Note: The "Initial session emitted" warning is expected behavior in the current SDK version
/// and will be addressed in a future major release. See: https://github.com/supabase/supabase-swift/pull/822
let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://xepuiarjjucaurgutzvm.supabase.co")!,
  supabaseKey: "sb_publishable_dfFg8WwL_L7CrnGqvK2gvQ_Y9fcwZ9V"
)
