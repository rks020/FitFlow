import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
    const corsHeaders = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    };

    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const { email, password, first_name, last_name, organization_id } = await req.json();

        if (!email || !password || !organization_id) {
            return new Response(JSON.stringify({ error: 'Missing fields' }), { status: 400, headers: corsHeaders });
        }

        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );

        // Create user
        // IMPORTANT: Add organization_id to user_metadata for the Postgres Trigger to pick it up!
        const { data: userData, error: createError } = await supabaseAdmin.auth.admin.createUser({
            email,
            password,
            email_confirm: true,
            user_metadata: {
                first_name,
                last_name,
                full_name: `${first_name} ${last_name}`.trim(),
                display_name: `${first_name} ${last_name}`.trim(),
                role: 'member',
                organization_id, // REQUIRED for handle_new_user trigger
                password_changed: false,
            },
            app_metadata: {
                organization_id,
            },
        });

        if (createError || !userData.user) {
            console.error('Create error:', createError);
            return new Response(JSON.stringify({ error: createError?.message }), { status: 400, headers: corsHeaders });
        }

        // We DO NOT insert into profiles here, because 'handle_new_user' trigger does it automatically.
        // The trigger will read organization_id from user_metadata and set it.

        return new Response(
            JSON.stringify({ user: userData.user, message: 'Member created' }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );

    } catch (error) {
        console.error('Exception:', error);
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders });
    }
});
