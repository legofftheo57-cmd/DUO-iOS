// Deploy as Supabase Edge Function `delete-account`, with platform JWT verification
// enabled. This function NEVER accepts a user ID from a request body.
import { withSupabase } from "npm:@supabase/server@1";

export default {
  fetch: withSupabase({ auth: "user" }, async (request, ctx) => {
    if (request.method !== "POST") {
      return Response.json({ message: "Méthode non autorisée." }, { status: 405 });
    }
    const userID = ctx.userClaims?.id;
    if (!userID) return Response.json({ message: "Non authentifié." }, { status: 401 });

    // Step 1 is an atomic SQL operation executed with the verified caller's JWT.
    // If step 2 fails, the deletion marker prevents a stale JWT from rejoining.
    // Retry this endpoint to finish the Auth deletion.
    const { error: dataError } = await ctx.supabase.rpc("erase_my_data");
    if (dataError) {
      console.error("DUO data erasure failed", dataError.code);
      return Response.json({ message: "Suppression impossible ; aucune confirmation." }, { status: 503 });
    }
    const { error: authError } = await ctx.supabaseAdmin.auth.admin.deleteUser(userID);
    if (authError) {
      console.error("DUO Auth erasure failed", authError.code);
      return Response.json({ message: "Effacement lancé mais suppression du compte incomplète. Réessayez." }, { status: 503 });
    }
    return Response.json({ deleted: true });
  }),
};
