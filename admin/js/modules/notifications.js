import { supabaseClient } from '../supabase-config.js';

export async function initNotifications() {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) return;
        
        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id, role')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;
        
        // Use user-specific key for persistence
        const storageKey = `fitflow_seen_low_session_ids_${user.id}`;

        let query = supabaseClient
            .from('members')
            .select('id, name, session_count, is_multisport, is_meditopia')
            .eq('organization_id', profile.organization_id)
            .eq('is_active', true)
            .eq('is_multisport', false)
            .eq('is_meditopia', false)
            .lte('session_count', 2)
            .order('session_count', { ascending: true }); // 0 comes first

        if (profile.role === 'trainer') {
            query = query.or(`trainer_id.eq.${user.id},is_meditopia.eq.true`);
        }

        const { data: lowSessionMembers, error } = await query;
        if (error) throw error;

        console.log(`[Notifications] Found ${lowSessionMembers?.length || 0} low session members`);
        updateNotificationUI(lowSessionMembers || [], storageKey);

    } catch (e) {
        console.error('[Notifications] Error loading notifications:', e);
    }
}

function updateNotificationUI(members, storageKey) {
    const badge = document.getElementById('notification-badge');
    const list = document.getElementById('notification-list');
    
    if (!badge || !list) return;

    window.currentNotificationStorageKey = storageKey;
    window.currentNotificationMemberIds = members.map(m => String(m.id));
    
    let seenIds = [];
    try {
        seenIds = JSON.parse(localStorage.getItem(storageKey) || '[]');
        if (!Array.isArray(seenIds)) seenIds = [];
    } catch (e) {
        seenIds = [];
    }
    
    const unreadMembers = members.filter(m => !seenIds.includes(String(m.id)));
    const unreadCount = unreadMembers.length;

    console.log(`[Notifications] Unread count: ${unreadCount}, Seen count: ${seenIds.length}`);

    if (unreadCount > 0) {
        badge.style.display = 'flex';
        badge.textContent = unreadCount > 99 ? '99+' : unreadCount;
    } else {
        badge.style.display = 'none';
        badge.textContent = '0';
    }

    if (members.length === 0) {
        list.innerHTML = `<div style="padding: 20px; text-align: center; color: #888; font-size: 13px;">Tüm üyelerinizin yeterli dersi var.</div>`;
    } else {
        list.innerHTML = members.map(m => {
            let color = '#EF4444'; // Red
            let icon = '❌';
            let msg = 'Dersi kalmadı!';
            
            if (m.session_count === 1) {
                color = '#F59E0B'; // Orange
                icon = '⚠️';
                msg = 'Sadece 1 dersi kaldı';
            } else if (m.session_count === 2) {
                color = '#FFD700'; // Yellow
                icon = '🔔';
                msg = 'Sadece 2 dersi kaldı';
            }
            
            return `
                <div class="notification-item" onclick="window.viewMemberDetail('${m.id}')" style="padding: 12px 16px; border-bottom: 1px solid rgba(255,255,255,0.05); cursor: pointer; display: flex; align-items: flex-start; gap: 12px; transition: background 0.2s;">
                    <div style="background: rgba(255,255,255,0.05); border-radius: 50%; width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; font-size: 16px; flex-shrink: 0;">
                        ${icon}
                    </div>
                    <div style="flex: 1;">
                        <div style="font-size: 13px; font-weight: 600; color: #fff; margin-bottom: 3px;">${m.name}</div>
                        <div style="font-size: 12px; color: ${color}; font-weight: 600;">${msg}</div>
                    </div>
                </div>
            `;
        }).join('');
    }
}

export function setupNotificationListeners() {
    const btn = document.getElementById('notification-btn');
    const dropdown = document.getElementById('notification-dropdown');

    if (btn && dropdown) {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const isOpening = dropdown.style.display === 'none' || dropdown.style.display === '';
            dropdown.style.display = isOpening ? 'block' : 'none';
            
            if (isOpening) {
                if (window.currentNotificationMemberIds && window.currentNotificationMemberIds.length > 0 && window.currentNotificationStorageKey) {
                    try {
                        const storageKey = window.currentNotificationStorageKey;
                        let seenIds = JSON.parse(localStorage.getItem(storageKey) || '[]');
                        if (!Array.isArray(seenIds)) seenIds = [];
                        
                        const updatedSeenIds = Array.from(new Set([...seenIds, ...window.currentNotificationMemberIds]));
                        localStorage.setItem(storageKey, JSON.stringify(updatedSeenIds));
                        console.log(`[Notifications] Marked ${window.currentNotificationMemberIds.length} notifications as seen for key ${storageKey}`);
                    } catch (e) {
                        console.error('[Notifications] Error updating seen IDs:', e);
                    }
                }
                const badge = document.getElementById('notification-badge');
                if (badge) badge.style.display = 'none';
            }
        });

        // Outside click to close
        document.addEventListener('click', (e) => {
            if (!dropdown.contains(e.target) && e.target !== btn && !btn.contains(e.target)) {
                dropdown.style.display = 'none';
            }
        });
        
        // CSS hover rules
        if (!document.getElementById('notification-styles')) {
            const style = document.createElement('style');
            style.id = 'notification-styles';
            style.textContent = `
                .notification-item:hover {
                    background: rgba(255, 255, 255, 0.05) !important;
                }
            `;
            document.head.appendChild(style);
        }
    }
}
