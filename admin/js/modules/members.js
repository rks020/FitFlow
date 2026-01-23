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
            <input type="text" id="member-search" placeholder="Üye ara...">
        </div>

        <div class="members-list" id="members-list">
            <p>Yükleniyor...</p>
        </div>
    `;

    // Load members
    await loadMembersList();

    // Setup event listeners
    document.getElementById('add-member-btn').addEventListener('click', () => {
        window.location.href = 'add-member.html';
    });

    // Search functionality
    const searchInput = document.getElementById('member-search');
    let debounceTimer;

    searchInput.addEventListener('input', (e) => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            loadMembersList(e.target.value);
        }, 500);
    });
}

async function loadMembersList(searchQuery = '') {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;

        let query = supabaseClient
            .from('profiles')
            .select('*')
            .eq('organization_id', profile.organization_id)
            .eq('role', 'member')
            .order('created_at', { ascending: false });

        if (searchQuery) {
            query = query.or(`first_name.ilike.%${searchQuery}%,last_name.ilike.%${searchQuery}%,email.ilike.%${searchQuery}%`);
        }

        const { data: members, error } = await query;

        if (error) throw error;

        const listContainer = document.getElementById('members-list');

        if (!members || members.length === 0) {
            listContainer.innerHTML = '<p>Üye bulunamadı.</p>';
            return;
        }

        listContainer.innerHTML = members.map(member => `
            <div class="member-card">
                <div class="member-header">
                    <div class="member-avatar">
                        ${(member.first_name?.[0] || 'Ü').toUpperCase()}
                    </div>
                    <div class="member-info">
                        <h3>${member.first_name} ${member.last_name}</h3>
                        <p>${member.email || ''}</p>
                    </div>
                </div>

                <div class="member-actions">
                    <button class="btn btn-small btn-secondary" onclick="editMember('${member.id}')">
                        Düzenle
                    </button>
                    <button class="btn btn-small btn-danger" onclick="deleteMember('${member.id}')">
                        Sil
                    </button>
                </div>
            </div>
        `).join('');

    } catch (error) {
        console.error('Error loading members:', error);
        showToast('Üyeler yüklenirken hata oluştu', 'error');
    }
}

// Global functions
window.editMember = async (id) => {
    showToast('Düzenleme özelliği yakında eklenecek', 'info');
};

window.deleteMember = async (id) => {
    if (!confirm('Bu üyeyi silmek istediğinizden emin misiniz?')) return;

    try {
        const { error } = await supabaseClient
            .from('profiles')
            .delete()
            .eq('id', id);

        if (error) throw error;

        showToast('Üye silindi', 'success');
        await loadMembersList();

    } catch (error) {
        console.error('Error deleting member:', error);
        showToast('Üye silinirken hata oluştu', 'error');
    }
};
