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
import '../../../core/services/presence_service.dart';

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



// ... (existing imports)

class _DashboardHomeState extends State<_DashboardHome> {
  int _totalMembers = 0;
  int _activeMembers = 0;
  int _totalMeasurements = 0;
  int _todayClasses = 0;
  bool _isLoading = true;
  bool _isOnline = false;
  RealtimeChannel? _monitorChannel;
  final _presenceService = PresenceService();

  @override
  void initState() {
    super.initState();
    _loadStats();
    _setupRealtimeSubscription();
    _setupPresence();
  }

  Future<void> _setupPresence() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await _presenceService.connect(userId);
      if (mounted) {
        setState(() => _isOnline = true);
      }
    }
  }

// ... (rest of methods)

  @override
  void dispose() {
    _presenceService.disconnect();
    if (_monitorChannel != null) {
      Supabase.instance.client.removeChannel(_monitorChannel!);
    }
    super.dispose();
  }

// ... (build method parts)

                                  GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => const ProfileScreen(),
                                        ),
                                      );
                                    },
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: 40,
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
                                        if (_isOnline)
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: AppColors.accentGreen,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: AppColors.surfaceDark,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
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
