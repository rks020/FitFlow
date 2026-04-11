import { initAuth, logout } from './auth.js';
import { loadDashboard } from './modules/dashboard.js';
import { loadTrainers } from './modules/trainers.js';
import { loadMembers } from './modules/members.js';
import { loadClasses } from './modules/classes.js';
import { loadAnnouncements } from './modules/announcements.js';
import { loadProfile } from './modules/profile.js';
import { loadFinance } from './modules/finance.js';
import { loadWorkouts } from './modules/workouts.js';
import { loadWeeklySchedule } from './modules/schedule-grid.js';
import { initNotifications, setupNotificationListeners } from './modules/notifications.js';

// Page Mappings
const pageLoaders = {
    'dashboard': loadDashboard,
    'trainers': loadTrainers,
    'members': loadMembers,
    'classes': loadClasses,
    'announcements': loadAnnouncements,
    'finance': loadFinance,
    'workouts': loadWorkouts,
    'weekly-schedule': loadWeeklySchedule,
    'profile': loadProfile
};

// ... (init and nav setup omitted for brevity in replace helper, focus on changed parts if possible or replace block)
// Need to match lines for clean replace. Let's do huge block or targeted chunks.
// Targeted chunk for imports

// Initialize App
function init() {
    // Initialize authentication
    initAuth();

    // Setup navigation
    setupNavigation();

    // Setup logout
    document.getElementById('logout-btn')?.addEventListener('click', logout);

    // Handle hash navigation
    window.addEventListener('hashchange', handleNavigation);

    // Check initial hash
    handleNavigation();

    // Hook notifications logic
    setupNotificationListeners();
    initNotifications();
}

// Handle race condition: check if DOM is already loaded
// Module scripts are deferred by default, so DOMContentLoaded might have already fired
if (document.readyState === 'loading') {
    window.addEventListener('DOMContentLoaded', init);
} else {
    // DOM is already loaded, initialize immediately
    init();
}

// Setup Navigation
function setupNavigation() {
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const page = item.getAttribute('data-page');
            navigateTo(page);
        });
    });
}

// Navigate to Page
function navigateTo(page, query = '') {
    // Update active nav item
    document.querySelectorAll('.nav-item').forEach(item => {
        if (item.getAttribute('data-page') === page) {
            item.classList.add('active');
        } else {
            item.classList.remove('active');
        }
    });

    // Update page title
    const titles = {
        'dashboard': 'Dashboard',
        'trainers': 'Antrenörler',
        'members': 'Üyeler',
        'classes': 'Ders Programı',
        'announcements': 'Duyurular',
        'finance': 'Finans & Ödemeler',
        'workouts': 'Antrenman Yönetimi',
        'weekly-schedule': 'Randevu Listesi',
        'profile': 'Profil'
    };
    document.getElementById('page-title').textContent = titles[page] || 'Dashboard';

    // Load page content
    if (pageLoaders[page]) {
        // Clear content area first and reset any styles (like those from schedule-grid)
        const contentArea = document.getElementById('content-area');
        if (contentArea) {
            contentArea.innerHTML = '<div style="padding: 20px; text-align: center;">Yükleniyor...</div>';
            contentArea.style.overflow = '';
            contentArea.style.height = '';
        }

        pageLoaders[page]();
    }

    // Update URL hash WITHOUT triggering a loop if possible, or just ensure consistency
    const targetHash = query ? `${page}?${query}` : page;
    if (window.location.hash.slice(1) !== targetHash) {
        window.location.hash = targetHash;
    }
}

// Handle hash navigation
function handleNavigation() {
    const hash = window.location.hash.slice(1) || 'dashboard';
    const [page, query] = hash.split('?');

    console.log('Navigating to:', page, 'Query:', query);
    
    // Store query globally for modules to access
    window.currentQuery = query;

    if (pageLoaders[page]) {
        navigateTo(page, query);
    } else {
        console.warn('No loader found for page:', page);
        navigateTo('dashboard');
    }
}

// Export navigate function for use in modules
export { navigateTo };
