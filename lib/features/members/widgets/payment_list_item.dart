import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/member.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/payment_repository.dart';
import 'add_payment_modal.dart';
import '../../../shared/widgets/glass_card.dart';

class PaymentListItem extends StatelessWidget {
  final Payment payment;
  final Member member;
  final VoidCallback onPaymentUpdated;

  const PaymentListItem({
    super.key,
    required this.payment,
    required this.member,
    required this.onPaymentUpdated,
  });

  Future<void> _handleTap(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('İşlemler', style: AppTextStyles.title2),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.primaryYellow),
              title: Text('Düzenle', style: AppTextStyles.body),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              title: Text('Sil', style: AppTextStyles.body.copyWith(color: Colors.redAccent)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (result == 'edit') {
      if (!context.mounted) return;
      final editResult = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AddPaymentModal(
          member: member,
          paymentToEdit: payment,
        ),
      );

      if (editResult == true) {
        onPaymentUpdated();
      }
    } else if (result == 'delete') {
      if (!context.mounted) return;
      
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
        await PaymentRepository().delete(payment.id);
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ödeme silindi'),
              backgroundColor: Colors.redAccent,
            ),
          );
          onPaymentUpdated();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.currency_lira,
                color: AppColors.accentGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.category.label,
                    style: AppTextStyles.headline.copyWith(fontSize: 16),
                  ),
                  Text(
                    payment.formattedDate,
                    style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  payment.formattedAmount,
                  style: AppTextStyles.headline.copyWith(
                    color: AppColors.accentGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  payment.type.label,
                  style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
