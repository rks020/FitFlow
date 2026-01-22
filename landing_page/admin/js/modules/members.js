import { supabaseClient } from '../supabase-config.js';
import { showToast } from '../utils.js';

export async function loadMembers() {
    const contentArea = document.getElementById('content-area');

    contentArea.innerHTML = `
        <div class="module-header">
            <h2>Üyeler</h2>
            <button class="btn btn-primary" id="add-member-btn">+ Yeni Üye Ekle</button>
        </div>
        
        <div class="search-bar">
            <input type="text" id="member-search" placeholder="Üye ara..." style="width: 100%; padding: 12px; background: var(--surface-dark); border: 1px solid var(--glass-border); border-radius: 12px; color: var(--text-primary);">
        </div>

        <div class="members-list" id="members-list">
            <p>Yükleniyor...</p>
        </div>

        <style>
            .search-bar {
                margin-bottom: 24px;
            }
            
            .members-list {
                display: grid;
                gap: 16px;
            }

            .member-card {
                background: var(--surface-color);
                border: 1px solid var(--glass-border);
                border-radius: 16px;
                padding: 20px;
                display: flex;
                align-items: center;
                gap: 20px;
                transition: all 0.3s ease;
            }

            .member-card:hover {
                background: rgba(255, 255, 255, 0.02);
            }

            .member-avatar {
                width: 60px;
                height: 60px;
                border-radius: 50%;
                background: var(--neon-cyan);
                color: #000;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 24px;
                font-weight: 700;
                flex-shrink: 0;
            }

            .member-info {
                flex: 1;
            }

            .member-info h3 {
                margin: 0 0 8px;
                font-size: 18px;
            }

            .member-info p {
                margin: 0;
                color: var(--text-secondary);
                font-size: 14px;
            }

            .member-actions {
                display: flex;
                gap: 8px;
            }
        </style>
    `;

    // Load members
    await loadMembersList();

    // Setup search
    document.getElementById('member-search').addEventListener('input', (e) => {
        const query = e.target.value.toLowerCase();
        document.querySelectorAll('.member-card').forEach(card => {
            const name = card.querySelector('h3').textContent.toLowerCase();
            card.style.display = name.includes(query) ? 'flex' : 'none';
        });
    });

    // Add member button (placeholder)
    document.getElementById('add-member-btn').addEventListener('click', () => {
        showToast('Üye ekleme özelliği yakında gelecek', 'info');
    });
}

async function loadMembersList() {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;

        const { data: members, error } = await supabaseClient
            .from('profiles')
            .select('*')
            .eq('organization_id', profile.organization_id)
            .eq('role', 'member')
            .order('created_at', { ascending: false });

        if (error) throw error;

        const listContainer = document.getElementById('members-list');

        if (!members || members.length === 0) {
            listContainer.innerHTML = '<p>Henüz üye eklenmemiş.</p>';
            return;
        }

        listContainer.innerHTML = members.map(member => `
            <div class="member-card">
                <div class="member-avatar">
                    ${(member.first_name?.[0] || 'M').toUpperCase()}
                </div>
                <div class="member-info">
                    <h3>${member.first_name || ''} ${member.last_name || ''}</h3>
                    <p>${member.profession || 'Üye'} ${member.age ? `• ${member.age} yaş` : ''}</p>
                </div>
                <div class="member-actions">
                    <button class="btn btn-small btn-secondary" onclick="viewMember('${member.id}')">
                        Görüntüle
                    </button>
                </div>
            </div>
        `).join('');

    } catch (error) {
        console.error('Error loading members:', error);
        showToast('Üyeler yüklenirken hata oluştu', 'error');
    }
}

window.viewMember = (id) => {
    showToast('Üye detayları yakında eklenecek', 'info');
};
