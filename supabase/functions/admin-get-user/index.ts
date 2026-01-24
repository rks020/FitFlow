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

        const { data: { user: currentUser }, error: userError } = await supabaseClient.auth.getUser();

        if (userError || !currentUser) {
            return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: corsHeaders });
        }

        // Check if admin/owner
        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('role')
            .eq('id', currentUser.id)
            .single();

        if (!profile || (profile.role !== 'admin' && profile.role !== 'owner')) {
            return new Response(JSON.stringify({ error: 'Forbidden' }), { status: 403, headers: corsHeaders });
        }

        const { user_id } = await req.json();

        if (!user_id) {
            return new Response(JSON.stringify({ error: 'User ID required' }), { status: 400, headers: corsHeaders });
        }

        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );

        const { data: userData, error: getError } = await supabaseAdmin.auth.admin.getUserById(user_id);

        if (getError) {
            return new Response(JSON.stringify({ error: getError.message }), { status: 400, headers: corsHeaders });
        }

        return new Response(
            JSON.stringify(userData),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders });
    }
});
