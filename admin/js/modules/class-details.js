import { supabaseClient } from '../supabase-config.js';
import { showToast } from '../utils.js';

let currentSessionId = null;
let originalData = {};
let currentCallback = null; // To refresh parent list (loadHistory or loadClasses)

export function setUpdateCallback(cb) {
    currentCallback = cb;
}

export async function openClassDetailModal(sessionId) {
    currentSessionId = sessionId;
    const modal = document.getElementById('class-detail-modal');
    const updateBtn = document.getElementById('update-class-btn');

    // Reset UI
    const titleInput = document.getElementById('detail-title-input');
    if (titleInput) titleInput.value = 'Yükleniyor...';
    document.getElementById('detail-member-name').textContent = '-';
    document.getElementById('detail-avatar').textContent = '-';
    document.getElementById('detail-date-input').value = '';
    document.getElementById('detail-time-start').value = '';
    document.getElementById('detail-time-end').value = '';
    document.getElementById('detail-title-input').value = '';
    
    // Reset colors
    document.querySelectorAll('.color-opt').forEach(opt => opt.style.borderColor = 'transparent');

    updateBtn.style.display = 'none';
    document.getElementById('complete-class-btn').style.display = 'none';

    try {
        const { data: session, error } = await supabaseClient
            .from('class_sessions')
            .select(`
                *,
                trainer:trainer_id(first_name, last_name),
                enrollments:class_enrollments(
                    member_id,
                    status,
                    member:member_id(name)
                )
            `)
            .eq('id', sessionId)
            .single();

        if (error) throw error;

        // Populate Data
        const startDate = new Date(session.start_time);
        const endDate = new Date(session.end_time);

        // Detect type: 'ders' if has enrollment, 'etkinlik' if free event
        const hasEnrollments = session.enrollments && session.enrollments.length > 0;
        const isClass = hasEnrollments;
        const typeLabel = isClass ? 'Ders' : 'Etkinlik';

        // Update modal labels
        const heading = document.getElementById('detail-modal-heading');
        const titleLabel = document.getElementById('detail-title-label');
        const completeBtnText = document.getElementById('complete-btn-text');
        if (heading) heading.textContent = `${typeLabel} Detayı`;
        if (titleLabel) titleLabel.textContent = `${typeLabel} Adı`;
        if (completeBtnText) completeBtnText.textContent = `${typeLabel}i Tamamla`;

        // Store type for delete dialog
        modal.dataset.sessionType = typeLabel;

        // Date & Time Inputs
        const dateStr = startDate.toISOString().split('T')[0];
        const timeStartStr = startDate.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });
        const timeEndStr = endDate.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });

        document.getElementById('detail-date-input').value = dateStr;
        document.getElementById('detail-time-start').value = timeStartStr;
        document.getElementById('detail-time-end').value = timeEndStr;

        // Store original for comparison
        originalData = {
            date: dateStr,
            start: timeStartStr,
            end: timeEndStr,
            title: session.title || '',
            color: session.color || '#06B6D4'
        };

        // UI Updates for Title & Color
        document.getElementById('detail-title-input').value = originalData.title;
        updateColorSelection(originalData.color);

        // Member Info (Ders only)
        if (isClass) {
            const memberNames = session.enrollments.map(e => e.member.name).join(' - ');
            document.getElementById('detail-member-name').textContent = memberNames;
            document.getElementById('detail-avatar').textContent = session.enrollments.length > 1 ? '👥' : session.enrollments[0].member.name.charAt(0).toUpperCase();
        } else {
            document.getElementById('detail-member-name').textContent = '—';
            document.getElementById('detail-avatar').textContent = '🎉';
        }

        // Action Buttons Visibility
        if (session.status === 'scheduled') {
            document.getElementById('complete-class-btn').style.display = isClass ? 'flex' : 'none';
        }

        modal.classList.add('active');

    } catch (err) {
        showToast('Detaylar yüklenemedi', 'error');
    }
}

// Check for changes to show Update button
function checkChanges() {
    const newDate = document.getElementById('detail-date-input').value;
    const newStart = document.getElementById('detail-time-start').value;
    const newEnd = document.getElementById('detail-time-end').value;

    const newTitle = document.getElementById('detail-title-input').value;
    const activeColor = document.querySelector('.color-opt.active')?.dataset.color || originalData.color;

    const hasChanged =
        newDate !== originalData.date ||
        newStart !== originalData.start ||
        newEnd !== originalData.end ||
        newTitle !== originalData.title ||
        activeColor !== originalData.color;

    document.getElementById('update-class-btn').style.display = hasChanged ? 'block' : 'none';
}

// Initial Setup
export function setupClassDetailModal() {
    const modal = document.getElementById('class-detail-modal');
    if (!modal) return;

    // Changes Listener
    ['detail-date-input', 'detail-time-start', 'detail-time-end', 'detail-title-input'].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.addEventListener('input', checkChanges);
    });

    // Color options
    document.querySelectorAll('.color-opt').forEach(opt => {
        opt.onclick = () => {
            document.querySelectorAll('.color-opt').forEach(o => o.classList.remove('active', 'selected'));
            document.querySelectorAll('.color-opt').forEach(o => o.style.borderColor = 'transparent');
            opt.classList.add('active');
            opt.style.borderColor = '#fff';
            checkChanges();
        };
    });

    // Close
    document.getElementById('close-detail-modal').onclick = () => {
        modal.classList.remove('active');
    };

    // Update Action
    document.getElementById('update-class-btn').onclick = saveChanges;

    // Delete Modal Trigger - update texts based on session type
    document.getElementById('delete-class-trigger').onclick = () => {
        const typeLabel = modal.dataset.sessionType || 'Ders';
        const delHeading = document.getElementById('delete-modal-heading');
        const delSingleText = document.getElementById('delete-single-text');
        const delProgramBtn = document.getElementById('delete-program-btn');
        if (delHeading) delHeading.textContent = `${typeLabel} Şablonunu Sil`;
        if (delSingleText) delSingleText.textContent = `Şablonu ve Gelecek Tüm Kopyaları Sil`;
        if (delProgramBtn) delProgramBtn.style.display = 'none'; // hide extra button

        modal.classList.remove('active');
        document.getElementById('delete-confirm-modal').classList.add('active');
    };

    // Delete Actions
    document.getElementById('delete-single-btn').onclick = () => deleteClass();

    // Cancel Delete
    const cancelDelete = document.getElementById('cancel-delete-btn');
    if (cancelDelete) { // if exists
        cancelDelete.onclick = () => document.getElementById('delete-confirm-modal').classList.remove('active');
    } else {
        // Fallback if user clicks outside or needs close button
        const closeDelete = document.querySelector('#delete-confirm-modal .close-modal');
        if (closeDelete) closeDelete.onclick = () => document.getElementById('delete-confirm-modal').classList.remove('active');
    }

    // Complete Action
    document.getElementById('complete-class-btn').onclick = completeClass;
}

async function saveChanges() {
    const newDate = document.getElementById('detail-date-input').value;
    const newStart = document.getElementById('detail-time-start').value;
    const newEnd = document.getElementById('detail-time-end').value;
    const newTitle = document.getElementById('detail-title-input').value;
    const activeColor = document.querySelector('.color-opt.active')?.dataset.color || originalData.color;

    const btn = document.getElementById('update-class-btn');
    btn.textContent = 'Kaydediliyor...';
    btn.disabled = true;

    try {
        // Construct ISO strings
        const startDateTime = new Date(`${newDate}T${newStart}`);
        let endDateTime = new Date(`${newDate}T${newEnd}`);

        if (isNaN(startDateTime) || isNaN(endDateTime)) throw new Error('Geçersiz tarih/saat');

        // Midnight wrap: if end <= start, it means next day (e.g. 23:00 → 00:00)
        if (endDateTime <= startDateTime) {
            endDateTime.setDate(endDateTime.getDate() + 1);
        }

        const { error } = await supabaseClient
            .from('class_sessions')
            .update({
                start_time: startDateTime.toISOString(),
                end_time: endDateTime.toISOString(),
                title: newTitle,
                color: activeColor
            })
            .eq('id', currentSessionId);

        if (error) throw error;

        // Also update future copies (only title and color, not time!)
        await supabaseClient
            .from('class_sessions')
            .update({
                title: newTitle,
                color: activeColor
            })
            .eq('template_id', currentSessionId)
            .gt('start_time', new Date().toISOString());

        showToast('Şablon güncellendi. (Saat değişimleri gelecekteki kopyalara uygulanmaz, gerekirse şablonu silip yeniden ekleyin)', 'success');
        document.getElementById('class-detail-modal').classList.remove('active');
        if (currentCallback) currentCallback();

    } catch (err) {
        showToast('Güncelleme başarısız: ' + err.message, 'error');
    } finally {
        btn.textContent = 'Değişiklikleri Kaydet';
        btn.disabled = false;
    }
}

async function deleteClass() {
    if (!currentSessionId) return;
    const modal = document.getElementById('delete-confirm-modal');

    try {
        // 1. Delete FUTURE generated sessions tied to this template
        await supabaseClient
            .from('class_sessions')
            .delete()
            .eq('template_id', currentSessionId)
            .gt('start_time', new Date().toISOString());

        // 2. Delete the template itself (past copies stay with template_id = NULL)
        const { error } = await supabaseClient
            .from('class_sessions')
            .delete()
            .eq('id', currentSessionId);

        if (error) throw error;
        
        showToast('Şablon ve gelecek dersler başarıyla silindi', 'success');
        modal.classList.remove('active');
        if (currentCallback) currentCallback();

    } catch (err) {
        showToast('Silme işlemi başarısız', 'error');
    }
}

async function completeClass() {
    if (!currentSessionId) return;

    try {
        const { data: session } = await supabaseClient
            .from('class_sessions')
            .select('class_enrollments(member_id)')
            .eq('id', currentSessionId)
            .single();

        const memberId = session?.class_enrollments?.[0]?.member_id;

        const { error } = await supabaseClient
            .from('class_sessions')
            .update({ status: 'completed' })
            .eq('id', currentSessionId);

        if (error) throw error;

        // Update count if member exists
        if (memberId) {
            const { data: member } = await supabaseClient
                .from('members')
                .select('used_session_count')
                .eq('id', memberId)
                .single();

            await supabaseClient
                .from('members')
                .update({ used_session_count: (member?.used_session_count || 0) + 1 })
                .eq('id', memberId);
        }

        showToast('Ders tamamlandı', 'success');
        document.getElementById('class-detail-modal').classList.remove('active');
        if (currentCallback) currentCallback();

    } catch (err) {
        showToast('Tamamlama başarısız', 'error');
    }
}

function updateColorSelection(color) {
    document.querySelectorAll('.color-opt').forEach(opt => {
        opt.classList.remove('active');
        opt.style.borderColor = 'transparent';
        if (opt.dataset.color.toUpperCase() === color.toUpperCase()) {
            opt.classList.add('active');
            opt.style.borderColor = '#fff';
        }
    });
}

// Global exposure for non-module access
window.openClassDetailModal = openClassDetailModal;
window.setupClassDetailModal = setupClassDetailModal;
