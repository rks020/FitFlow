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

        if (!trainers || trainers.length === 0) {
            listContainer.innerHTML = '<p>Henüz antrenör eklenmemiş.</p>';
            return;
        }

        listContainer.innerHTML = trainers.map(trainer => `
        <div class="trainer-card">
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
                    <button class="btn btn-small btn-secondary" onclick="editTrainer('${trainer.id}')">
                        Düzenle
                    </button>
                    <button class="btn btn-small btn-danger" onclick="deleteTrainer('${trainer.id}')">
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
    showToast('Düzenleme özelliği yakında eklenecek', 'info');
};

window.deleteTrainer = async (id) => {
    if (!confirm('Bu antrenörü silmek istediğinizden emin misiniz?')) return;

    try {
        const { error } = await supabaseClient
            .from('profiles')
            .delete()
            .eq('id', id);

        if (error) throw error;

        showToast('Antrenör silindi', 'success');
        await loadTrainersList();

    } catch (error) {
        console.error('Error deleting trainer:', error);
        showToast('Antrenör silinirken hata oluştu', 'error');
    }
};
