import { supabaseClient } from '../supabase-config.js';
import { showToast } from '../utils.js';

export async function loadFinance() {
    const contentArea = document.getElementById('content-area');

    contentArea.innerHTML = `
        <div class="module-header">
            <h2>Finans & Ödemeler</h2>
        </div>
        <div class="filters-row" style="display: flex; gap: 15px; margin-bottom: 20px; align-items: center;">
            <select id="finance-year" style="padding: 10px; border-radius: 5px; background: #222; color: #fff; border: 1px solid #444; outline: none; cursor: pointer;">
                <option value="all">Tüm Zamanlar</option>
            </select>
            <select id="finance-month" style="padding: 10px; border-radius: 5px; background: #222; color: #fff; border: 1px solid #444; outline: none; cursor: pointer;">
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
        if (yearSelect.value === 'all') {
            monthSelect.style.display = 'none';
        } else {
            monthSelect.style.display = 'block';
        }
        loadPaymentsList();
    });
    
    monthSelect.addEventListener('change', loadPaymentsList);

    await loadPaymentsList();
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
            tableBody.innerHTML = '<tr><td colspan="7" style="padding: 20px; text-align: center;">Henüz ödeme yok.</td></tr>';
            
            // Clear summary table if no data
            const summaryBody = document.getElementById('finance-summary-body');
            if (summaryBody) {
                summaryBody.innerHTML = '<tr><td colspan="2" style="text-align: center; padding: 20px; color: #888;">Bu ay / aralık için işlem bulunamadı.</td></tr>';
            }
            
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
