import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../widgets/payment_list_item.dart';
import '../../../data/models/member.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/payment_repository.dart';

class MemberPaymentsScreen extends StatefulWidget {
  final String memberId;
  final String memberName;

  const MemberPaymentsScreen({
    super.key, 
    required this.memberId,
    required this.memberName,
  });

  @override
  State<MemberPaymentsScreen> createState() => _MemberPaymentsScreenState();
}

class _MemberPaymentsScreenState extends State<MemberPaymentsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${widget.memberName} - Ödemeler', style: AppTextStyles.headline.copyWith(fontSize: 16)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Payment>>(
        future: PaymentRepository().getMemberPayments(widget.memberId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final payments = snapshot.data ?? [];
          if (payments.isEmpty) {
            return Center(child: Text('Henüz ödeme kaydı yok.', style: TextStyle(color: Colors.grey[500])));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              return PaymentListItem(
                payment: payment,
                member: Member(
                  id: widget.memberId,
                  name: widget.memberName,
                  email: '', // Not needed here
                  phone: '', // Not needed here
                  joinDate: DateTime.now(), // Not needed here
                ),
                onPaymentUpdated: () => setState(() {}),
              );
            },
          );
        },
      ),
    );
  }
}
