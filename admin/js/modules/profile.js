import { supabaseClient } from '../supabase-config.js';
import { showToast } from '../utils.js';

export async function loadProfile() {
    const contentArea = document.getElementById('content-area');

    contentArea.innerHTML = `
        <div class="profile-container">
            <h2>Profil Ayarları</h2>
            <div class="profile-card">
                <h3>Kullanıcı Bilgileri</h3>
                <p id="profile-email">-</p>
            </div>
            <div class="profile-card">
                <h3>Organizasyon</h3>
                <p id="profile-org">-</p>
            </div>
            <button class="btn btn-danger" id="delete-account-btn">Hesabı Sil</button>
        </div>

        <style>
            .profile-container {
                max-width: 600px;
            }
            
            .profile-card {
                background: var(--surface-color);
                border: 1px solid var(--glass-border);
                border-radius: 16px;
                padding: 24px;
                margin-bottom: 16px;
            }

            .profile-card h3 {
                margin-bottom: 12px;
                font-size: 16px;
                color: var(--text-secondary);
            }

            .btn-danger {
                margin-top: 24px;
            }
        </style>
    `;

    // Load profile data
    await loadProfileData();
}

async function loadProfileData() {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('*, organizations(name)')
            .eq('id', user.id)
            .single();

        document.getElementById('profile-email').textContent = user.email;
        document.getElementById('profile-org').textContent = profile?.organizations?.name || 'Yükleniyor...';

    } catch (error) {
        console.error('Error loading profile:', error);
        showToast('Profil yüklenirken hata', 'error');
    }
}
