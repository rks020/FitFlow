
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
    // CORS Headers
    const corsHeaders = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
    };

    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
        );

        // 1. Check Auth (Caller must be logged in)
        const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
        if (authError || !user) {
            return new Response(JSON.stringify({ error: 'Unauthorized' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        // 2. Get Request Data
        const body = await req.json();
        const targetUserId = body.user_id;

        if (!targetUserId) {
            return new Response(JSON.stringify({ error: 'User ID is required' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        // 3. Admin Client (Service Role)
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );

        // 3.1 Fetch Caller's Profile to get Organization ID
        const { data: callerProfile, error: profileError } = await supabaseAdmin
            .from('profiles')
            .select('organization_id, role')
            .eq('id', user.id)
            .single();

        if (profileError || !callerProfile?.organization_id) {
            return new Response(JSON.stringify({ error: 'Caller has no organization' }), {
                status: 403,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        // Optional: Check if caller is admin/owner
        if (callerProfile.role !== 'owner' && callerProfile.role !== 'admin') {
            return new Response(JSON.stringify({ error: 'Insufficient permissions' }), {
                status: 403,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        const organizationId = callerProfile.organization_id;

        // 4. Verify Target User authorization
        // We need to ensure the user belongs to THIS organization, not another one

        // Check profiles table
        const { data: targetProfile } = await supabaseAdmin
            .from('profiles')
            .select('organization_id')
            .eq('id', targetUserId)
            .single();

        // Check app_metadata
        const { data: targetAuthData } = await supabaseAdmin.auth.admin.getUserById(targetUserId);
        const targetAuthUser = targetAuthData?.user;
        const targetMetadata = targetAuthUser?.app_metadata;

        // Determine the user's organization from either source
        const userOrgFromProfile = targetProfile?.organization_id;
        const userOrgFromMeta = targetMetadata?.organization_id;

        console.log(`Delete request: caller org=${organizationId}, target profile org=${userOrgFromProfile}, target meta org=${userOrgFromMeta}`);

        // SIMPLIFIED LOGIC:
        // If user has NO organization anywhere (orphaned), allow deletion
        const isOrphaned = !userOrgFromProfile && !userOrgFromMeta;

        // If user belongs to caller's org (in either place), allow deletion
        const belongsToCallerOrg =
            userOrgFromProfile === organizationId ||
            userOrgFromMeta === organizationId;

        // DENY only if user explicitly belongs to a DIFFERENT organization
        if (!isOrphaned && !belongsToCallerOrg) {
            return new Response(JSON.stringify({ error: 'User belongs to another organization' }), {
                status: 403,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        console.log(`Deleting user ${targetUserId} from organization ${organizationId}`);

        // 5. Perform Deletion

        // 5.0 Delete from fcm_tokens (foreign key dependency)
        const { error: fcmDeleteError } = await supabaseAdmin
            .from('fcm_tokens')
            .delete()
            .eq('user_id', targetUserId);

        if (fcmDeleteError) console.error('FCM tokens delete error:', fcmDeleteError);

        // 5.1 Delete from public.members
        const { error: memberDeleteError } = await supabaseAdmin
            .from('members')
            .delete()
            .eq('id', targetUserId);

        if (memberDeleteError) console.error('Member delete error:', memberDeleteError);

        // 5.2 Delete from public.profiles
        const { error: profileDeleteError } = await supabaseAdmin
            .from('profiles')
            .delete()
            .eq('id', targetUserId);

        if (profileDeleteError) console.error('Profile delete error:', profileDeleteError);

        // 5.3 Delete from Auth Users
        const { error: authDeleteError } = await supabaseAdmin.auth.admin.deleteUser(targetUserId);

        if (authDeleteError) {
            console.error('Auth delete error:', authDeleteError);
            return new Response(JSON.stringify({ error: authDeleteError.message }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        return new Response(JSON.stringify({ message: 'User deleted successfully' }), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });

    } catch (error) {
        console.error('Exception:', error);
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
    }
});
