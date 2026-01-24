import { supabaseClient } from './supabase-config.js';
import { showToast } from './utils.js';

document.addEventListener('DOMContentLoaded', async () => {
    // Get ID from URL
    const urlParams = new URLSearchParams(window.location.search);
    const trainerId = urlParams.get('id');

    if (!trainerId) {
        showToast('Antrenör ID bulunamadı', 'error');
        setTimeout(() => window.location.href = 'dashboard.html#trainers', 1500);
        return;
    }

    // Check session
    const { data: { session } } = await supabaseClient.auth.getSession();
    if (!session) {
        window.location.href = 'login.html';
        return;
    }

    // Check role
    const { data: profile } = await supabaseClient
        .from('profiles')
        .select('role')
        .eq('id', session.user.id)
        .single();

    if (!profile || (profile.role !== 'owner' && profile.role !== 'admin')) {
        showToast('Bu işlem için yetkiniz yok', 'error');
        setTimeout(() => window.location.href = 'dashboard.html', 1500);
        return;
    }

    // Load Trainer Data
    try {
        const { data: trainer, error } = await supabaseClient
            .from('profiles')
            .select('*')
            .eq('id', trainerId)
            .single();

        if (error) throw error;

        // Fill Form
        document.getElementById('trainer-id').value = trainer.id;
        document.getElementById('trainer-firstname').value = trainer.first_name;
        document.getElementById('trainer-lastname').value = trainer.last_name;
        document.getElementById('trainer-specialty').value = trainer.specialty || '';

        // Handle Email
        if (trainer.email) {
            document.getElementById('trainer-email').value = trainer.email;
        } else {
            // Fetch email from Auth via Edge Function
            try {
                const { data, error } = await supabaseClient.functions.invoke('admin-get-user', {
                    body: { user_id: trainerId }
                });

                if (data && data.user && data.user.email) {
                    document.getElementById('trainer-email').value = data.user.email;
                }
            } catch (err) {
                console.warn('Could not fetch email from auth:', err);
                document.getElementById('trainer-email').placeholder = 'Email unavailable';
            }
        }

    } catch (error) {
        console.error('Error loading trainer:', error);
        showToast('Antrenör bilgileri yüklenemedi', 'error');
    }

    // Handle Save
    const form = document.getElementById('edit-trainer-form');
    const saveBtn = document.getElementById('save-trainer-btn');

    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const firstname = document.getElementById('trainer-firstname').value.trim();
        const lastname = document.getElementById('trainer-lastname').value.trim();
        const specialty = document.getElementById('trainer-specialty').value.trim();

        if (!firstname || !lastname) {
            showToast('Ad ve Soyad zorunludur', 'error');
            return;
        }

        saveBtn.disabled = true;
        saveBtn.querySelector('.btn-text').style.display = 'none';
        saveBtn.querySelector('.btn-loader').style.display = 'inline';

        try {
            const { error } = await supabaseClient
                .from('profiles')
                .update({
                    first_name: firstname,
                    last_name: lastname,
                    specialty: specialty || null
                })
                .eq('id', trainerId);

            if (error) throw error;

            showToast('Antrenör bilgileri güncellendi!', 'success');
            setTimeout(() => {
                window.location.href = 'dashboard.html#trainers';
            }, 1000);

        } catch (error) {
            console.error('Error updating trainer:', error);
            showToast('Güncelleme hatası: ' + error.message, 'error');
        } finally {
            saveBtn.disabled = false;
            saveBtn.querySelector('.btn-text').style.display = 'inline';
            saveBtn.querySelector('.btn-loader').style.display = 'none';
        }
    });

});
