import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../data/models/payment.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../data/repositories/member_repository.dart';
import '../../members/widgets/add_payment_modal.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../members/screens/member_payments_screen.dart';
import '../../members/screens/member_detail_screen.dart';

class FinanceScreen extends StatefulWidget {
  final int initialTabIndex;

  const FinanceScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final _repository = PaymentRepository();
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isLoadingUpcoming = true;
  late int _activeTabIndex; // 0: Ödemeler, 1: Ödemesi Yaklaşanlar
  int? _selectedSessionFilter; // null: Tümü, 0, 1, 2, 3

  List<Payment> _payments = [];
  List<Map<String, dynamic>> _upcomingMembers = [];
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  
  final List<String> _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  late final List<int> _years;

  Map<String, double> _monthlyStats = {
    'total': 0,
    'cash': 0,
    'card': 0,
    'transfer': 0,
    'cash_count': 0,
    'card_count': 0,
    'transfer_count': 0,
  };

  @override
  void initState() {
    super.initState();
    _activeTabIndex = widget.initialTabIndex;
    _years = List.generate(DateTime.now().year - 2024 + 2, (index) => 2024 + index);
    _loadData();
    _loadUpcomingMembers();
  }

  Future<void> _loadUpcomingMembers() async {
    setState(() => _isLoadingUpcoming = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingUpcoming = false);
        return;
      }

      final profileParams = await _supabase
          .from('profiles')
          .select('organization_id, role')
          .eq('id', user.id)
          .single();

      final orgId = profileParams['organization_id'];
      final role = profileParams['role'];

      if (orgId == null) {
        if (mounted) setState(() => _isLoadingUpcoming = false);
        return;
      }

      var query = _supabase
          .from('members')
          .select('id, name, phone, email, subscription_package, session_count, is_active, is_multisport, is_meditopia, profiles:trainer_id(first_name, last_name)')
          .eq('organization_id', orgId)
          .not('session_count', 'is', null)
          .lte('session_count', 3);

      if (role == 'trainer') {
        query = query.eq('trainer_id', user.id);
      }

      final response = await query.order('session_count', ascending: true);
      final filtered = List<Map<String, dynamic>>.from(response).where((m) {
        final count = m['session_count'] as int? ?? 0;
        if (count >= 1 && count <= 3) return true;
        return (m['is_active'] == true) &&
            (m['is_multisport'] != true) &&
            (m['is_meditopia'] != true);
      }).toList();
      if (mounted) {
        setState(() {
          _upcomingMembers = filtered;
          _isLoadingUpcoming = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading upcoming members: $e');
      if (mounted) {
        setState(() => _isLoadingUpcoming = false);
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final startOfMonth = DateTime(_selectedYear, _selectedMonth, 1);
      final endOfMonth = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
      
      final payments = await _repository.getRecentPayments(
        start: startOfMonth,
        end: endOfMonth,
        limit: 100,
      );
      
      final stats = await _repository.getIncomeReport(startOfMonth, endOfMonth);

      if (mounted) {
        setState(() {
          _payments = payments;
          _monthlyStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading finance data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackBar.showError(context, 'Veriler yüklenirken bir hata oluştu');
      }
    }
  }

  Future<void> _handleDelete(Payment payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Ödemeyi Sil', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bu ödeme kaydını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.delete(payment.id);
        if (mounted) {
          CustomSnackBar.showSuccess(context, 'Ödeme başarıyla silindi');
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          CustomSnackBar.showError(context, 'Silme işlemi başarısız: $e');
        }
      }
    }
  }

  Future<void> _handleEdit(Payment payment) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final memberRepo = MemberRepository();
      // Fetch full member details
      final member = await memberRepo.getById(payment.memberId);
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (member != null && mounted) {
        final result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => AddPaymentModal(
            member: member,
            paymentToEdit: payment,
          ),
        );

        if (result == true) {
          _loadData();
        }
      } else {
        if (mounted) {
          CustomSnackBar.showError(context, 'Üye bilgisi bulunamadı');
        }
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) Navigator.pop(context);
      if (mounted) {
        CustomSnackBar.showError(context, 'Hata: $e');
      }
    }
  }

  Future<void> _openMemberDetail(String memberId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final member = await MemberRepository().getById(memberId);
      if (mounted) Navigator.pop(context);
      if (member != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemberDetailScreen(member: member),
          ),
        );
        _loadUpcomingMembers();
        _loadData();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) CustomSnackBar.showError(context, 'Hata: $e');
    }
  }

  Future<void> _openAddPaymentForMember(String memberId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final member = await MemberRepository().getById(memberId);
      if (mounted) Navigator.pop(context);
      if (member != null && mounted) {
        final result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => AddPaymentModal(member: member),
        );
        if (result == true) {
          _loadUpcomingMembers();
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) CustomSnackBar.showError(context, 'Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Finans & Ödemeler',
          style: AppTextStyles.headline.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const IOExceptionButton(),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Tab Switcher
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTabIndex = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeTabIndex == 0
                                  ? AppColors.primaryYellow
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Ödemeler',
                              style: AppTextStyles.subheadline.copyWith(
                                color: _activeTabIndex == 0
                                    ? Colors.black
                                    : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTabIndex = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeTabIndex == 1
                                  ? AppColors.primaryYellow
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Ödemesi Yaklaşanlar',
                                    style: AppTextStyles.subheadline.copyWith(
                                      color: _activeTabIndex == 1
                                          ? Colors.black
                                          : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_upcomingMembers.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _activeTabIndex == 1
                                          ? Colors.black
                                          : AppColors.accentRed,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_upcomingMembers.length}',
                                      style: TextStyle(
                                        color: _activeTabIndex == 1
                                            ? AppColors.primaryYellow
                                            : Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _activeTabIndex == 0
                    ? _buildPaymentsTab()
                    : _buildUpcomingPaymentsTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
        await _loadUpcomingMembers();
      },
      color: AppColors.primaryYellow,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Year & Month Selection
          _buildDateFilters(),
          const SizedBox(height: 20),

          // Monthly Summary Card
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_months[_selectedMonth - 1]} $_selectedYear Özet',
                  style: AppTextStyles.title3.copyWith(
                    color: AppColors.primaryYellow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildStatRow('Nakit', _monthlyStats['cash_count']!),
                _buildStatRow('Kredi Kartı', _monthlyStats['card_count']!),
                _buildStatRow('Havale/EFT', _monthlyStats['transfer_count']!),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Son İşlemler',
            style: AppTextStyles.title3.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          
          if (_payments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Henüz işlem bulunmuyor',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            )
          else
            ..._payments.map((payment) => _buildPaymentCard(payment)),
        ],
      ),
    );
  }

  Widget _buildUpcomingPaymentsTab() {
    if (_isLoadingUpcoming) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _selectedSessionFilter == null
        ? _upcomingMembers
        : _upcomingMembers
            .where((m) => (m['session_count'] ?? 0) == _selectedSessionFilter)
            .toList();

    return RefreshIndicator(
      onRefresh: _loadUpcomingMembers,
      color: AppColors.primaryYellow,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(null, 'Tümü', AppColors.primaryYellow),
                const SizedBox(width: 8),
                _buildFilterChip(0, 'Bitti (0)', AppColors.accentRed),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'Son 1 Ders', AppColors.accentOrange),
                const SizedBox(width: 8),
                _buildFilterChip(2, 'Son 2 Ders', AppColors.primaryYellow),
                const SizedBox(width: 8),
                _buildFilterChip(3, 'Son 3 Ders', AppColors.accentBlue),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.accentGreen,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ödemesi yaklaşan üye bulunmuyor.',
                      style: AppTextStyles.body.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((m) => _buildUpcomingMemberCard(m)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int? sessionVal, String label, Color accentColor) {
    final isSelected = _selectedSessionFilter == sessionVal;
    return GestureDetector(
      onTap: () => setState(() => _selectedSessionFilter = sessionVal),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryYellow : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryYellow : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : accentColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingMemberCard(Map<String, dynamic> m) {
    final id = m['id'] as String;
    final name = m['name'] as String? ?? 'İsimsiz';
    final pkg = m['subscription_package'] as String? ?? 'Belirtilmemiş';
    final count = (m['session_count'] as int?) ?? 0;
    final profileMap = m['profiles'] as Map<String, dynamic>?;
    final trainerName = profileMap != null
        ? '${profileMap['first_name'] ?? ''} ${profileMap['last_name'] ?? ''}'.trim()
        : '';

    Color statusColor = AppColors.accentRed;
    String iconStr = '❌';
    String statusMsg = 'Dersi kalmadı! (Ödeme Bekliyor)';

    if (count == 1) {
      statusColor = AppColors.accentOrange;
      iconStr = '⚠️';
      statusMsg = 'Son 1 dersi kaldı';
    } else if (count == 2) {
      statusColor = AppColors.primaryYellow;
      iconStr = '🔔';
      statusMsg = 'Son 2 dersi kaldı';
    } else if (count == 3) {
      statusColor = AppColors.accentBlue;
      iconStr = '⏳';
      statusMsg = 'Son 3 dersi kaldı';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => _openMemberDetail(id),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  alignment: Alignment.center,
                  child: Text(iconStr, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.headline.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusMsg,
                        style: AppTextStyles.caption1.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trainerName.isNotEmpty
                            ? 'Paket: $pkg • Eğitmen: $trainerName'
                            : 'Paket: $pkg',
                        style: AppTextStyles.caption2.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _openAddPaymentForMember(id),
                  tooltip: 'Ödeme Al',
                  icon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accentGreen.withOpacity(0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payments_rounded, color: AppColors.accentGreen, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Ödeme Al',
                          style: TextStyle(
                            color: AppColors.accentGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, double count, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal 
                ? AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 18)
                : AppTextStyles.body.copyWith(color: Colors.white70),
          ),
          Text(
            count.toInt().toString(), // Show as integer count
            style: isTotal 
                ? AppTextStyles.title3.copyWith(color: AppColors.accentGreen)
                : AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Payment payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceUser.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MemberPaymentsScreen(
                  memberId: payment.memberId,
                  memberName: payment.memberName ?? 'Üye',
                ),
              ),
            );
          },
          child: Slidable(
            key: ValueKey(payment.id),
            endActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: 0.5,
            children: [
              SlidableAction(
                onPressed: (context) => _handleEdit(payment),
                backgroundColor: AppColors.primaryYellow,
                foregroundColor: Colors.black,
                icon: Icons.edit_rounded,
                label: 'Düzenle',
              ),
              SlidableAction(
                onPressed: (context) => _handleDelete(payment),
                backgroundColor: AppColors.accentRed,
                foregroundColor: Colors.white,
                icon: Icons.delete_rounded,
                label: 'Sil',
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getPaymentIcon(payment.type),
                    color: AppColors.primaryYellow,
                  ),
                ),
                const SizedBox(width: 16),
                
                // 2. Middle Content (Name, Category, Date)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        payment.memberName ?? 'Silinmiş Üye',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(payment.category).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              payment.category.label,
                              style: TextStyle(
                                color: _getCategoryColor(payment.category),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            payment.formattedDate,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12), // Minimum gap before trailing
                
                // 3. Trailing Content (Amount, Type)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      payment.formattedAmount,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payment.type.label,
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDateFilters() {
    return Row(
      children: [
        // Year selection
        Expanded(
          child: _buildSelector(
            label: 'YIL SEÇİMİ',
            value: _selectedYear.toString(),
            onTap: () => _showYearPicker(),
          ),
        ),
        const SizedBox(width: 12),
        // Month selection
        Expanded(
          child: _buildSelector(
            label: 'AY SEÇİMİ',
            value: _months[_selectedMonth - 1],
            onTap: () => _showMonthPicker(),
          ),
        ),
      ],
    );
  }

  Widget _buildSelector({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.primaryYellow,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showYearPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPickerSheet(
        title: 'Yıl Seçin',
        items: _years.reversed.toList(),
        selectedValue: _selectedYear,
        onSelected: (year) {
          setState(() => _selectedYear = year);
          _loadData();
        },
      ),
    );
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPickerSheet(
        title: 'Ay Seçin',
        items: List.generate(12, (index) => index + 1),
        itemLabel: (month) => _months[month - 1],
        selectedValue: _selectedMonth,
        onSelected: (month) {
          setState(() => _selectedMonth = month);
          _loadData();
        },
      ),
    );
  }

  Widget _buildPickerSheet<T>({
    required String title,
    required List<T> items,
    required T selectedValue,
    required Function(T) onSelected,
    String Function(T)? itemLabel,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTextStyles.title3.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = item == selectedValue;
                final label = itemLabel != null ? itemLabel(item) : item.toString();

                return ListTile(
                  title: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? AppColors.primaryYellow : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  onTap: () {
                    onSelected(item);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentIcon(PaymentType type) {
    switch (type) {
      case PaymentType.cash: return Icons.payments_rounded;
      case PaymentType.creditCard: return Icons.credit_card_rounded;
      case PaymentType.transfer: return Icons.account_balance_rounded;
    }
  }

  Color _getCategoryColor(PaymentCategory category) {
     switch (category) {
       case PaymentCategory.packageRenewal: return AppColors.primaryYellow;
       case PaymentCategory.singleSession: return AppColors.accentBlue;
       case PaymentCategory.extra: return AppColors.accentOrange;
       case PaymentCategory.other: return Colors.purpleAccent;
     }
  }
}

class IOExceptionButton extends StatelessWidget {
  const IOExceptionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      ),
      onPressed: () => Navigator.pop(context),
    );
  }
}
