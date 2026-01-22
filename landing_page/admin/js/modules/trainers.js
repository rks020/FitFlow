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

        <!-- Add Trainer Modal -->
        <div id="add-trainer-modal" class="modal">
            <div class="modal-content" style="max-width: 500px;">
                <h2>Yeni Antrenör Ekle</h2>
                <form id="add-trainer-form">
                    <div class="form-group">
                        <label>Ad</label>
                        <input type="text" id="trainer-firstname" required>
                    </div>
                    <div class="form-group">
                        <label>Soyad</label>
                        <input type="text" id="trainer-lastname" required>
                    </div>
                    <div class="form-group">
                        <label>Email</label>
                        <input type="email" id="trainer-email" required>
                    </div>
                    <div class="form-group">
                        <label>Uzmanlık (opsiyonel)</label>
                        <input type="text" id="trainer-specialty" placeholder="Örn: PT, Diyetisyen">
                    </div>
                    <div class="form-actions">
                        <button type="button" class="btn btn-secondary" id="cancel-trainer-btn">İptal</button>
                        <button type="submit" class="btn btn-primary">Kaydet</button>
                    </div>
                </form>
            </div>
        </div>

        <style>
            .module-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 24px;
            }

            .trainers-list {
                display: grid;
                grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
                gap: 20px;
            }

            .trainer-card {
                background: var(--surface-color);
                border: 1px solid var(--glass-border);
                border-radius: 16px;
                padding: 20px;
                transition: all 0.3s ease;
            }

            .trainer-card:hover {
                transform: translateY(-4px);
                box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
            }

            .trainer-header {
                display: flex;
                align-items: center;
                gap: 16px;
                margin-bottom: 16px;
            }

            .trainer-avatar {
                width: 60px;
                height: 60px;
                border-radius: 50%;
                background: var(--primary-yellow);
                color: #000;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 24px;
                font-weight: 700;
            }

            .trainer-info h3 {
                margin: 0;
                font-size: 18px;
            }

            .trainer-info p {
                margin: 4px 0 0;
                color: var(--text-secondary);
                font-size: 14px;
            }

            .trainer-actions {
                display: flex;
                gap: 8px;
                margin-top: 16px;
            }

            .btn-small {
                flex: 1;
                padding: 8px;
                font-size: 13px;
                border-radius: 8px;
            }

            .btn-secondary {
                background: var(--surface-dark);
                color: var(--text-primary);
                border: 1px solid var(--glass-border);
            }

            .btn-danger {
                background: rgba(255, 59, 48, 0.2);
                color: var(--error);
                border: 1px solid var(--error);
            }

            .form-actions {
                display: flex;
                gap: 12px;
                margin-top: 24px;
            }

            .form-actions button {
                flex: 1;
            }
        </style>
    `;

    // Load trainers
    await loadTrainersList();

    // Setup event listeners
    document.getElementById('add-trainer-btn').addEventListener('click', () => {
        document.getElementById('add-trainer-modal').classList.add('active');
    });

    document.getElementById('cancel-trainer-btn').addEventListener('click', () => {
        document.getElementById('add-trainer-modal').classList.remove('active');
        document.getElementById('add-trainer-form').reset();
    });

    document.getElementById('add-trainer-form').addEventListener('submit', handleAddTrainer);
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
                <div class="trainer-details">
                    <p style="font-size: 14px; color: var(--text-secondary);">
                        📧 ${trainer.id.slice(0, 8)}...
                    </p>
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

async function handleAddTrainer(e) {
    e.preventDefault();

    const firstname = document.getElementById('trainer-firstname').value.trim();
    const lastname = document.getElementById('trainer-lastname').value.trim();
    const email = document.getElementById('trainer-email').value.trim();
    const specialty = document.getElementById('trainer-specialty').value.trim();

    if (!firstname || !lastname || !email) {
        showToast('Lütfen gerekli alanları doldurun', 'error');
        return;
    }

    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) {
            showToast('Organizasyon bilgisi bulunamadı', 'error');
            return;
        }

        // Call RPC function to invite trainer
        const { error } = await supabaseClient.rpc('invite_trainer', {
            trainer_email: email,
            trainer_first_name: firstname,
            trainer_last_name: lastname,
            trainer_specialty: specialty || null,
            org_id: profile.organization_id
        });

        if (error) throw error;

        showToast('Antrenör davet edildi! Email gönderildi.', 'success');
        document.getElementById('add-trainer-modal').classList.remove('active');
        document.getElementById('add-trainer-form').reset();
        await loadTrainersList();

    } catch (error) {
        console.error('Error adding trainer:', error);
        showToast('Antrenör eklenirken hata: ' + error.message, 'error');
    }
}

// Global functions for edit/delete (could be improved with event delegation)
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
