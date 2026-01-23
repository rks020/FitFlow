import { supabaseClient } from './supabase-config.js';
import { showToast } from './utils.js';
import { loadDashboard } from './modules/dashboard.js';

// Initialize Auth
export function initAuth() {
    console.log('Initializing Auth...');
    checkSession();
}

// Check Session
async function checkSession() {
    const { data: { session } } = await supabaseClient.auth.getSession();

    if (session) {
        // Verify user role
        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('role, organization_id, first_name, last_name')
            .eq('id', session.user.id)
            .single();

        if (profile && (profile.role === 'owner' || profile.role === 'trainer') && profile.organization_id) {
            setupUserInterface(session.user, profile);
            loadDashboard(); // Load initial content
        } else {
            // Invalid role
            await supabaseClient.auth.signOut();
            window.location.href = 'login.html';
        }
    } else {
        // No session
        window.location.href = 'login.html';
    }
}

// Setup User Interface
function setupUserInterface(user, profile) {
    // Set user info
    const userNameElement = document.getElementById('user-name');
    if (userNameElement) {
        const userName = `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || user.email;
        userNameElement.textContent = userName;
    }
}

// Logout
export async function logout() {
    await supabaseClient.auth.signOut();
    window.location.href = 'login.html';
}
