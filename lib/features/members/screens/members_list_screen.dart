import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/member_repository.dart';
import '../widgets/member_card.dart';
import 'add_edit_member_screen.dart';
import 'member_detail_screen.dart';
import '../../../data/models/profile.dart'; // Added
import '../../../data/repositories/profile_repository.dart'; // Added

import '../../../shared/widgets/ambient_background.dart';
import '../../../core/utils/string_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MembersListScreen extends StatefulWidget {
  final Profile? trainer;
  const MembersListScreen({super.key, this.trainer});

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MemberRepository _repository = MemberRepository();
  
  List<Member> _members = [];
  List<Member> _filteredMembers = [];
  String _filterType = 'my_members';
  List<Map<String, String>> _filterItems = [
    {'id': 'my_members', 'label': 'Üyelerim'},
    {'id': 'multisport', 'label': 'Multisport'},
    {'id': 'meditopia', 'label': 'Meditopia'},
    {'id': 'active', 'label': 'Aktif'},
    {'id': 'passive', 'label': 'Pasif'},
    {'id': 'all', 'label': 'Tümü'},
  ];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // If viewing a specific trainer's members, default filter to 'all'
    if (widget.trainer != null) {
      _filterType = 'all';
    }
    _loadFilterOrder();
    _loadCurrentUserProfile(); // Added
    _loadMembers();
    _searchController.addListener(_filterMembers);
  }

  Future<void> _loadFilterOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('member_filters_order');
    if (savedOrder != null) {
      setState(() {
        final newItems = <Map<String, String>>[];
        for (var id in savedOrder) {
          final item = _filterItems.firstWhere((element) => element['id'] == id, orElse: () => {});
          if (item.isNotEmpty) {
            newItems.add(item);
          }
        }
        // Add any missing items (e.g. if we add new filters later)
        for (var item in _filterItems) {
          if (!savedOrder.contains(item['id'])) {
            newItems.add(item);
          }
        }
        _filterItems = newItems;
      });
    }
  }

  Future<void> _saveFilterOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('member_filters_order', _filterItems.map((e) => e['id']!).toList());
  }

  Profile? _currentUserProfile;
  
  Future<void> _loadCurrentUserProfile() async {
    final profile = await ProfileRepository().getProfile();
    if (mounted) {
       setState(() {
         _currentUserProfile = profile;
       });
    }
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final members = await _repository.getAll();
      if (mounted) {
        setState(() {
          _members = members;
          _filterMembers();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Üyeler yüklenirken hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterMembers() {
    final query = _searchController.text.turkishToLower();

    
    setState(() {
      _filteredMembers = _members.where((member) {
        // Apply Trainer Filter (if provided)
        if (widget.trainer != null) {
          if (member.trainerId != widget.trainer!.id) return false;
        }

        // Apply Local Filters
        if (_filterType == 'my_members' && widget.trainer == null) {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (member.trainerId != userId) return false;
        } else if (_filterType == 'active') {
          if (!member.isActive) return false;
        } else if (_filterType == 'passive') {
          if (member.isActive) return false;
        } else if (_filterType == 'multisport') {
          if (!member.isMultisport) return false;
        } else if (_filterType == 'meditopia') {
          if (!member.isMeditopia) return false;
        }
        
        // Apply search filter
        if (query.isEmpty) return true;
        
        return member.name.turkishToLower().contains(query) ||
            member.email.turkishToLower().contains(query) ||

            member.phone.contains(query);
      }).toList();
    });
  }

  Future<void> _navigateToAddMember() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddEditMemberScreen(),
      ),
    );
    
    if (result == true) {
      _loadMembers();
    }
  }

  Future<void> _navigateToMemberDetail(Member member) async {
    // Permission Check
    if (_currentUserProfile != null && _currentUserProfile!.role == 'trainer') {
       // Allow if member is assigned to trainer OR is multisport
       if (member.trainerId != _currentUserProfile!.id && !member.isMultisport) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu üyenin detaylarını görüntüleme yetkiniz yok.'),
              backgroundColor: AppColors.accentRed,
            ),
          );
          return;
       }
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MemberDetailScreen(member: member),
      ),
    );
    
    if (result == true) {
      _loadMembers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.trainer != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      Expanded(
                        child: Text(
                          widget.trainer != null 
                              ? '${('${widget.trainer!.firstName ?? ''} ${widget.trainer!.lastName ?? ''}').trim()} Üyeleri'
                              : 'Üyeler',
                          style: AppTextStyles.largeTitle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search Bar
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.glassBorder.withOpacity(0.5),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: AppTextStyles.body.copyWith(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Üye ara...',
                        hintStyle: AppTextStyles.body.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Toggle
                  SizedBox(
                    height: 45,
                    child: ReorderableListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 4),
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _filterItems.removeAt(oldIndex);
                          _filterItems.insert(newIndex, item);
                          _saveFilterOrder();
                        });
                      },
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          color: Colors.transparent,
                          child: child,
                        );
                      },
                      children: _filterItems.map((item) {
                        final id = item['id']!;
                        final label = item['label']!;
                        
                        // "Üyelerim" visibility check logic
                        if (id == 'my_members' && widget.trainer != null) {
                          return Container(key: ValueKey(id));
                        }

                        return Padding(
                          key: ValueKey(id),
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildFilterChip(label, id),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Members List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryYellow,
                        ),
                      ),
                    )
                  : _filteredMembers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 64,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'Henüz üye yok'
                                    : 'Üye bulunamadı',
                                style: AppTextStyles.headline.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'Yeni üye eklemek için + butonuna tıklayın'
                                    : 'Farklı bir arama yapın',
                                style: AppTextStyles.subheadline,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadMembers,
                          color: AppColors.primaryYellow,
                          backgroundColor: AppColors.surfaceDark,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _filteredMembers.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final member = _filteredMembers[index];
                              return MemberCard(
                                member: member,
                                onTap: () => _navigateToMemberDetail(member),
                              );
                            },
                          ),
                        ),
            ),
          ],
      ),
      ),
      ),
      floatingActionButton: widget.trainer == null ? FloatingActionButton.extended(
        onPressed: _navigateToAddMember,
        backgroundColor: AppColors.primaryYellow,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: Text('Üye Ekle', style: AppTextStyles.headline.copyWith(color: Colors.black)),
      ) : null,
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = type;
          _filterMembers();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryYellow : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryYellow : AppColors.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.callout.copyWith(
            color: isSelected ? Colors.black : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
