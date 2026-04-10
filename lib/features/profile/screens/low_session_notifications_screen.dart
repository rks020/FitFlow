import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../members/screens/member_detail_screen.dart';
import '../../../data/repositories/member_repository.dart';

class LowSessionNotificationsScreen extends StatefulWidget {
  const LowSessionNotificationsScreen({super.key});

  @override
  State<LowSessionNotificationsScreen> createState() => _LowSessionNotificationsScreenState();
}

class _LowSessionNotificationsScreenState extends State<LowSessionNotificationsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profileParams = await _supabase
          .from('profiles')
          .select('organization_id, role')
          .eq('id', user.id)
          .single();

      final orgId = profileParams['organization_id'];
      final role = profileParams['role'];

      if (orgId == null) return;

      var query = _supabase
          .from('members')
          .select('id, name, session_count, is_multisport, is_meditopia')
          .eq('organization_id', orgId)
          .eq('is_active', true)
          .lte('session_count', 2);

      if (role == 'trainer') {
        query = query.or('trainer_id.eq.${user.id},is_meditopia.eq.true');
      }

      final response = await query.order('session_count', ascending: true);
      if (mounted) {
        setState(() {
          _members = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching low session notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openMemberDetail(String id) async {
    setState(() => _isLoading = true);
    final member = await MemberRepository().getById(id);
    setState(() => _isLoading = false);
    
    if (member != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MemberDetailScreen(member: member),
        ),
      ).then((_) => _fetchNotifications()); // Refresh on return
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Kalan Ders Bildirimleri'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.primaryYellow,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow))
              : _members.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'Tüm aktif üyelerinizin yeterli dersi var. Harika!',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final m = _members[index];
                        final sessionCount = m['session_count'] ?? 0;
                        final name = m['name'] ?? 'İsimsiz';
                        final id = m['id'];

                        Color color = AppColors.accentRed;
                        String iconStr = '❌';
                        String msg = 'Dersi kalmadı!';

                        if (sessionCount == 1) {
                          color = AppColors.accentOrange; 
                          iconStr = '⚠️';
                          msg = 'Sadece 1 dersi kaldı';
                        } else if (sessionCount == 2) {
                          color = AppColors.primaryYellow;
                          iconStr = '🔔';
                          msg = 'Sadece 2 dersi kaldı';
                        }

                        return InkWell(
                          onTap: () => _openMemberDetail(id),
                          borderRadius: BorderRadius.circular(16),
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: color.withOpacity(0.5)),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    iconStr,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: AppTextStyles.headline.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        msg,
                                        style: AppTextStyles.caption1.copyWith(
                                          color: color,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
