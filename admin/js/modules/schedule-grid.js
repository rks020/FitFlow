import { supabaseClient } from '../supabase-config.js';
import { showToast, formatDate, turkishToLower } from '../utils.js';
import { openClassDetailModal, setupClassDetailModal, setUpdateCallback } from './class-details.js';

const TEMPLATE_WEEK_START = new Date('2024-01-01T00:00:00'); // Pazartesi
let currentWeekStart = TEMPLATE_WEEK_START;
let selectedTrainerId = null;
let trainersCache = [];
let sessionsCache = [];
let closedDaysCache = []; // stores date strings 'YYYY-MM-DD' for the selected trainer
let selectedMembersForCreate = []; // [{id, name}, ...]

export async function loadWeeklySchedule() {
    const contentArea = document.getElementById('content-area');
    
    // Disable outer scrolling for this module to fit everything on screen
    contentArea.style.overflow = 'hidden';
    contentArea.style.height = 'calc(100vh - 80px)';

    contentArea.innerHTML = `
        <div class="weekly-schedule-container">
            <div class="schedule-controls" style="display: flex; align-items: center; justify-content: space-between;">
                <div class="trainer-tabs" id="trainer-tabs" style="justify-content: flex-start; margin-left: 0;">
                    <div class="tab loading">Hocalar yükleniyor...</div>
                </div>
                <div style="display: flex; gap: 8px; align-items: center;">
                    <span id="week-label" class="week-label">Sabit Şablon Programı</span>
                </div>
            </div>

            <div class="grid-wrapper">
                <div class="schedule-grid" id="schedule-grid">
                    <!-- Grid will be injected here -->
                </div>
            </div>
        </div>

        <style>
            .weekly-schedule-container {
                display: flex;
                flex-direction: column;
                gap: 12px;
                height: 100%;
            }

            .schedule-controls {
                display: flex;
                justify-content: space-between;
                align-items: center;
                background: rgba(255, 255, 255, 0.03);
                padding: 12px 20px;
                border-radius: 16px;
                border: 1px solid rgba(255, 255, 255, 0.05);
            }

            .trainer-tabs {
                display: flex;
                gap: 10px;
            }

            .trainer-tab {
                padding: 10px 20px;
                border-radius: 12px;
                background: rgba(255, 255, 255, 0.05);
                color: #888;
                font-weight: 600;
                cursor: pointer;
                transition: all 0.2s;
                border: 1px solid rgba(255, 255, 255, 0.05);
                font-size: 14px;
                text-transform: uppercase;
            }

            .trainer-tab.active {
                background: #FFD700;
                color: #000;
                box-shadow: 0 4px 15px rgba(255, 215, 0, 0.2);
            }

            .week-nav {
                display: flex;
                align-items: center;
                gap: 8px;
                background: rgba(255, 255, 255, 0.05);
                padding: 6px;
                border-radius: 14px;
                border: 1px solid rgba(255, 255, 255, 0.08);
            }

            .nav-btn {
                width: 36px;
                height: 36px;
                display: flex;
                align-items: center;
                justify-content: center;
                background: rgba(255, 255, 255, 0.08);
                border: 1px solid rgba(255, 255, 255, 0.1);
                border-radius: 10px;
                color: #fff;
                cursor: pointer;
                transition: all 0.2s;
                font-size: 14px;
            }

            .nav-btn:hover {
                background: rgba(255, 255, 255, 0.15);
                border-color: #FFD700;
                transform: translateY(-1px);
            }

            .nav-btn:active {
                transform: translateY(0);
            }

            .nav-btn-today {
                padding: 0 16px;
                height: 36px;
                background: rgba(255, 215, 0, 0.1);
                border: 1px solid rgba(255, 215, 0, 0.2);
                border-radius: 10px;
                color: #FFD700;
                font-size: 13px;
                font-weight: 600;
                cursor: pointer;
                transition: all 0.2s;
                margin-left: 4px;
            }

            .nav-btn-today:hover {
                background: #FFD700;
                color: #000;
                box-shadow: 0 4px 15px rgba(255, 215, 0, 0.2);
            }

            .week-label {
                font-weight: 700;
                color: #fff;
                min-width: 160px;
                text-align: center;
                font-size: 14px;
                letter-spacing: -0.2px;
            }

            .grid-wrapper {
                flex: 1;
                overflow-x: auto;
                overflow-y: hidden; /* No scroll, fit to screen */
                background: #1C1C1E;
                border-radius: 20px;
                border: 1px solid rgba(255, 255, 255, 0.08);
                position: relative;
                height: calc(100vh - 180px); /* Fit exactly to screen */
            }

            .schedule-grid {
                display: grid;
                grid-template-columns: 70px repeat(7, 1fr);
                grid-template-rows: auto repeat(17, 1fr); /* 07:00 - 23:00 is 17 rows, fixed 1fr to fit screen */
                height: 100%;
                min-width: 900px;
                min-height: 0;
            }

            .grid-header-cell {
                padding: 10px 5px;
                text-align: center;
                background: rgba(255, 255, 255, 0.02);
                border-bottom: 2px solid rgba(255, 255, 255, 0.05);
                position: sticky;
                top: 0;
                z-index: 10;
                font-size: 13px;
            }

            .day-name { font-weight: 700; color: #FFD700; margin-bottom: 4px; }
            .day-date { font-size: 12px; color: #888; }

            .time-axis-cell {
                padding: 5px;
                text-align: center;
                border-right: 1px solid rgba(255, 255, 255, 0.05);
                font-size: 11px;
                color: #888;
                font-weight: 600;
                background: #1C1C1E;
                position: sticky;
                left: 0;
                z-index: 9;
                display: flex;
                align-items: center;
                justify-content: center;
            }

            .grid-cell {
                border-bottom: 1px solid rgba(255, 255, 255, 0.03);
                border-right: 1px solid rgba(255, 255, 255, 0.03);
                min-height: 0;
                position: relative;
                transition: background 0.2s;
            }

            .grid-cell.drag-over {
                background: rgba(255, 215, 0, 0.1);
            }

            .session-item {
                position: absolute;
                top: 2px;
                left: 2px;
                right: 2px;
                bottom: 2px;
                background: #06B6D4; /* Default Cyan */
                border-radius: 8px;
                padding: 8px;
                font-size: 12px;
                font-weight: 700;
                color: #000;
                display: flex;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                overflow: hidden;
                box-shadow: 0 4px 10px rgba(0,0,0,0.3);
                transition: transform 0.2s, box-shadow 0.2s;
            }

            .session-item:active { cursor: grabbing; }
            .session-item:hover { transform: scale(1.02); z-index: 5; }

            .session-item.multiple { background: #10B981; } /* Green for multiple */
            .session-item.manual { background: #FFD700; } /* Yellow for manual */
            .session-item.special { background: #EF4444; color: #fff; } /* Red for blocked/special */

            .member-name {
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
                width: 100%;
            }

            .session-time-float {
                font-size: 9px;
                opacity: 0.7;
                margin-top: 2px;
            }

            .search-result-item:hover {
                background: rgba(255, 215, 0, 0.1) !important;
                color: #FFD700 !important;
            }

            .member-tag span:hover {
                color: #EF4444 !important;
            }
        </style>
    `;

    setupEventListeners();
    setupClassDetailModal();
    setUpdateCallback(updateView);
    setupCreateEventModal();
    await initializeTrainers();
}

function getMonday(d) {
    d = new Date(d);
    var day = d.getDay(),
        diff = d.getDate() - day + (day == 0 ? -6 : 1);
    const monday = new Date(d.setDate(diff));
    monday.setHours(0, 0, 0, 0);
    return monday;
}

function setupEventListeners() {
    // Navigation removed for fixed template
}

let createEventType = 'ders'; // 'ders' | 'etkinlik'

function localDateStr(date) {
    // Returns YYYY-MM-DD in LOCAL timezone (avoids UTC offset bug)
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function openCreateEventModal(dayIndex, hour) {
    const targetDate = new Date(currentWeekStart);
    targetDate.setDate(currentWeekStart.getDate() + dayIndex);
    const dateStr = localDateStr(targetDate); // ✅ local timezone fix

    // Pre-fill fields
    document.getElementById('create-event-date').value = dateStr;
    document.getElementById('create-event-start').value = `${String(hour).padStart(2, '0')}:00`;
    // 23:00 slot → bitiş gece yarısı (00:00 ertesi gün)
    const endHour = hour + 1;
    document.getElementById('create-event-end').value = endHour >= 24 ? '00:00' : `${String(endHour).padStart(2, '0')}:00`;
    document.getElementById('create-event-title').value = '';

    // Reset color
    document.querySelectorAll('.create-color-opt').forEach(opt => {
        opt.style.borderColor = 'transparent';
        opt.classList.remove('active');
    });
    const firstOpt = document.querySelector('.create-color-opt');
    if (firstOpt) { firstOpt.style.borderColor = '#fff'; firstOpt.classList.add('active'); }

    // Default to Ders mode
    setCreateType('ders');
    
    // Clear previous member selection
    selectedMembersForCreate = [];
    renderSelectedMemberTags();

    document.getElementById('create-event-modal').classList.add('active');
}

function renderSelectedMemberTags() {
    const container = document.getElementById('selected-members-tags');
    if (!container) return;
    container.innerHTML = selectedMembersForCreate.map(m => `
        <div class="member-tag" style="background: rgba(255, 215, 0, 0.2); color: #FFD700; padding: 4px 10px; border-radius: 20px; font-size: 13px; font-weight: 600; display: flex; align-items: center; gap: 6px; border: 1px solid rgba(255, 215, 0, 0.3);">
            ${m.name}
            <span onclick="removeMemberFromCreate('${m.id}')" style="cursor: pointer; opacity: 0.7;">&times;</span>
        </div>
    `).join('');
}

window.removeMemberFromCreate = function(id) {
    selectedMembersForCreate = selectedMembersForCreate.filter(m => m.id !== id);
    renderSelectedMemberTags();
};

window.setCreateType = function(type) {
    createEventType = type;
    const dersBtnStyle = type === 'ders' ? 'background:#FFD700;color:#000;' : 'background:transparent;color:#888;';
    const etkinlikBtnStyle = type === 'etkinlik' ? 'background:#FFD700;color:#000;' : 'background:transparent;color:#888;';
    document.getElementById('type-btn-ders').style.cssText += dersBtnStyle;
    document.getElementById('type-btn-etkinlik').style.cssText += etkinlikBtnStyle;
    document.getElementById('create-member-section').style.display = type === 'ders' ? 'block' : 'none';
    document.getElementById('create-title-section').style.display = type === 'etkinlik' ? 'block' : 'none';
    if (type === 'etkinlik') {
        setTimeout(() => document.getElementById('create-event-title').focus(), 50);
    }
};

async function setupMemberSearch() {
    const input = document.getElementById('member-search-input');
    const results = document.getElementById('member-search-results');
    if (!input || !results) return;

    // Load ALL members once for local filtering (simple approach) or search on type
    const { data: { user } } = await supabaseClient.auth.getUser();
    const { data: profile } = await supabaseClient.from('profiles').select('organization_id').eq('id', user.id).single();
    if (!profile?.organization_id) return;

    const { data: allMembers } = await supabaseClient
        .from('members')
        .select('id, name')
        .eq('organization_id', profile.organization_id)
        .eq('is_active', true)
        .order('name');

    const members = allMembers || [];

    input.oninput = (e) => {
        const val = e.target.value.trim().toLocaleLowerCase('tr');
        if (!val) {
            results.style.display = 'none';
            return;
        }

        const filtered = members.filter(m => 
            m.name.toLocaleLowerCase('tr').includes(val) && 
            !selectedMembersForCreate.find(s => s.id === m.id)
        );

        if (filtered.length > 0) {
            results.innerHTML = filtered.map(m => `
                <div class="search-result-item" 
                    style="padding: 10px 15px; cursor: pointer; border-bottom: 1px solid rgba(255,255,255,0.05); color: #fff;"
                    onclick="addMemberToCreate('${m.id}', '${m.name.replace(/'/g, "\\'")}')">
                    ${m.name}
                </div>
            `).join('');
            results.style.display = 'block';
        } else {
            results.innerHTML = '<div style="padding: 10px 15px; color: #666;">Üye bulunamadı</div>';
            results.style.display = 'block';
        }
    };

    window.addMemberToCreate = (id, name) => {
        if (!selectedMembersForCreate.find(m => m.id === id)) {
            selectedMembersForCreate.push({ id, name });
            renderSelectedMemberTags();
        }
        input.value = '';
        results.style.display = 'none';
    };

    // Global click listener to close dropdown
    document.addEventListener('click', (e) => {
        if (!input.contains(e.target) && !results.contains(e.target)) {
            results.style.display = 'none';
        }
    });
}

function setupCreateEventModal() {
    document.getElementById('close-create-event-modal').onclick = () => {
        document.getElementById('create-event-modal').classList.remove('active');
    };

    document.querySelectorAll('.create-color-opt').forEach(opt => {
        opt.onclick = () => {
            document.querySelectorAll('.create-color-opt').forEach(o => {
                o.classList.remove('active');
                o.style.borderColor = 'transparent';
            });
            opt.classList.add('active');
            opt.style.borderColor = '#fff';
        };
    });

    document.getElementById('save-create-event-btn').onclick = saveNewEvent;

    // Setup member search
    setupMemberSearch();
}

async function saveNewEvent() {
    const dateStr = document.getElementById('create-event-date').value;
    const startStr = document.getElementById('create-event-start').value;
    const endStr = document.getElementById('create-event-end').value;
    const color = document.querySelector('.create-color-opt.active')?.dataset.color || '#06B6D4';

    if (!dateStr || !startStr || !endStr) { showToast('Tarih ve saat zorunlu', 'error'); return; }

    const startDateTime = new Date(`${dateStr}T${startStr}`);
    let endDateTime = new Date(`${dateStr}T${endStr}`);
    // Midnight wrap: if end <= start, it means next day (e.g. 23:00 → 00:00)
    if (endDateTime <= startDateTime) {
        endDateTime.setDate(endDateTime.getDate() + 1);
    }

    let title;

    if (createEventType === 'ders') {
        if (selectedMembersForCreate.length === 0) { showToast('Lütfen en az bir üye seçin', 'error'); return; }
        title = selectedMembersForCreate.map(m => m.name).join(' - '); // Joined names
    } else {
        title = document.getElementById('create-event-title').value.trim();
        if (!title) { showToast('Lütfen bir etkinlik adı girin', 'error'); return; }
    }

    const btn = document.getElementById('save-create-event-btn');
    btn.textContent = 'Kaydediliyor...';
    btn.disabled = true;

    try {
        // 1. Create class_session AS TEMPLATE
        const { data: newSession, error: sessionError } = await supabaseClient
            .from('class_sessions')
            .insert({
                title,
                start_time: startDateTime.toISOString(),
                end_time: endDateTime.toISOString(),
                trainer_id: selectedTrainerId,
                color,
                status: 'scheduled',
                is_template: true
            })
            .select()
            .single();

        if (sessionError) throw sessionError;

        // 2. If Ders: create enrollments for the template
        if (createEventType === 'ders' && selectedMembersForCreate.length > 0) {
            const templateEnrollments = selectedMembersForCreate.map(m => ({
                class_id: newSession.id,
                member_id: m.id,
                status: 'booked'
            }));
            const { error: tempEnrollError } = await supabaseClient
                .from('class_enrollments')
                .insert(templateEnrollments);
            if (tempEnrollError) throw tempEnrollError;
        }

        // 3. GENERATE 52 WEEKS OF FUTURE EVENTS
        const targetDay = startDateTime.getDay(); // 0(Sun) - 6(Sat)
        const generatedSessions = [];
        
        let currentDate = new Date();
        currentDate.setHours(0,0,0,0);
        // Find the *next* occurrence of targetDay from today
        while (currentDate.getDay() !== targetDay) {
            currentDate.setDate(currentDate.getDate() + 1);
        }

        for (let i = 0; i < 52; i++) {
            const iterStartDate = new Date(currentDate);
            iterStartDate.setDate(iterStartDate.getDate() + (i * 7));
            iterStartDate.setHours(startDateTime.getHours(), startDateTime.getMinutes(), 0, 0);
            
            const iterEndDate = new Date(iterStartDate);
            // use original duration
            const diffMs = endDateTime.getTime() - startDateTime.getTime();
            iterEndDate.setTime(iterStartDate.getTime() + diffMs);

            generatedSessions.push({
                title,
                start_time: iterStartDate.toISOString(),
                end_time: iterEndDate.toISOString(),
                trainer_id: selectedTrainerId,
                color,
                status: 'scheduled',
                is_template: false,
                template_id: newSession.id
            });
        }

        const { data: insertedGeneratedSessions, error: genError } = await supabaseClient
            .from('class_sessions')
            .insert(generatedSessions)
            .select();

        if (genError) throw genError;

        // 4. Enrollments for all generated sessions
        if (createEventType === 'ders' && selectedMembersForCreate.length > 0) {
            let allFutureEnrollments = [];
            insertedGeneratedSessions.forEach(sess => {
                selectedMembersForCreate.forEach(m => {
                    allFutureEnrollments.push({
                        class_id: sess.id,
                        member_id: m.id,
                        status: 'booked'
                    });
                });
            });

            // supabase has a limit on bulk inserts (usually 1000 or similar), 52 * members shouldn't exceed it unless members > 19
            const { error: genEnrollError } = await supabaseClient
                .from('class_enrollments')
                .insert(allFutureEnrollments);
                
            if (genEnrollError) throw genEnrollError;
        }

        showToast(createEventType === 'ders' ? 'Ders eklendi ✅' : 'Etkinlik eklendi ✅', 'success');
        document.getElementById('create-event-modal').classList.remove('active');
        await updateView();
    } catch (err) {
        showToast('Kaydedilemedi: ' + err.message, 'error');
    } finally {
        btn.textContent = 'Kaydet';
        btn.disabled = false;
    }
}

async function initializeTrainers() {
    const tabsContainer = document.getElementById('trainer-tabs');
    
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
            .in('role', ['trainer', 'owner']);

        if (error) throw error;

        // Custom sort: Owners first, then by name
        trainersCache = (trainers || []).sort((a, b) => {
            if (a.role === 'owner' && b.role !== 'owner') return -1;
            if (a.role !== 'owner' && b.role === 'owner') return 1;
            return a.first_name.localeCompare(b.first_name);
        });
        
        if (trainersCache.length > 0) {
            selectedTrainerId = trainersCache[0].id;
            renderTrainerTabs();
            await updateView();
        } else {
            tabsContainer.innerHTML = '<div class="tab">Hoca Bulunamadı</div>';
        }

    } catch (err) {
        console.error('Trainers init error:', err);
        tabsContainer.innerHTML = '<div class="tab error">Hata oluştu</div>';
    }
}

function renderTrainerTabs() {
    const tabsContainer = document.getElementById('trainer-tabs');
    tabsContainer.innerHTML = trainersCache.map(trainer => `
        <div class="trainer-tab ${selectedTrainerId === trainer.id ? 'active' : ''}" 
             onclick="window.selectTrainer('${trainer.id}')">
            ${trainer.first_name} ${trainer.last_name || ''}
            ${trainer.role === 'owner' ? '<span style="font-size: 9px; opacity: 0.7; margin-left: 4px; vertical-align: middle;">(Yönetici)</span>' : ''}
        </div>
    `).join('');
}

window.selectTrainer = async (id) => {
    selectedTrainerId = id;
    renderTrainerTabs();
    await updateView();
};

async function updateView() {
    updateWeekLabel();
    await fetchSessions();
    renderGrid();
}

function updateWeekLabel() {
    document.getElementById('week-label').textContent = "Sabit Haftalık Taslak";
}

async function fetchSessions() {
    const start = currentWeekStart.toISOString();
    const end = new Date(currentWeekStart);
    end.setDate(currentWeekStart.getDate() + 7);
    const endStr = end.toISOString();

    // Build date strings for the week  (YYYY-MM-DD)
    const weekDates = [];
    for (let i = 0; i < 7; i++) {
        const d = new Date(currentWeekStart);
        d.setDate(currentWeekStart.getDate() + i);
        weekDates.push(d.toISOString().split('T')[0]);
    }

    try {
        const [sessionsResult, closedResult] = await Promise.all([
            supabaseClient
                .from('class_sessions')
                .select(`*, class_enrollments(id, member:member_id(id, name))`)
                .eq('trainer_id', selectedTrainerId)
                .eq('is_template', true)
                .neq('status', 'cancelled'),
            supabaseClient
                .from('closed_days')
                .select('date')
                .eq('trainer_id', selectedTrainerId)
                .in('date', weekDates)
        ]);

        if (sessionsResult.error) throw sessionsResult.error;
        sessionsCache = sessionsResult.data || [];
        closedDaysCache = (closedResult.data || []).map(r => r.date);
    } catch (err) {
        console.error('Fetch sessions error:', err);
        showToast('Veriler yüklenemedi', 'error');
    }
}

async function toggleClosedDay(dateStr, isCurrentlyClosed) {
    if (!selectedTrainerId) return;

    if (isCurrentlyClosed) {
        // Re-open: delete from closed_days
        const { error } = await supabaseClient
            .from('closed_days')
            .delete()
            .eq('trainer_id', selectedTrainerId)
            .eq('date', dateStr);
        if (error) { showToast('İşlem başarısız', 'error'); return; }
        showToast('Gün açıldı ✅', 'success');
    } else {
        // Close: insert into closed_days
        const { error } = await supabaseClient
            .from('closed_days')
            .insert({ trainer_id: selectedTrainerId, date: dateStr });
        if (error) { showToast('İşlem başarısız', 'error'); return; }
        showToast('Gün kapalı olarak işaretlendi 🔒', 'success');
    }

    await updateView();
}

async function blockSlot(dayIndex, hour) {
    if (!selectedTrainerId) return;

    const startDateTime = new Date(currentWeekStart);
    startDateTime.setDate(startDateTime.getDate() + dayIndex);
    startDateTime.setHours(hour, 0, 0, 0);

    const endDateTime = new Date(startDateTime);
    endDateTime.setHours(hour + 1, 0, 0, 0);

    try {
        const { data: newSession, error: sessionError } = await supabaseClient
            .from('class_sessions')
            .insert({
                title: 'Kapalı Slot',
                start_time: startDateTime.toISOString(),
                end_time: endDateTime.toISOString(),
                trainer_id: selectedTrainerId,
                color: '#4B5563', // gray
                status: 'scheduled', 
                is_template: true
            })
            .select()
            .single();

        if (sessionError) throw sessionError;

        const targetDay = startDateTime.getDay();
        const generatedSessions = [];
        
        let currentDate = new Date();
        currentDate.setHours(0,0,0,0);
        while (currentDate.getDay() !== targetDay) {
            currentDate.setDate(currentDate.getDate() + 1);
        }

        for (let i = 0; i < 52; i++) {
            const iterStartDate = new Date(currentDate);
            iterStartDate.setDate(iterStartDate.getDate() + (i * 7));
            iterStartDate.setHours(startDateTime.getHours(), startDateTime.getMinutes(), 0, 0);
            
            const iterEndDate = new Date(iterStartDate);
            iterEndDate.setHours(hour + 1, 0, 0, 0);

            generatedSessions.push({
                title: 'Kapalı Slot',
                start_time: iterStartDate.toISOString(),
                end_time: iterEndDate.toISOString(),
                trainer_id: selectedTrainerId,
                color: '#4B5563',
                status: 'scheduled',
                is_template: false,
                template_id: newSession.id
            });
        }

        const { error: genError } = await supabaseClient
            .from('class_sessions')
            .insert(generatedSessions);

        if (genError) throw genError;

        showToast('Saat kapalı olarak işaretlendi 🔒', 'success');
        await updateView();
    } catch (err) {
        showToast('Saat kapatılamadı: ' + err.message, 'error');
    }
}

function renderGrid() {
    const grid = document.getElementById('schedule-grid');
    if (!grid) return;
    grid.innerHTML = '';

    // 1. Header Row
    grid.appendChild(createCell('', 'grid-header-cell')); // Hour column header

    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    for (let i = 0; i < 7; i++) {
        const dayDate = new Date(currentWeekStart);
        dayDate.setDate(currentWeekStart.getDate() + i);
        const dateStr = dayDate.toISOString().split('T')[0];
        const isClosed = closedDaysCache.includes(dateStr);
        
        const headerCell = document.createElement('div');
        headerCell.className = 'grid-header-cell';
        headerCell.style.cursor = 'pointer';
        headerCell.title = isClosed ? 'Günü Aç' : 'Kapalı gün ata';
        headerCell.innerHTML = `
            <div class="day-name" style="color: ${isClosed ? '#EF4444' : ''}; font-size: 16px; margin-top: 8px;">${days[i]}${isClosed ? ' 🔒' : ''}</div>
        `;
        headerCell.addEventListener('click', () => toggleClosedDay(dateStr, isClosed));
        grid.appendChild(headerCell);
    }

    // 2. Hour Rows (07:00 - 22:00)
    for (let hour = 7; hour <= 23; hour++) {
        // Time Axis
        const timeCell = document.createElement('div');
        timeCell.className = 'time-axis-cell';
        timeCell.textContent = `${hour}:00`;
        grid.appendChild(timeCell);

        // Day Columns for this hour
        for (let dayIndex = 0; dayIndex < 7; dayIndex++) {
            const dayDate = new Date(currentWeekStart);
            dayDate.setDate(currentWeekStart.getDate() + dayIndex);
            const dateStr = dayDate.toISOString().split('T')[0];
            const isClosed = closedDaysCache.includes(dateStr);

            const cell = document.createElement('div');
            cell.className = 'grid-cell';
            cell.dataset.day = dayIndex;
            cell.dataset.hour = hour;

            if (isClosed) {
                // Closed day: show KAPALI
                cell.style.background = 'rgba(239,68,68,0.12)';
                cell.style.borderLeft = '2px solid rgba(239,68,68,0.3)';
                cell.innerHTML = `<div style="color: #EF4444; font-size: 10px; font-weight: 700; text-align: center; opacity: 0.8;">KAPALI</div>`;
                cell.style.cursor = 'default';
            } else {
                // Find session in this slot
                const session = sessionsCache.find(s => {
                    const sDate = new Date(s.start_time);
                    return sDate.getHours() === hour && isSameDay(sDate, dayIndex);
                });

                if (session) {
                    cell.appendChild(createSessionElement(session));
                } else {
                    // Empty cell: click to create new event, right click to block
                    cell.addEventListener('click', () => {
                        openCreateEventModal(dayIndex, hour);
                    });
                    cell.addEventListener('contextmenu', async (e) => {
                        e.preventDefault();
                        if (confirm('Bu saati kapatmak (bloklamak) istiyor musunuz?')) {
                            await blockSlot(dayIndex, hour);
                        }
                    });
                    cell.style.cursor = 'pointer';
                    cell.title = 'Sol Tık: Etkinlik Ekle | Sağ Tık: Saati Kapat';
                }
            }

            // Drag events
            cell.addEventListener('dragover', (e) => {
                e.preventDefault();
                cell.classList.add('drag-over');
            });

            cell.addEventListener('dragleave', () => {
                cell.classList.remove('drag-over');
            });

            cell.addEventListener('drop', async (e) => {
                e.preventDefault();
                cell.classList.remove('drag-over');
                const sessionId = e.dataTransfer.getData('sessionId');
                if (sessionId) {
                    await handleSessionMove(sessionId, dayIndex, hour);
                }
            });

            grid.appendChild(cell);
        }
    }
}

function createCell(content, className) {
    const div = document.createElement('div');
    if (className) div.className = className;
    div.innerHTML = content;
    return div;
}

function isSameDay(date, dayIndexOffset) {
    const targetDate = new Date(currentWeekStart);
    targetDate.setDate(targetWeekDate(dayIndexOffset));
    return date.getDate() === targetDate.getDate() && 
           date.getMonth() === targetDate.getMonth() &&
           date.getFullYear() === targetDate.getFullYear();
}

function targetWeekDate(offset) {
    const d = new Date(currentWeekStart);
    d.setDate(currentWeekStart.getDate() + offset);
    return d.getDate();
}

function createSessionElement(session) {
    const div = document.createElement('div');
    div.className = 'session-item';
    div.draggable = true;
    
    const enrollments = session.class_enrollments || [];
    const memberNames = enrollments.length > 0 
        ? enrollments.map(e => e.member?.name || 'Üye').join(' - ')
        : (session.title || 'Ders');

    // Use custom color from DB or default
    const bgColor = session.color || '#06B6D4';
    div.style.background = bgColor;
    
    // Contrast check for text color (simple)
    const isLight = ['#FFD700', 'yellow', '#10B981'].includes(bgColor.toUpperCase()) || bgColor === '#FFD700';
    div.style.color = isLight ? '#000' : '#fff';

    div.innerHTML = `
        <div class="member-name" style="font-size: 11px; line-height: 1.1; max-height: 100%; overflow: hidden;" title="${memberNames}">${memberNames}</div>
    `;

    div.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('sessionId', session.id);
        div.style.opacity = '0.5';
    });

    div.addEventListener('dragend', () => {
        div.style.opacity = '1';
    });

    // Edit on click?
    div.addEventListener('click', () => {
        openClassDetailModal(session.id);
    });

    return div;
}

async function handleSessionMove(sessionId, targetDayIndex, targetHour) {
    const targetDate = new Date(currentWeekStart);
    targetDate.setDate(currentWeekStart.getDate() + targetDayIndex);
    targetDate.setHours(targetHour, 0, 0, 0);

    const oldSession = sessionsCache.find(s => s.id === sessionId);
    if (!oldSession) return;

    // Calculate new end time based on duration
    const start = new Date(oldSession.start_time);
    const end = new Date(oldSession.end_time);
    const durationMs = end - start;
    const newEnd = new Date(targetDate.getTime() + durationMs);

    try {
        showToast('Taşınıyor...', 'info');
        
        const { error } = await supabaseClient
            .from('class_sessions')
            .update({
                start_time: targetDate.toISOString(),
                end_time: newEnd.toISOString()
            })
            .eq('id', sessionId);

        if (error) throw error;

        showToast('Randevu başarıyla taşındı', 'success');
        await updateView();

    } catch (err) {
        console.error('Move error:', err);
        showToast('Randevu taşınamadı', 'error');
    }
}

function formatTime(isoString) {
    const d = new Date(isoString);
    return `${d.getHours().toString().padLeft(2, '0')}:${d.getMinutes().toString().padLeft(2, '0')}`;
}

// Helper for padding
if (!String.prototype.padLeft) {
    String.prototype.padLeft = function(length, character) {
        return this.padStart(length, character);
    };
}
