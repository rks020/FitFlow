import { supabaseClient } from '../supabase-config.js';
import { showToast, formatDate, turkishToLower } from '../utils.js';

let currentWeekStart = getMonday(new Date());
let selectedTrainerId = null;
let trainersCache = [];
let sessionsCache = [];

export async function loadWeeklySchedule() {
    const contentArea = document.getElementById('content-area');
    
    // Disable outer scrolling for this module to fit everything on screen
    contentArea.style.overflow = 'hidden';
    contentArea.style.height = 'calc(100vh - 84px)'; // Account for content-header

    contentArea.innerHTML = `
        <div class="weekly-schedule-container">
            <div class="schedule-controls">
                <div class="trainer-tabs" id="trainer-tabs">
                    <div class="tab loading">Hocalar yükleniyor...</div>
                </div>
                <div class="week-nav">
                    <button id="prev-week" class="nav-btn" title="Geri"><span>❮</span></button>
                    <div id="week-label" class="week-label">Yükleniyor...</div>
                    <button id="next-week" class="nav-btn" title="İleri"><span>❯</span></button>
                    <button id="today-btn" class="nav-btn-today">Bugün</button>
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
                overflow-y: hidden;
                background: #1C1C1E;
                border-radius: 20px;
                border: 1px solid rgba(255, 255, 255, 0.08);
                position: relative;
                min-height: 0;
            }

            .schedule-grid {
                display: grid;
                grid-template-columns: 70px repeat(7, 1fr);
                grid-template-rows: auto repeat(16, 1fr); /* Header + 16 hour slots (07:00-22:00) */
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
        </style>
    `;

    setupEventListeners();
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
    document.getElementById('prev-week').addEventListener('click', () => {
        currentWeekStart.setDate(currentWeekStart.getDate() - 7);
        updateView();
    });

    document.getElementById('next-week').addEventListener('click', () => {
        currentWeekStart.setDate(currentWeekStart.getDate() + 7);
        updateView();
    });

    document.getElementById('today-btn').addEventListener('click', () => {
        currentWeekStart = getMonday(new Date());
        updateView();
    });
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
            .in('role', ['trainer', 'owner'])
            .order('first_name');

        if (error) throw error;

        trainersCache = trainers || [];
        
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
    const endOfWeek = new Date(currentWeekStart);
    endOfWeek.setDate(currentWeekStart.getDate() + 6);
    
    const options = { month: 'long', day: 'numeric' };
    const label = `${currentWeekStart.toLocaleDateString('tr-TR', options)} - ${endOfWeek.toLocaleDateString('tr-TR', options)}`;
    document.getElementById('week-label').textContent = label;
}

async function fetchSessions() {
    const start = currentWeekStart.toISOString();
    const end = new Date(currentWeekStart);
    end.setDate(currentWeekStart.getDate() + 7);
    const endStr = end.toISOString();

    try {
        const { data, error } = await supabaseClient
            .from('class_sessions')
            .select(`
                *,
                class_enrollments(
                    id,
                    member:member_id(id, name)
                )
            `)
            .eq('trainer_id', selectedTrainerId)
            .gte('start_time', start)
            .lt('start_time', endStr)
            .neq('status', 'cancelled');

        if (error) throw error;
        sessionsCache = data || [];
    } catch (err) {
        console.error('Fetch sessions error:', err);
        showToast('Veriler yüklenemedi', 'error');
    }
}

function renderGrid() {
    const grid = document.getElementById('schedule-grid');
    grid.innerHTML = '';

    // 1. Header Row
    grid.appendChild(createCell('', 'grid-header-cell')); // Hour column header

    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    for (let i = 0; i < 7; i++) {
        const dayDate = new Date(currentWeekStart);
        dayDate.setDate(currentWeekStart.getDate() + i);
        
        const headerCell = document.createElement('div');
        headerCell.className = 'grid-header-cell';
        headerCell.innerHTML = `
            <div class="day-name">${days[i]}</div>
            <div class="day-date">${dayDate.getDate()} ${dayDate.toLocaleDateString('tr-TR', { month: 'short' })}</div>
        `;
        grid.appendChild(headerCell);
    }

    // 2. Hour Rows (07:00 - 22:00)
    for (let hour = 7; hour <= 22; hour++) {
        // Time Axis
        const timeCell = document.createElement('div');
        timeCell.className = 'time-axis-cell';
        timeCell.textContent = `${hour}:00`;
        grid.appendChild(timeCell);

        // Day Columns for this hour
        for (let dayIndex = 0; dayIndex < 7; dayIndex++) {
            const cell = document.createElement('div');
            cell.className = 'grid-cell';
            cell.dataset.day = dayIndex;
            cell.dataset.hour = hour;

            // Find session in this slot
            const session = sessionsCache.find(s => {
                const sDate = new Date(s.start_time);
                return sDate.getHours() === hour && 
                       isSameDay(sDate, dayIndex);
            });

            if (session) {
                cell.appendChild(createSessionElement(session));
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
    
    // Determine Color Category
    const enrollments = session.class_enrollments || [];
    if (session.title?.toLowerCase().includes('maç') || session.title?.toLowerCase().includes('kapalı')) {
        div.classList.add('special');
    } else if (enrollments.length > 1) {
        div.classList.add('multiple');
    } else if (session.is_public) {
        div.classList.add('manual');
    }

    const memberNames = enrollments.length > 0 
        ? enrollments.map(e => e.member?.name || 'Üye').join(' - ')
        : (session.title || 'Ders');

    div.innerHTML = `
        <div class="member-name" title="${memberNames}">${memberNames}</div>
        <div class="session-time-float">${formatTime(session.start_time)}</div>
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
        if (window.openClassDetailModal) {
            window.openClassDetailModal(session.id);
        }
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
