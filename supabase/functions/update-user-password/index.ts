
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
        );

        // 1. Verify Caller is Admin/Owner
        const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
        if (authError || !user) {
            return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: corsHeaders });
        }

        // Get caller profile to check role
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );

        const { data: callerProfile } = await supabaseAdmin
            .from('profiles')
            .select('role, organization_id')
            .eq('id', user.id)
            .single();

        if (!callerProfile || !['admin', 'owner'].includes(callerProfile.role)) {
            return new Response(JSON.stringify({ error: 'Unauthorized access' }), { status: 403, headers: corsHeaders });
        }

        // 2. Parse Request
        const { userId, newPassword } = await req.json();
        if (!userId || !newPassword) {
            return new Response(JSON.stringify({ error: 'Missing userId or newPassword' }), { status: 400, headers: corsHeaders });
        }

        if (newPassword.length < 6) {
            return new Response(JSON.stringify({ error: 'Password must be at least 6 characters' }), { status: 400, headers: corsHeaders });
        }

        // 3. Verify Target User
        const { data: targetProfile, error: targetError } = await supabaseAdmin
            .from('profiles')
            .select('organization_id, password_changed')
            .eq('id', userId)
            .single();

        if (targetError || !targetProfile) {
            return new Response(JSON.stringify({ error: 'User not found' }), { status: 404, headers: corsHeaders });
        }

        // Check organization match
        if (targetProfile.organization_id !== callerProfile.organization_id) {
            return new Response(JSON.stringify({ error: 'User belongs to different organization' }), { status: 403, headers: corsHeaders });
        }

        // 4. Check Permission: Only if password NOT changed yet
        if (targetProfile.password_changed === true) {
            return new Response(JSON.stringify({ error: 'Users who have set their own password cannot have it reset by admin.' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }

        // 5. Update Password
        const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(userId, {
            password: newPassword
        });

        if (updateError) throw updateError;

        return new Response(JSON.stringify({ message: 'Password updated successfully' }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200
        });

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
});
