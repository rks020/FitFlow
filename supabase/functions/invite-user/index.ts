
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
    // CORS Headers
    const corsHeaders = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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
        const email = body.email ? body.email.trim() : null;
        const data = body.data;

        console.log(`Invite request for: '${email}'`);

        if (!email) {
            return new Response(JSON.stringify({ error: 'Email is required' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        // 3. Admin Client (Service Role) - REQUIRED to fetch profile & invite
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );

        // 3.1 Fetch Caller's Profile to get real Organization ID
        const { data: callerProfile, error: profileError } = await supabaseAdmin
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (profileError || !callerProfile?.organization_id) {
            return new Response(JSON.stringify({ error: 'Caller has no organization' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        const organizationId = callerProfile.organization_id;

        // 4. Check if user already exists in auth
        const { data: listData, error: listError } = await supabaseAdmin.auth.admin.listUsers({ perPage: 1000 });
        const users = listData?.users;

        console.log(`Checking existence for email: [${email}]`);

        if (!listError && users) {
            console.log(`Total users in auth: ${users.length}`);

            const existingUser = users.find(u => u.email?.toLowerCase() === email.toLowerCase());
            if (existingUser) {
                console.log('Found existing user:', existingUser.id, existingUser.email);

                // Check if user is orphaned (no organization_id)
                const isOrphaned = !existingUser.app_metadata?.organization_id;

                // Also check profile
                const { data: existingProfile } = await supabaseAdmin
                    .from('profiles')
                    .select('organization_id')
                    .eq('id', existingUser.id)
                    .single();

                const profileOrphaned = !existingProfile || !existingProfile.organization_id;

                // If user is orphaned in EITHER auth OR profile, link them
                if (isOrphaned || profileOrphaned) {
                    console.log(`Linking orphaned user ${existingUser.id} to organization ${organizationId}`);

                    // Update Auth Metadata
                    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
                        existingUser.id,
                        {
                            app_metadata: { organization_id: organizationId },
                            user_metadata: { ...data }
                        }
                    );

                    if (updateError) {
                        console.error('Failed to update auth user:', updateError);
                        return new Response(JSON.stringify({ error: 'Kullanıcı güncellenemedi: ' + updateError.message }), {
                            status: 500,
                            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                        });
                    }

                    // Update/Create Profile
                    await supabaseAdmin
                        .from('profiles')
                        .upsert({
                            id: existingUser.id,
                            organization_id: organizationId,
                            first_name: data.first_name,
                            last_name: data.last_name,
                            role: data.role || 'member',
                            updated_at: new Date().toISOString()
                        })
                        .eq('id', existingUser.id);

                    // Send OTP to notify user
                    const { error: otpError } = await supabaseAdmin.auth.signInWithOtp({
                        email: email,
                        options: {
                            data: { ...data, organization_id: organizationId },
                            emailRedirectTo: 'io.supabase.fitflow://login-callback'
                        }
                    });

                    if (otpError) {
                        console.error('Failed to send OTP/Magic Link:', otpError);
                    }

                    return new Response(JSON.stringify({
                        user: {
                            id: existingUser.id,
                            email: existingUser.email,
                            app_metadata: { organization_id: organizationId },
                            user_metadata: data
                        },
                        message: 'Kullanıcı organizasyonunuza bağlandı.'
                    }), {
                        status: 200,
                        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                    });
                }

                // User exists and belongs to same organization
                if (existingProfile?.organization_id === organizationId) {
                    return new Response(JSON.stringify({
                        user: {
                            id: existingUser.id,
                            email: existingUser.email,
                            app_metadata: existingUser.app_metadata,
                            user_metadata: existingUser.user_metadata
                        },
                        message: 'Kullanıcı zaten organizasyonunuzda mevcut.'
                    }), {
                        status: 200,
                        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                    });
                }

                // User belongs to different organization
                return new Response(JSON.stringify({ error: 'Bu kullanıcı başka bir organizasyona ait.' }), {
                    status: 400,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                });
            }
        }

        // 5. Create User and send OTP (not Magic Link)
        console.log(`Creating new user: ${email}`);

        // Step 5a: Create the user manually
        const { data: createData, error: createError } = await supabaseAdmin.auth.admin.createUser({
            email,
            email_confirm: false, // Will be confirmed via OTP
            user_metadata: {
                ...data,
                password_changed: false,
            },
            app_metadata: {
                organization_id: organizationId,
            }
        });

        if (createError || !createData.user) {
            console.error('Create User Error:', createError);
            return new Response(JSON.stringify({ error: createError?.message || 'Failed to create user' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        const newUserId = createData.user.id;

        // Step 5b: Create profile entry
        await supabaseAdmin.from('profiles').insert({
            id: newUserId,
            organization_id: organizationId,
            first_name: data.first_name,
            last_name: data.last_name,
            role: data.role || 'member',
            password_changed: false,
        });

        // Step 5c: Send confirmation OTP via generateLink
        const { data: linkData, error: otpError } = await supabaseAdmin.auth.admin.generateLink({
            type: 'signup',
            email,
            options: {
                data: {
                    ...data,
                    organization_id: organizationId,
                }
            }
        });

        if (otpError) {
            console.error('OTP Send Error:', otpError);
            // Don't fail the whole operation, user was created successfully
        } else {
            console.log('Confirmation OTP sent successfully');
        }

        return new Response(JSON.stringify({
            user: createData.user,
            message: 'Kullanıcı oluşturuldu. E-postasına doğrulama kodu gönderildi.'
        }), {
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
