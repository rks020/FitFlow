import { supabaseClient } from '../supabase-config.js';
import { showToast } from '../utils.js';

export async function loadTrainers() {
    const contentArea = document.getElementById('content-area');

    contentArea.innerHTML = `
        <div class="module-header">
            <h2>Antrenörler</h2>
            <button class="btn btn-primary" id="add-trainer-btn">+ Yeni Antrenör Ekle</button>
        </div>
        
        <div class="trainers-list" id="trainers-list">
            <p>Yükleniyor...</p>
        </div>
    `;

    // Load trainers
    await loadTrainersList();

    // Setup event listeners
    document.getElementById('add-trainer-btn').addEventListener('click', () => {
        window.location.href = 'add-trainer.html';
    });
}

async function loadTrainersList() {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;

        const { data: trainers, error } = await supabaseClient
            .from('profiles')
            .select('*')
            .eq('organization_id', profile.organization_id)
            .eq('role', 'trainer')
            .order('created_at', { ascending: false });

        if (error) throw error;

        const listContainer = document.getElementById('trainers-list');
        if (!listContainer) return; // Stop if user navigated away

        if (!trainers || trainers.length === 0) {
            listContainer.innerHTML = '<p>Henüz antrenör eklenmemiş.</p>';
            return;
        }

        listContainer.innerHTML = trainers.map(trainer => `
        <div class="trainer-card" onclick="openTrainerMembersModal('${trainer.id}', '${trainer.first_name} ${trainer.last_name}')" style="cursor: pointer; transition: transform 0.2s, box-shadow 0.2s;">
                <div class="trainer-header">
                    <div class="trainer-avatar">
                        ${(trainer.first_name?.[0] || 'T').toUpperCase()}
                    </div>
                    <div class="trainer-info">
                        <h3>${trainer.first_name} ${trainer.last_name}</h3>
                        <p>${trainer.specialty || 'Antrenör'}</p>
                    </div>
                </div>

                <div class="trainer-actions">
                    <button class="btn btn-small btn-secondary text-btn" onclick="event.stopPropagation(); editTrainer('${trainer.id}')">
                        Düzenle
                    </button>
                    <button class="btn btn-small btn-danger text-btn" onclick="event.stopPropagation(); deleteTrainer('${trainer.id}')">
                        Sil
                    </button>
                </div>
            </div>
        `).join('');

    } catch (error) {
        console.error('Error loading trainers:', error);
        showToast('Antrenörler yüklenirken hata oluştu', 'error');
    }
}

// Global functions for edit/delete
window.editTrainer = async (id) => {
    window.location.href = `edit-trainer.html?id=${id}`;
};

// Custom Modal Helper
function showConfirmation(title, message, onConfirm) {
    const modal = document.getElementById('confirm-modal');
    if (!modal) return;

    document.getElementById('confirm-title').textContent = title;
    document.getElementById('confirm-message').textContent = message;

    modal.classList.add('active');

    // Clean up old listeners
    const yesBtn = document.getElementById('confirm-yes');
    const cancelBtn = document.getElementById('confirm-cancel');
    const newYesBtn = yesBtn.cloneNode(true);
    const newCancelBtn = cancelBtn.cloneNode(true);

    yesBtn.parentNode.replaceChild(newYesBtn, yesBtn);
    cancelBtn.parentNode.replaceChild(newCancelBtn, cancelBtn);

    newYesBtn.addEventListener('click', async () => {
        modal.classList.remove('active');
        await onConfirm();
    });

    newCancelBtn.addEventListener('click', () => {
        modal.classList.remove('active');
    });
}

window.deleteTrainer = async (id) => {
    showConfirmation('Antrenörü Sil', 'Bu antrenörü ve hesabını kalıcı olarak silmek istediğinizden emin misiniz?', async () => {
        try {
            showToast('Siliniyor...', 'info');

            const { data, error } = await supabaseClient.functions.invoke('delete-user', {
                body: { user_id: id }
            });

            if (error) {
                console.error('Edge Function Error:', error);
                throw error;
            }

            showToast('Antrenör başarıyla silindi', 'success');
            await loadTrainersList();

        } catch (error) {
            console.error('Error deleting trainer:', error);
            showToast('Antrenör silinirken hata oluştu: ' + error.message, 'error');
        }
    });
};

/* Trainer Members Modal Logic */
let currentTrainerMembers = [];
let currentFilter = 'all'; // 'all' | 'multisport'

window.openTrainerMembersModal = async (trainerId, trainerName) => {
    const modal = document.getElementById('trainer-members-modal');
    if (!modal) return;

    document.getElementById('trainer-members-title').textContent = `${trainerName}`;

    // Reset States
    currentFilter = 'all';
    updateFilterUI();
    document.getElementById('trainer-members-search').value = '';

    modal.classList.add('active');

    await loadTrainerMembers(trainerId);

    // Setup listeners
    document.getElementById('close-trainer-members-modal').onclick = () => modal.classList.remove('active');
    document.getElementById('filter-all').onclick = () => setFilter('all');
    document.getElementById('filter-multisport').onclick = () => setFilter('multisport');
    document.getElementById('trainer-members-search').oninput = (e) => renderTrainerMembers(e.target.value);

    // Close on outside click
    window.onclick = (e) => {
        if (e.target == modal) modal.classList.remove('active');
    };
};

async function loadTrainerMembers(trainerId) {
    const listContainer = document.getElementById('trainer-members-list');
    listContainer.innerHTML = '<p style="text-align: center; color: #888; padding: 20px;">Yükleniyor...</p>';

    try {
        const { data: members, error } = await supabaseClient
            .from('members')
            .select('*')
            .eq('trainer_id', trainerId)
            .order('name', { ascending: true });

        if (error) throw error;

        currentTrainerMembers = members || [];
        renderTrainerMembers();

    } catch (error) {
        console.error('Error loading trainer members:', error);
        listContainer.innerHTML = '<p style="text-align: center; color: #ef4444; padding: 20px;">Üyeler yüklenirken hata oluştu.</p>';
    }
}

function setFilter(type) {
    currentFilter = type;
    updateFilterUI();
    renderTrainerMembers(document.getElementById('trainer-members-search').value);
}

function updateFilterUI() {
    const allBtn = document.getElementById('filter-all');
    const multiBtn = document.getElementById('filter-multisport');

    if (currentFilter === 'all') {
        allBtn.style.background = '#FFD700';
        allBtn.style.color = '#000';
        multiBtn.style.background = 'transparent';
        multiBtn.style.color = '#888';
    } else {
        allBtn.style.background = 'transparent';
        allBtn.style.color = '#888';
        multiBtn.style.background = '#FFD700';
        multiBtn.style.color = '#000';
    }
}

function renderTrainerMembers(searchQuery = '') {
    const listContainer = document.getElementById('trainer-members-list');

    let filtered = currentTrainerMembers.filter(m => {
        if (currentFilter === 'multisport') {
            return m.is_multisport;
        }
        return true;
    });

    if (searchQuery) {
        const q = searchQuery.toLowerCase();
        filtered = filtered.filter(m =>
            m.name.toLowerCase().includes(q) ||
            (m.email && m.email.toLowerCase().includes(q))
        );
    }

    if (filtered.length === 0) {
        listContainer.innerHTML = '<div style="text-align: center; padding: 40px; color: #888;"><div style="font-size: 32px; margin-bottom: 10px;">👥</div>Üye bulunamadı.</div>';
        return;
    }

    listContainer.innerHTML = filtered.map(member => `
        <div style="background: rgba(255,255,255,0.03); padding: 16px; border-radius: 12px; margin-bottom: 12px; display: flex; align-items: center; justify-content: space-between; border: 1px solid rgba(255,255,255,0.05);">
            <div style="display: flex; align-items: center; gap: 16px;">
                <div style="width: 44px; height: 44px; background: rgba(255,215,0,0.1); border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #FFD700; font-weight: bold; font-size: 18px;">
                    ${(member.name?.[0] || 'Ü').toUpperCase()}
                </div>
                <div>
                    <div style="color: #fff; font-weight: 600; font-size: 15px; margin-bottom: 4px;">${member.name}</div>
                    <div style="color: #888; font-size: 13px;">${member.email || '-'}</div>
                </div>
            </div>
            <div style="display: flex; flex-direction: column; align-items: flex-end; gap: 6px;">
                 ${member.is_active
            ? '<span style="font-size: 11px; color: #10b981; background: rgba(16,185,129,0.1); padding: 4px 10px; border-radius: 6px; font-weight: 600;">Aktif</span>'
            : '<span style="font-size: 11px; color: #ef4444; background: rgba(239,68,68,0.1); padding: 4px 10px; border-radius: 6px; font-weight: 600;">Pasif</span>'}
                 ${member.is_multisport
            ? '<span style="font-size: 11px; color: #FFD700; background: rgba(255,215,0,0.1); padding: 4px 10px; border-radius: 6px; font-weight: 600;">Multisport</span>'
            : ''}
            </div>
        </div>
    `).join('');
}
