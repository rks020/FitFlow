import { supabaseClient } from '../supabase-config.js';
import { showToast } from '../utils.js';
import { initNotifications } from './notifications.js';

let currentFinanceTab = 'payments'; // 'payments' | 'upcoming'

export async function loadFinance() {
    const contentArea = document.getElementById('content-area');

    // Check if query requests upcoming tab directly
    if (window.currentQuery === 'tab=upcoming') {
        currentFinanceTab = 'upcoming';
    } else if (!window.currentQuery) {
        currentFinanceTab = 'payments';
    }

    contentArea.innerHTML = `
        <div class="module-header" style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
            <h2>Finans & Ödemeler</h2>
            <div style="display: flex; align-items: center; gap: 12px;">
                <div style="display: flex; background: #222; padding: 4px; border-radius: 10px; border: 1px solid #444; gap: 4px;">
                    <button id="tab-btn-payments" onclick="switchFinanceTab('payments')" style="padding: 8px 16px; border-radius: 8px; border: none; cursor: pointer; font-weight: bold; font-size: 13px; display: flex; align-items: center; gap: 6px; transition: all 0.2s;">
                        <span>💳</span> Ödemeler
                    </button>
                    <button id="tab-btn-upcoming" onclick="switchFinanceTab('upcoming')" style="padding: 8px 16px; border-radius: 8px; border: none; cursor: pointer; font-weight: bold; font-size: 13px; display: flex; align-items: center; gap: 6px; transition: all 0.2s;">
                        <span>⏳</span> Ödemesi Yaklaşanlar
                        <span id="upcoming-count-badge" style="display: none; background: #EF4444; color: #fff; font-size: 11px; padding: 1px 6px; border-radius: 10px; font-weight: 800;">0</span>
                    </button>
                </div>
                <button id="export-excel-btn" onclick="exportFinanceToExcel()" class="btn" style="background: #10B981; color: white; border: none; padding: 10px 15px; border-radius: 8px; cursor: pointer; font-weight: bold; display: flex; align-items: center; gap: 8px;">
                    <span>📊</span> Excel'e Aktar
                </button>
            </div>
        </div>

        <!-- TAB 1: PAYMENTS VIEW -->
        <div id="finance-payments-view">
            <div class="filters-row" style="display: flex; gap: 20px; margin-bottom: 20px; align-items: flex-end;">
                <div style="display: flex; flex-direction: column; gap: 8px; flex: 1;">
                    <label style="color: #FFD700; font-size: 13px; font-weight: bold; letter-spacing: 0.5px; text-transform: uppercase;">Yıl Seçimi</label>
                    <select id="finance-year" style="padding: 12px; border-radius: 8px; background: #222; color: #fff; border: 1px solid #444; outline: none; cursor: pointer; width: 100%; font-size: 15px;">
                        <option value="all">Tüm Zamanlar</option>
                    </select>
                </div>
                <div id="month-filter-group" style="display: flex; flex-direction: column; gap: 8px; flex: 1;">
                    <label style="color: #FFD700; font-size: 13px; font-weight: bold; letter-spacing: 0.5px; text-transform: uppercase;">Ay Seçimi</label>
                    <select id="finance-month" style="padding: 12px; border-radius: 8px; background: #222; color: #fff; border: 1px solid #444; outline: none; cursor: pointer; width: 100%; font-size: 15px;">
                        <option value="0">Ocak</option>
                        <option value="1">Şubat</option>
                        <option value="2">Mart</option>
                        <option value="3">Nisan</option>
                        <option value="4">Mayıs</option>
                        <option value="5">Haziran</option>
                        <option value="6">Temmuz</option>
                        <option value="7">Ağustos</option>
                        <option value="8">Eylül</option>
                        <option value="9">Ekim</option>
                        <option value="10">Kasım</option>
                        <option value="11">Aralık</option>
                    </select>
                </div>
            </div>

            <div class="stats-row" style="display: flex; gap: 20px; margin-bottom: 20px;">
                 <div class="stat-card" style="background: #333; padding: 20px; border-radius: 10px; flex: 1;">
                    <h3 style="margin: 0; color: #888; font-size: 14px;">Son İşlem</h3>
                    <p id="last-payment" style="margin: 10px 0 0 0; font-size: 18px; color: #fff;">-</p>
                </div>
            </div>

            <div class="table-container" style="overflow-x: auto; background: #222; border-radius: 10px; padding: 10px;">
                <table style="width: 100%; border-collapse: collapse; color: #eee;">
                    <thead>
                        <tr style="border-bottom: 1px solid #444; text-align: left;">
                            <th style="padding: 12px;">Tarih</th>
                            <th style="padding: 12px;">Üye</th>
                            <th style="padding: 12px;">Kategori</th>
                            <th style="padding: 12px;">Yöntem</th>
                            <th style="padding: 12px;">Tutar</th>
                             <th style="padding: 12px;">Not</th>
                             <th style="padding: 12px; text-align: right;">İşlemler</th>
                        </tr>
                    </thead>
                    <tbody id="payments-table-body">
                        <tr><td colspan="7" style="padding: 20px; text-align: center;">Yükleniyor...</td></tr>
                    </tbody>
                </table>
            </div>

            <!-- Breakdown Summary Table -->
            <div class="summary-container" style="margin-top: 30px; background: #222; border-radius: 10px; padding: 20px;">
                <h3 id="finance-summary-title" style="margin-bottom: 20px; color: #FFD700; font-size: 18px;">Ödeme Dağılımı</h3>
                <table style="width: 100%; border-collapse: collapse; color: #eee;">
                    <thead>
                        <tr style="border-bottom: 1px solid #444; text-align: left;">
                            <th style="padding: 12px; color: #888;">Ödeme Yöntemi</th>
                            <th style="padding: 12px; color: #888; text-align: right;">Toplam Adet</th>
                        </tr>
                    </thead>
                    <tbody id="finance-summary-body">
                        <tr><td colspan="2" style="text-align: center; padding: 20px;">Hesaplanıyor...</td></tr>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TAB 2: UPCOMING PAYMENTS VIEW -->
        <div id="finance-upcoming-view" style="display: none;">
            <div style="background: rgba(255, 215, 0, 0.06); border: 1px solid rgba(255, 215, 0, 0.2); border-radius: 10px; padding: 14px 18px; margin-bottom: 20px; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px;">
                <div style="display: flex; align-items: center; gap: 10px; color: #ddd; font-size: 14px;">
                    <span style="font-size: 18px;">🔔</span>
                    <span>Kalan dersi <strong>3, 2, 1 veya 0</strong> olan ve paket yenilemesi / ödemesi yaklaşan aktif üyeler listelenmektedir.</span>
                </div>
                <div id="upcoming-filter-pills" style="display: flex; gap: 6px;">
                    <button class="upcoming-pill active" data-sessions="all" onclick="filterUpcomingBySession('all')" style="padding: 6px 12px; border-radius: 8px; border: 1px solid #FFD700; background: #FFD700; color: #000; font-weight: 700; font-size: 12px; cursor: pointer;">Tümü</button>
                    <button class="upcoming-pill" data-sessions="0" onclick="filterUpcomingBySession(0)" style="padding: 6px 12px; border-radius: 8px; border: 1px solid #444; background: #222; color: #EF4444; font-weight: 700; font-size: 12px; cursor: pointer;">Bitti (0)</button>
                    <button class="upcoming-pill" data-sessions="1" onclick="filterUpcomingBySession(1)" style="padding: 6px 12px; border-radius: 8px; border: 1px solid #444; background: #222; color: #F59E0B; font-weight: 700; font-size: 12px; cursor: pointer;">Son 1 Ders</button>
                    <button class="upcoming-pill" data-sessions="2" onclick="filterUpcomingBySession(2)" style="padding: 6px 12px; border-radius: 8px; border: 1px solid #444; background: #222; color: #FFD700; font-weight: 700; font-size: 12px; cursor: pointer;">Son 2 Ders</button>
                    <button class="upcoming-pill" data-sessions="3" onclick="filterUpcomingBySession(3)" style="padding: 6px 12px; border-radius: 8px; border: 1px solid #444; background: #222; color: #38BDF8; font-weight: 700; font-size: 12px; cursor: pointer;">Son 3 Ders</button>
                </div>
            </div>

            <div class="table-container" style="overflow-x: auto; background: #222; border-radius: 10px; padding: 10px;">
                <table style="width: 100%; border-collapse: collapse; color: #eee;">
                    <thead>
                        <tr style="border-bottom: 1px solid #444; text-align: left;">
                            <th style="padding: 12px;">Üye</th>
                            <th style="padding: 12px;">Eğitmen</th>
                            <th style="padding: 12px;">Mevcut Paket</th>
                            <th style="padding: 12px;">Kalan Ders / Durum</th>
                            <th style="padding: 12px;">Telefon</th>
                            <th style="padding: 12px; text-align: right;">İşlemler</th>
                        </tr>
                    </thead>
                    <tbody id="upcoming-payments-table-body">
                        <tr><td colspan="6" style="padding: 20px; text-align: center;">Yükleniyor...</td></tr>
                    </tbody>
                </table>
            </div>
        </div>
    `;

    const yearSelect = document.getElementById('finance-year');
    const monthSelect = document.getElementById('finance-month');
    
    // Yılları doldur
    const currentYear = new Date().getFullYear();
    for (let i = 0; i < 5; i++) {
        const option = document.createElement('option');
        option.value = currentYear - i;
        option.textContent = currentYear - i;
        yearSelect.appendChild(option);
    }
    
    // Başlangıç defaultları seç (ay/yıl)
    yearSelect.value = currentYear.toString();
    monthSelect.value = new Date().getMonth().toString();

    // Filtre işleyiciler (listeners)
    yearSelect.addEventListener('change', () => {
        const monthGroup = document.getElementById('month-filter-group');
        if (yearSelect.value === 'all') {
            if(monthGroup) monthGroup.style.display = 'none';
        } else {
            if(monthGroup) monthGroup.style.display = 'flex';
        }
        loadPaymentsList();
    });
    
    monthSelect.addEventListener('change', loadPaymentsList);

    // Setup payment modal listeners so "Ödeme Al" works inside Finance tab too
    setupFinancePaymentModal();

    // Apply initial tab UI
    updateTabStyles();

    await Promise.all([
        loadPaymentsList(),
        loadUpcomingPaymentsList()
    ]);
}

async function loadPaymentsList() {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        // Admin check? Or trainers can see too? Assuming Organization scope.
        // We need organization_id.
        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;

        // We need to join members to filter by organization?
        // Or RLS handles it? Assuming RLS handles it.
        // Also need member name.

        const yearSelect = document.getElementById('finance-year');
        const monthSelect = document.getElementById('finance-month');
        
        let query = supabaseClient
            .from('payments')
            .select('*, members(name, organization_id)')
            .order('date', { ascending: false });

        if (yearSelect && yearSelect.value !== 'all') {
            const year = parseInt(yearSelect.value);
            const month = parseInt(monthSelect.value);
            // UTC vs Local time fix: ensuring we wrap the entire local month
            const startDate = new Date(year, month, 1, 0, 0, 0).toISOString();
            const endDate = new Date(year, month + 1, 0, 23, 59, 59, 999).toISOString();
            
            query = query.gte('date', startDate).lte('date', endDate);
        } else {
            // Tüm zamanlar seçeneğinde performansı korumak için max 500 ödeme getiriyoruz
            query = query.limit(500); 
        }

        const { data: payments, error } = await query;

        if (error) throw error;

        const tableBody = document.getElementById('payments-table-body');
        if (!tableBody) return; // Stop if user navigated away

        // Filter by frontend if RLS isn't perfect relation-wise, but members join should help check org
        // Ideally backend RLS ensures we only see our org's payments. 
        // Let's assume fetched payments are correct.

        const filteredPayments = payments.filter(p => p.members && p.members.organization_id === profile.organization_id);

        if (filteredPayments.length === 0) {
            tableBody.innerHTML = '<tr><td colspan="7" style="padding: 20px; text-align: center;">Bu ayda bir ödeme mevcut değil.</td></tr>';
            
            // Clear summary table if no data
            const summaryBody = document.getElementById('finance-summary-body');
            if (summaryBody) {
                summaryBody.innerHTML = '<tr><td colspan="2" style="text-align: center; padding: 20px; color: #888;">Bu ayda bir ödeme mevcut değil.</td></tr>';
            }
            
            const summaryTitle = document.getElementById('finance-summary-title');
            if (summaryTitle) {
                if (yearSelect && yearSelect.value === 'all') {
                    summaryTitle.textContent = 'Tüm Zamanlar Ödeme Dağılımı';
                } else if (yearSelect) {
                    const monthNames = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
                    const mName = monthNames[parseInt(monthSelect.value)];
                    summaryTitle.textContent = `${mName} ${yearSelect.value} Ödeme Dağılımı`;
                }
            }

            // Ayrıca "Son İşlem" kısmını da temizle
            const lastPayment = document.getElementById('last-payment');
            if (lastPayment) lastPayment.textContent = '-';

            return;
        }

        // Calculate Stats (removed total revenue calculation)

        const now = new Date();
        if (filteredPayments.length > 0) {
            document.getElementById('last-payment').textContent = `${filteredPayments[0].members.name}`;
        }

        tableBody.innerHTML = filteredPayments.map(p => `
            <tr style="border-bottom: 1px solid #333;">
                <td style="padding: 12px; color: #aaa;">${new Date(p.date).toLocaleDateString('tr-TR')}</td>
                <td style="padding: 12px; font-weight: bold;">${p.members.name}</td>
                <td style="padding: 12px;">
                    <span style="background: rgba(255, 215, 0, 0.1); color: #FFD700; padding: 2px 8px; border-radius: 4px; font-size: 12px;">
                        ${formatPaymentCategory(p.category)}
                    </span>
                </td>
                <td style="padding: 12px; color: #ccc;">${formatPaymentType(p.type)}</td>
                 <td style="padding: 12px; color: #4ade80; font-weight: bold;">
                    ${p.amount === 0 ? 'Ödeme alındı' : (p.amount || 0).toLocaleString('tr-TR', { minimumFractionDigits: 2 }) + ' TL'}
                 </td>
                <td style="padding: 12px; color: #888; font-size: 12px; max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                    ${p.description || ''}
                </td>
                <td style="padding: 12px; text-align: right;">
                    <button onclick="editPayment('${p.id}')" style="background: none; border: none; cursor: pointer; color: #3b82f6; margin-right: 8px;">✎</button>
                    <button onclick="deletePayment('${p.id}')" style="background: none; border: none; cursor: pointer; color: #ef4444;">🗑️</button>
                </td>
            </tr>
        `).join('');

        const summaryTitle = document.getElementById('finance-summary-title');
        if (summaryTitle) {
            if (yearSelect && yearSelect.value === 'all') {
                summaryTitle.textContent = 'Tüm Zamanlar Ödeme Dağılımı';
            } else if (yearSelect) {
                const monthNames = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
                const mName = monthNames[parseInt(monthSelect.value)];
                summaryTitle.textContent = `${mName} ${yearSelect.value} Ödeme Dağılımı`;
            }
        }

        // --- Calculate Payment Method Counts ---
        // Artık filtreleme Supabase tarafında yapıldığı için gelen sonuçları doğrudan kullanıyoruz.
        const monthlyPayments = filteredPayments;

        const methodCounts = {
            'cash': { count: 0, label: 'Nakit' },
            'credit_card': { count: 0, label: 'Kredi Kartı' },
            'transfer': { count: 0, label: 'Havale/EFT' }
        };

        monthlyPayments.forEach(p => {
            const typeKey = p.type || 'cash';
            if (methodCounts[typeKey]) {
                methodCounts[typeKey].count++;
            }
        });

        // Render Summary Body
        const summaryBody = document.getElementById('finance-summary-body');
        const rows = Object.keys(methodCounts).map(key => {
            const row = methodCounts[key];
            return `
                <tr style="border-bottom: 1px solid #333;">
                    <td style="padding: 12px;">${row.label}</td>
                    <td style="padding: 12px; text-align: right; font-weight: 500; color: #4ade80;">${row.count}</td>
                </tr>
            `;
        }).join('');

        summaryBody.innerHTML = rows || '<tr><td colspan="2" style="text-align: center; padding: 20px; color: #888;">Bu ay işlem bulunamadı.</td></tr>';

    } catch (error) {
        console.error('Error loading payments:', error);
        showToast('Ödemeler yüklenirken hata oluştu', 'error');
    }
}

function formatPaymentType(type) {
    const types = {
        'cash': 'Nakit',
        'credit_card': 'Kredi Kartı',
        'transfer': 'Havale/EFT'
    };
    return types[type] || type || '-';
}

function formatPaymentCategory(category) {
    const categories = {
        'package_renewal': 'Paket Yenileme',
        'single_session': 'Tek Ders',
        'extra': 'Ekstra',
        'other': 'Diğer'
    };
    return categories[category] || category || '-';
}

// Global Handlers
window.deletePayment = async (id) => {
    window.showConfirmation('Ödemeyi Sil', 'Bu ödemeyi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.', async () => {
        try {
            const { error } = await supabaseClient
                .from('payments')
                .delete()
                .eq('id', id);

            if (error) throw error;

            showToast('Ödeme silindi', 'success');
            loadPaymentsList(); // Refresh
        } catch (e) {
            console.error(e);
            showToast('Silme başarısız', 'error');
        }
    });
};

window.editPayment = async (id) => {
    // 1. Fetch details (or pass them, but fetching is safer)
    try {
        const { data: payment, error } = await supabaseClient
            .from('payments')
            .select('*')
            .eq('id', id)
            .single();

        if (error) throw error;

        // 2. Open Modal (Reuse #payment-modal)
        const modal = document.getElementById('payment-modal');
        const form = document.getElementById('payment-form');

        // Populate
        document.getElementById('payment-member-id').value = payment.member_id; // Keep member ID logic? Yes
        // Tutar alanı kaldırıldı
        document.getElementById('payment-description').value = payment.description || '';

        // Map Types back to UI
        const typeMap = { 'cash': 'Nakit', 'credit_card': 'Kredi Kartı', 'transfer': 'Havale/EFT' };
        document.getElementById('payment-method').value = typeMap[payment.type] || 'Nakit';

        const catMap = { 'package_renewal': 'Paket Yenileme', 'single_session': 'Tek Ders', 'extra': 'Ekstra', 'other': 'Diğer' };
        document.getElementById('payment-category').value = catMap[payment.category] || 'Diğer';

        // UI Updates
        document.querySelector('#payment-modal h2').textContent = 'Ödemeyi Düzenle';
        modal.classList.add('active');

        // 3. Bind Update Handler
        form.onsubmit = async (e) => {
            e.preventDefault();
            const submitBtn = form.querySelector('button[type="submit"]');
            submitBtn.disabled = true;

            try {
                const amount = 0; // Tutar artık kaydedilmiyor, varsayılan 0
                const methodRaw = document.getElementById('payment-method').value;
                const categoryRaw = document.getElementById('payment-category').value;
                const description = document.getElementById('payment-description').value;

                let method = 'cash';
                if (methodRaw === 'Kredi Kartı') method = 'credit_card';
                else if (methodRaw === 'Havale/EFT') method = 'transfer';

                let category = 'package_renewal'; // default
                if (categoryRaw === 'Tek Ders') category = 'single_session';
                else if (categoryRaw === 'Ekstra') category = 'extra';

                const { error: updateError } = await supabaseClient
                    .from('payments')
                    .update({
                        amount,
                        type: method,
                        category,
                        description
                    })
                    .eq('id', id);

                if (updateError) throw updateError;

                showToast('Ödeme güncellendi', 'success');
                modal.classList.remove('active');
                loadPaymentsList();

            } catch (err) {
                console.error(err);
                showToast('Güncelleme hatası', 'error');
            } finally {
                submitBtn.disabled = false;
            }
        };

        // Close logic handles itself in members.js (setupPaymentModal) via window.onclick etc.
        // But we need to make sure close button works. It strictly works because members.js setUpPaymentModal handles close click.

    } catch (e) {
        console.error(e);
        showToast('Ödeme detayları alınamadı', 'error');
    }
};

window.exportFinanceToExcel = async () => {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();
        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) {
            showToast('Organizasyon bulunamadı', 'error');
            return;
        }

        // Tüm ödemeleri getiriyoruz
        const { data: payments, error } = await supabaseClient
            .from('payments')
            .select('*, members(name, organization_id)')
            .order('date', { ascending: false });

        if (error) throw error;

        const orgPayments = payments.filter(p => p.members && p.members.organization_id === profile.organization_id);

        if (orgPayments.length === 0) {
            showToast('Dışa aktarılacak ödeme bulunamadı', 'info');
            return;
        }

        const grouped = {};
        const monthNames = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];

        orgPayments.forEach(p => {
            const d = new Date(p.date);
            const year = d.getFullYear();
            const month = d.getMonth();
            const sheetName = `${monthNames[month]} ${year}`;
            
            if (!grouped[sheetName]) {
                grouped[sheetName] = [];
            }
            grouped[sheetName].push({
                'Tarih': d.toLocaleDateString('tr-TR'),
                'Üye': p.members.name,
                'Kategori': formatPaymentCategory(p.category),
                'Yöntem': formatPaymentType(p.type),
                'Tutar': p.amount === 0 ? 'Ödeme alındı' : p.amount + ' TL',
                'Not': p.description || ''
            });
        });

        // SheetJS (XLSX) workbook oluştur
        if (typeof XLSX === 'undefined') {
            showToast('Excel kütüphanesi yüklenemedi', 'error');
            return;
        }
        
        const wb = XLSX.utils.book_new();

        Object.keys(grouped).forEach(sheetName => {
            const ws = XLSX.utils.json_to_sheet(grouped[sheetName]);
            
            // Sütun genişliklerini ayarla
            const wscols = [
                {wch: 15}, // Tarih
                {wch: 25}, // Üye
                {wch: 20}, // Kategori
                {wch: 15}, // Yöntem
                {wch: 15}, // Tutar
                {wch: 35}  // Not
            ];
            ws['!cols'] = wscols;
            
            XLSX.utils.book_append_sheet(wb, ws, sheetName);
        });

        XLSX.writeFile(wb, 'Finans_Raporu.xlsx');
        showToast('Excel dosyası indiriliyor', 'success');

    } catch (error) {
        console.error('Export error:', error);
        showToast('Dışa aktarılırken hata oluştu', 'error');
    }
};

// --- UPCOMING PAYMENTS & TABS LOGIC ---

let upcomingMembersCache = [];
let upcomingSessionFilter = 'all';

function updateTabStyles() {
    const btnPayments = document.getElementById('tab-btn-payments');
    const btnUpcoming = document.getElementById('tab-btn-upcoming');
    const viewPayments = document.getElementById('finance-payments-view');
    const viewUpcoming = document.getElementById('finance-upcoming-view');
    const exportBtn = document.getElementById('export-excel-btn');

    if (!btnPayments || !btnUpcoming || !viewPayments || !viewUpcoming) return;

    if (currentFinanceTab === 'payments') {
        btnPayments.style.background = '#FFD700';
        btnPayments.style.color = '#000';
        btnUpcoming.style.background = 'transparent';
        btnUpcoming.style.color = '#aaa';
        viewPayments.style.display = 'block';
        viewUpcoming.style.display = 'none';
        if (exportBtn) exportBtn.style.display = 'flex';
    } else {
        btnUpcoming.style.background = '#FFD700';
        btnUpcoming.style.color = '#000';
        btnPayments.style.background = 'transparent';
        btnPayments.style.color = '#aaa';
        viewPayments.style.display = 'none';
        viewUpcoming.style.display = 'block';
        if (exportBtn) exportBtn.style.display = 'none';
    }
}

window.switchFinanceTab = (tab) => {
    currentFinanceTab = tab;
    updateTabStyles();
    if (tab === 'upcoming') {
        loadUpcomingPaymentsList();
    } else {
        loadPaymentsList();
    }
};

window.filterUpcomingBySession = (val) => {
    upcomingSessionFilter = val;
    document.querySelectorAll('.upcoming-pill').forEach(btn => {
        const btnVal = btn.getAttribute('data-sessions');
        if (String(btnVal) === String(val)) {
            btn.style.background = '#FFD700';
            btn.style.color = '#000';
            btn.style.borderColor = '#FFD700';
        } else {
            btn.style.background = '#222';
            btn.style.borderColor = '#444';
            if (btnVal === '0') btn.style.color = '#EF4444';
            else if (btnVal === '1') btn.style.color = '#F59E0B';
            else if (btnVal === '2') btn.style.color = '#FFD700';
            else if (btnVal === '3') btn.style.color = '#38BDF8';
            else btn.style.color = '#eee';
        }
    });
    renderUpcomingTable();
};

async function loadUpcomingPaymentsList() {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (!user) return;

        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id, role')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;

        let query = supabaseClient
            .from('members')
            .select('id, name, phone, email, subscription_package, session_count, trainer_id, is_active, is_multisport, is_meditopia, profiles:trainer_id(first_name, last_name)')
            .eq('organization_id', profile.organization_id)
            .not('session_count', 'is', null)
            .lte('session_count', 3)
            .order('session_count', { ascending: true });

        if (profile.role === 'trainer') {
            query = query.eq('trainer_id', user.id);
        }

        const { data: rawMembers, error } = await query;
        if (error) throw error;

        // Kalan dersi 1, 2 veya 3 olan tüm üyeleri (veya 0 olup aktif & normal paketli olanları) göster
        const members = (rawMembers || []).filter(m => {
            if (m.session_count >= 1 && m.session_count <= 3) return true;
            return m.is_active && !m.is_multisport && !m.is_meditopia;
        });

        upcomingMembersCache = members || [];

        const badge = document.getElementById('upcoming-count-badge');
        if (badge) {
            if (upcomingMembersCache.length > 0) {
                badge.style.display = 'inline-block';
                badge.textContent = upcomingMembersCache.length;
            } else {
                badge.style.display = 'none';
            }
        }

        renderUpcomingTable();
    } catch (e) {
        console.error('Error loading upcoming payments:', e);
        const tbody = document.getElementById('upcoming-payments-table-body');
        if (tbody) {
            tbody.innerHTML = '<tr><td colspan="6" style="padding: 20px; text-align: center; color: #ef4444;">Liste yüklenirken hata oluştu.</td></tr>';
        }
    }
}

function renderUpcomingTable() {
    const tbody = document.getElementById('upcoming-payments-table-body');
    if (!tbody) return;

    let filtered = upcomingMembersCache;
    if (upcomingSessionFilter !== 'all') {
        const targetCount = parseInt(upcomingSessionFilter);
        filtered = upcomingMembersCache.filter(m => (m.session_count ?? 0) === targetCount);
    }

    if (filtered.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="padding: 24px; text-align: center; color: #888;">Ödemesi yaklaşan üye bulunmuyor.</td></tr>';
        return;
    }

    tbody.innerHTML = filtered.map(m => {
        const count = m.session_count ?? 0;
        let badgeBg = 'rgba(239, 68, 68, 0.15)';
        let badgeColor = '#EF4444';
        let statusText = '❌ Dersi Bitti (0 Ders)';

        if (count === 1) {
            badgeBg = 'rgba(245, 158, 11, 0.15)';
            badgeColor = '#F59E0B';
            statusText = '⚠️ Son 1 Ders Kaldı';
        } else if (count === 2) {
            badgeBg = 'rgba(255, 215, 0, 0.15)';
            badgeColor = '#FFD700';
            statusText = '🔔 Son 2 Ders Kaldı';
        } else if (count === 3) {
            badgeBg = 'rgba(56, 189, 248, 0.15)';
            badgeColor = '#38BDF8';
            statusText = '⏳ Son 3 Ders Kaldı';
        }

        const trainerName = m.profiles
            ? `${m.profiles.first_name || ''} ${m.profiles.last_name || ''}`.trim()
            : '-';

        const safeName = (m.name || '').replace(/'/g, "\\'");

        return `
            <tr style="border-bottom: 1px solid #333;">
                <td style="padding: 12px; font-weight: bold;">
                    <span onclick="window.location.href='member-detail.html?id=${m.id}'" style="cursor: pointer; color: #fff; text-decoration: none;" onmouseover="this.style.color='#FFD700'" onmouseout="this.style.color='#fff'">
                        ${m.name}
                    </span>
                </td>
                <td style="padding: 12px; color: #aaa;">${trainerName || '-'}</td>
                <td style="padding: 12px;">
                    <span style="background: rgba(255, 255, 255, 0.06); color: #ccc; padding: 4px 10px; border-radius: 6px; font-size: 12px;">
                        ${m.subscription_package || 'Belirtilmemiş'}
                    </span>
                </td>
                <td style="padding: 12px;">
                    <span style="background: ${badgeBg}; color: ${badgeColor}; padding: 4px 10px; border-radius: 6px; font-size: 12px; font-weight: 700; display: inline-block;">
                        ${statusText}
                    </span>
                </td>
                <td style="padding: 12px; color: #aaa; font-size: 13px;">${m.phone || '-'}</td>
                <td style="padding: 12px; text-align: right;">
                    <button onclick="openFinancePaymentModal('${m.id}', '${safeName}')" style="background: #10B981; color: #fff; border: none; padding: 6px 12px; border-radius: 6px; cursor: pointer; font-weight: 600; font-size: 12px; margin-right: 6px;">
                        💳 Ödeme Al / Yenile
                    </button>
                    <button onclick="window.location.href='member-detail.html?id=${m.id}'" style="background: rgba(255,255,255,0.08); color: #ccc; border: none; padding: 6px 10px; border-radius: 6px; cursor: pointer; font-size: 12px;">
                        Detay
                    </button>
                </td>
            </tr>
        `;
    }).join('');
}

function setupFinancePaymentModal() {
    const modal = document.getElementById('payment-modal');
    const closeBtn = document.getElementById('close-payment-modal');
    const catSelect = document.getElementById('payment-category');
    const packSelect = document.getElementById('payment-package');
    const packGroup = document.getElementById('payment-package-group');
    const manualGroup = document.getElementById('payment-manual-sessions-group');

    if (!modal) return;

    if (closeBtn) {
        closeBtn.onclick = () => modal.classList.remove('active');
    }

    if (catSelect && !catSelect.dataset.financeBound) {
        catSelect.dataset.financeBound = 'true';
        catSelect.addEventListener('change', (e) => {
            if (e.target.value === 'Paket Yenileme') {
                if (packGroup) packGroup.style.display = 'block';
                if (packSelect && packSelect.value === 'Manuel' && manualGroup) {
                    manualGroup.style.display = 'block';
                }
            } else {
                if (packGroup) packGroup.style.display = 'none';
                if (manualGroup) manualGroup.style.display = 'none';
            }
        });
    }

    if (packSelect && !packSelect.dataset.financeBound) {
        packSelect.dataset.financeBound = 'true';
        packSelect.addEventListener('change', (e) => {
            if (e.target.value === 'Manuel') {
                if (manualGroup) manualGroup.style.display = 'block';
            } else {
                if (manualGroup) manualGroup.style.display = 'none';
            }
        });
    }
}

window.openFinancePaymentModal = (memberId, memberName) => {
    const modal = document.getElementById('payment-modal');
    const form = document.getElementById('payment-form');
    if (!modal || !form) return;

    document.getElementById('payment-member-id').value = memberId;
    form.reset();
    document.querySelector('#payment-modal h2').textContent = `${memberName} - Ödeme Al`;

    const catSelect = document.getElementById('payment-category');
    if (catSelect) catSelect.value = 'Paket Yenileme';
    const packGroup = document.getElementById('payment-package-group');
    if (packGroup) packGroup.style.display = 'block';
    const manualGroup = document.getElementById('payment-manual-sessions-group');
    if (manualGroup) manualGroup.style.display = 'none';

    form.onsubmit = async (e) => {
        e.preventDefault();
        const submitBtn = form.querySelector('button[type="submit"]');
        submitBtn.disabled = true;
        submitBtn.textContent = 'Kaydediliyor...';

        try {
            const amount = 0;
            const methodRaw = document.getElementById('payment-method').value;
            const categoryRaw = document.getElementById('payment-category').value;
            const description = document.getElementById('payment-description').value;

            let method = 'cash';
            if (methodRaw === 'Kredi Kartı') method = 'credit_card';
            else if (methodRaw === 'Havale/EFT') method = 'transfer';

            let category = 'package_renewal';
            if (categoryRaw === 'Tek Ders') category = 'single_session';
            else if (categoryRaw === 'Ekstra') category = 'extra';

            const { error } = await supabaseClient
                .from('payments')
                .insert({
                    member_id: memberId,
                    amount: amount,
                    type: method,
                    category: category,
                    description: description,
                    date: new Date()
                });

            if (error) throw error;

            if (category === 'package_renewal') {
                const packageType = document.getElementById('payment-package').value.trim();
                const manualSessions = document.getElementById('payment-manual-sessions').value;

                let sessionsToAdd = 0;
                let packageName = packageType;

                if (packageType === '8 Ders Paketi') sessionsToAdd = 8;
                else if (packageType === '12 Ders Paketi') sessionsToAdd = 12;
                else if (packageType === 'Manuel') {
                    sessionsToAdd = parseInt(manualSessions) || 0;
                    packageName = sessionsToAdd + ' Ders Paketi';
                }

                if (sessionsToAdd > 0) {
                    const { data: member } = await supabaseClient
                        .from('members')
                        .select('session_count')
                        .eq('id', memberId)
                        .maybeSingle();

                    if (member) {
                        const newTotalCount = (member.session_count || 0) + sessionsToAdd;
                        await supabaseClient
                            .from('members')
                            .update({
                                subscription_package: packageName,
                                session_count: newTotalCount,
                                is_active: true
                            })
                            .eq('id', memberId);
                    }
                }
            } else if (category === 'single_session') {
                const { data: member } = await supabaseClient
                    .from('members')
                    .select('session_count')
                    .eq('id', memberId)
                    .maybeSingle();

                if (member) {
                    await supabaseClient
                        .from('members')
                        .update({ session_count: (member.session_count || 0) + 1 })
                        .eq('id', memberId);
                }
            }

            modal.classList.remove('active');
            form.reset();
            showToast('Ödeme alındı ve paket başarıyla güncellendi', 'success');

            await Promise.all([
                loadPaymentsList(),
                loadUpcomingPaymentsList(),
                initNotifications()
            ]);
        } catch (err) {
            console.error(err);
            showToast('Ödeme kaydedilemedi: ' + err.message, 'error');
        } finally {
            submitBtn.disabled = false;
            submitBtn.textContent = 'Ödemeyi Kaydet';
        }
    };

    modal.classList.add('active');
};


