import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../members/screens/members_list_screen.dart';
import '../../measurements/screens/measurements_main_screen.dart';
import '../../classes/screens/class_schedule_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../widgets/stat_card.dart';
import '../../../shared/widgets/glass_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/member_repository.dart';
import '../../../data/repositories/measurement_repository.dart';
import '../../../data/repositories/class_repository.dart';
import '../../members/screens/add_edit_member_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    void switchToTab(int index) {
      setState(() {
        _selectedIndex = index;
      });
    }

    final List<Widget> _screens = [
      _DashboardHome(onNavigate: switchToTab),
      const MembersListScreen(),
      const MeasurementsMainScreen(),
      const ClassScheduleScreen(),
    ];

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.primaryYellow,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          selectedLabelStyle: AppTextStyles.caption1.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: AppTextStyles.caption2,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Ana Sayfa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_rounded),
              label: 'Üyeler',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.straighten_rounded),
              label: 'Ölçümler',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center_rounded),
              label: 'Dersler',
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHome extends StatefulWidget {
  final Function(int) onNavigate;
  const _DashboardHome({required this.onNavigate});

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  int _totalMembers = 0;
  int _activeMembers = 0;
  int _totalMeasurements = 0;
  int _todayClasses = 0;
  bool _isLoading = true;
  RealtimeChannel? _monitorChannel;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _monitorChannel = Supabase.instance.client.channel('dashboard_stats');
    _monitorChannel
      ?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'members',
        callback: (payload) => _loadStats(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'measurements',
        callback: (payload) => _loadStats(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'class_sessions',
        callback: (payload) => _loadStats(),
      )
      .subscribe();
  }

  @override
  void dispose() {
    if (_monitorChannel != null) {
      Supabase.instance.client.removeChannel(_monitorChannel!);
    }
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final memberRepo = MemberRepository();
      final measurementRepo = MeasurementRepository();
      final classRepo = ClassRepository();

      final totalMembers = await memberRepo.getCount();
      final activeMembers = await memberRepo.getActiveCount();
      final totalMeasurements = await measurementRepo.getCount();
      final todayClasses = await classRepo.getTodaySessionCount();

      if (mounted) {
        setState(() {
          _totalMembers = totalMembers;
          _activeMembers = activeMembers;
          _totalMeasurements = totalMeasurements;
          _todayClasses = todayClasses;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadStats,
        color: AppColors.primaryYellow,
        backgroundColor: AppColors.surfaceDark,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center, // Align center vertically with the text row effectively?
                      // Wait, if I use start, it aligns with top.
                      // If the user wants it opposite "Change" which is in the title...
                      // The title is the top element.
                      // But the text might have line height.
                      // Let's try aligning it with the text baseline? No, Row doesn't support that easily for blocks.
                      // Let's try creating a Row for just the Title and the Button?
                      // No, the layout is Column(Title, Subtitle) | Button.
                      // If I want Button opposite Title, I should put Button INSIDE the first Layout?
                      // Or just use CrossAxisAlignment.start.
                      // But the button has 44 height. The text might be 30.
                      // Center might be better if I only check the Title.
                      // But the Column includes Subtitle.
                      
                      // Better approach: Move the subtitle OUT of the Row?
                      // Structure:
                      // Column(
                      //   Row(Title, Button),
                      //   Subtitle
                      // )
                      // THIS IS IT!
                      // This guarantees the button is purely aligned with the Title.
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'PT',
                                          style: GoogleFonts.graduate(
                                            textStyle: AppTextStyles.largeTitle.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.primaryYellow,
                                              fontSize: 28, // Reduced from largeTitle (~34)
                                            ),
                                          ),
                                        ),
                                        TextSpan(
                                          text: ' Body Change',
                                          style: GoogleFonts.graduate(
                                            textStyle: AppTextStyles.largeTitle.copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 28, // Reduced
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => const ProfileScreen(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 40, // Slightly smaller button too? maybe. User didn't ask but visual balance.
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryYellow.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.primaryYellow,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'PT',
                                          style: AppTextStyles.headline.copyWith(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sporcu Takip Sistemi',
                                style: AppTextStyles.subheadline.copyWith(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Stats Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                ),
                delegate: SliverChildListDelegate([
                  StatCard(
                    title: 'Toplam Üye',
                    value: '$_totalMembers',
                    icon: Icons.people_rounded,
                    color: AppColors.accentBlue,
                  ),
                  StatCard(
                    title: 'Aktif Üye',
                    value: '$_activeMembers',
                    icon: Icons.person_rounded,
                    color: AppColors.accentGreen,
                  ),
                  StatCard(
                    title: 'Bugünkü Dersler',
                    value: '$_todayClasses',
                    icon: Icons.fitness_center_rounded,
                    color: AppColors.primaryYellow,
                  ),
                  StatCard(
                    title: 'Ölçümler',
                    value: '$_totalMeasurements',
                    icon: Icons.straighten_rounded,
                    color: AppColors.accentOrange,
                  ),
                ]),
              ),
            ),

            // Quick Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Hızlı İşlemler',
                      style: AppTextStyles.title3,
                    ),
                    const SizedBox(height: 16),
                    _QuickActionButton(
                      icon: Icons.person_add_rounded,
                      title: 'Yeni Üye Ekle',
                      subtitle: 'Sisteme yeni sporcu kaydet',
                      color: AppColors.accentBlue,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AddEditMemberScreen(),
                          ),
                        );
                        _loadStats(); // Reload stats after return
                      },
                    ),
                    const SizedBox(height: 12),
                    _QuickActionButton(
                      icon: Icons.straighten_rounded,
                      title: 'Ölçüm Yap',
                      subtitle: 'Sporcunun ölçümlerini kaydet',
                      color: AppColors.accentOrange,
                      onTap: () {
                        // Switch to Members tab (index 1) which allows selecting a member
                        widget.onNavigate(1);
                        // Ideally we could show a snackbar or guide here,
                        // but switching tab is a start.
                        // Or better: Navigate to MembersListScreen with a flag "pick_for_measurement"
                        // But for now, user just said "Ölçüm yap" needs to work.
                        // Switching to members tab is safe.
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lütfen ölçüm eklemek istediğiniz üyeyi seçin.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _QuickActionButton(
                      icon: Icons.add_circle_rounded,
                      title: 'Ders Oluştur',
                      subtitle: 'Yeni ders programı ekle',
                      color: AppColors.primaryYellow,
                      onTap: () {
                        // Switch to Classes tab (index 3)
                        widget.onNavigate(3);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.headline,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.subheadline,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
