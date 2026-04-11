import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../data/repositories/member_repository.dart';
import '../../members/widgets/add_payment_modal.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../members/screens/member_payments_screen.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final _repository = PaymentRepository();
  bool _isLoading = true;
  List<Payment> _payments = [];
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
    _years = List.generate(DateTime.now().year - 2024 + 2, (index) => 2024 + index);
    _loadData();
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
        leading: IOExceptionButton(),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
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
                ),
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
    return Column(
      children: [
        // Year selection
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _years.reversed.map((year) {
              final isSelected = _selectedYear == year;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(year.toString()),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedYear = year);
                      _loadData();
                    }
                  },
                  backgroundColor: AppColors.surfaceDark,
                  selectedColor: AppColors.primaryYellow,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        // Month selection
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(12, (index) {
              final monthIdx = index + 1;
              final isSelected = _selectedMonth == monthIdx;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_months[index]),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedMonth = monthIdx);
                      _loadData();
                    }
                  },
                  backgroundColor: AppColors.surfaceDark,
                  selectedColor: AppColors.primaryYellow,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
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
