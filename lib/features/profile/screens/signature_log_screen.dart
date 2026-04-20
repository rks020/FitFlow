import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../data/models/class_session.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ambient_background.dart';

class SignatureLogScreen extends StatefulWidget {
  const SignatureLogScreen({super.key});

  @override
  State<SignatureLogScreen> createState() => _SignatureLogScreenState();
}

class _SignatureLogScreenState extends State<SignatureLogScreen> {
  final _repository = ClassRepository();
  bool _isLoading = true;

  String? _role;
  Map<String, dynamic>? _memberData;
  List<Map<String, dynamic>> _historySessions = [];
  List<ClassSession> _upcomingSessions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Determine role first
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      final role = profile['role'] as String?;
      _role = role;

      if (role == 'trainer' || role == 'owner' || role == 'admin') {
        _historySessions =
            await _repository.getCompletedHistoryWithDetails(trainerId: userId);
      } else {
        // Assume member
        final memberData = await Supabase.instance.client
            .from('members')
            .select('package_name, session_count, is_multisport, is_meditopia')
            .eq('id', userId)
            .maybeSingle();

        _memberData = memberData;
        _historySessions = await _repository.getMemberCompletedHistory(userId);
        _upcomingSessions = await _repository.getMemberUpcomingClasses(userId);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading signature log data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Ders Kaydı Defteri'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final isTrainer =
        _role == 'trainer' || _role == 'owner' || _role == 'admin';
    if (isTrainer) {
      return _buildHistoryList(_historySessions);
    } else {
      return CustomScrollView(
        padding: const EdgeInsets.all(20),
        slivers: [
          SliverToBoxAdapter(child: _buildMemberInfoCard()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          if (_upcomingSessions.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Gelecek Derslerim',
                    style: AppTextStyles.title3
                        .copyWith(color: AppColors.primaryYellow)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final session = _upcomingSessions[index];
                  return _buildUpcomingSessionCard(session);
                },
                childCount: _upcomingSessions.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Geçmiş Derslerim (Kayıtlar)',
                  style: AppTextStyles.title3
                      .copyWith(color: AppColors.primaryYellow)),
            ),
          ),
          if (_historySessions.isEmpty) ...[
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Henüz tamamlanmış dersiniz yok.',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
            )
          ] else ...[
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildHistoryCard(_historySessions[index],
                      showParticipants: false);
                },
                childCount: _historySessions.length,
              ),
            ),
          ],
        ],
      );
    }
  }

  Widget _buildMemberInfoCard() {
    if (_memberData == null) return const SizedBox.shrink();

    // Multisport / Meditopia check
    final isMultisport = _memberData!['is_multisport'] == true;
    final isMeditopia = _memberData!['is_meditopia'] == true;

    // Do not show for multisport / meditopia
    if (isMultisport || isMeditopia) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.info_outline,
                color: AppColors.primaryYellow, size: 32),
            const SizedBox(height: 12),
            Text(
              isMultisport ? 'Multisport Üyesi' : 'Meditopia Üyesi',
              style: AppTextStyles.headline
                  .copyWith(color: AppColors.primaryYellow),
            ),
            const SizedBox(height: 8),
            Text(
              'Sabit bir ders paketiniz bulunmuyor. Katıldığınız dersler kurumsal üyeliğiniz üzerinden yönetilmektedir.',
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final packageName = _memberData!['package_name'] ?? 'Bilinmiyor';
    final sessionCount = _memberData!['session_count'] ?? 0;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Icon(Icons.card_membership_rounded,
                  color: AppColors.primaryYellow, size: 28),
              const SizedBox(height: 8),
              Text(
                packageName.toString().toUpperCase(),
                style: AppTextStyles.headline
                    .copyWith(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text('Mevcut Paket',
                  style: AppTextStyles.caption1
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
          Container(width: 1, height: 40, color: AppColors.glassBorder),
          Column(
            children: [
              const Icon(Icons.bolt_rounded,
                  color: AppColors.accentCyan, size: 28),
              const SizedBox(height: 8),
              Text(
                sessionCount.toString(),
                style: AppTextStyles.headline
                    .copyWith(color: AppColors.accentCyan, fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text('Kalan Ders',
                  style: AppTextStyles.caption1
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSessionCard(ClassSession session) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_rounded,
                  color: AppColors.accentBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR')
                        .format(session.startTime.toLocal()),
                    style: AppTextStyles.subheadline
                        .copyWith(color: AppColors.primaryYellow),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.title,
                    style: AppTextStyles.headline,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) {
      return Center(
        child: Text(
          'Henüz tamamlanmış ders yok.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        return _buildHistoryCard(sessions[index], showParticipants: true);
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> session,
      {required bool showParticipants}) {
    // Use updated_at as the signing time, fall back to start_time
    final displayTime = session['updated_at'] != null
        ? DateTime.parse(session['updated_at']).toLocal()
        : DateTime.parse(session['start_time']).toLocal();

    final enrollments = (session['class_enrollments'] as List?) ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR')
                          .format(displayTime),
                      style: AppTextStyles.subheadline
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session['title'] ?? 'Ders',
                      style: AppTextStyles.headline,
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.1),
                    border: Border.all(color: AppColors.accentGreen),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Tamamlandı',
                      style: AppTextStyles.caption2
                          .copyWith(color: AppColors.accentGreen)),
                )
              ],
            ),
            if (showParticipants) ...[
              const SizedBox(height: 16),
              const Divider(color: AppColors.glassBorder, height: 1),
              const SizedBox(height: 12),
              Text('Katılımcılar',
                  style: AppTextStyles.caption1
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              if (enrollments.isEmpty)
                Text('Katılımcı yok', style: AppTextStyles.body),
              ...enrollments.map((e) {
                final member = e['members'] ?? {};
                final studentName = member['name'] ?? 'Bilinmeyen Üye';
                final isPresent =
                    e['status'] == 'attended' || e['status'] == 'completed';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(studentName, style: AppTextStyles.body)),
                      if (isPresent)
                        Text('Derse katıldı',
                            style: AppTextStyles.caption1
                                .copyWith(color: AppColors.accentGreen))
                      else
                        Text('Katılmadı',
                            style: AppTextStyles.caption1
                                .copyWith(color: AppColors.accentRed)),
                    ],
                  ),
                );
              }).toList(),
            ]
          ],
        ),
      ),
    );
  }
}
