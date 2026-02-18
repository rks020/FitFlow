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
  String _filterType = 'my_members'; // 'my_members', 'multisport', 'all'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // If viewing a specific trainer's members, default filter to 'all'
    if (widget.trainer != null) {
      _filterType = 'all';
    }
    _loadCurrentUserProfile(); // Added
    _loadMembers();
    _searchController.addListener(_filterMembers);
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
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredMembers = _members.where((member) {
        // Apply Trainer Filter (if provided)
        if (widget.trainer != null) {
          if (member.trainerId != widget.trainer!.id) return false;
        }

        // Apply Local Filters (Only if NOT viewing a specific trainer)
        if (widget.trainer == null) {
          if (_filterType == 'my_members') {
             final userId = Supabase.instance.client.auth.currentUser?.id;
             if (member.trainerId != userId) return false;
          } else if (_filterType == 'multisport') {
             if (!member.isMultisport) return false;
             
// If trainer, only show own multisport members - REMOVED to show all
             // if (_currentUserProfile?.role == 'trainer') {
             //   final userId = Supabase.instance.client.auth.currentUser?.id;
             //   if (member.trainerId != userId) return false;
             // }
          }
        } else {
          // If viewing specific trainer, we might still want to filter by multisport
          if (_filterType == 'multisport') {
            if (!member.isMultisport) return false;
          }
        }
        
        // Apply search filter
        if (query.isEmpty) return true;
        
        return member.name.toLowerCase().contains(query) ||
            member.email.toLowerCase().contains(query) ||
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.glassBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: AppTextStyles.body,
                            decoration: InputDecoration(
                              hintText: 'Üye ara...',
                              hintStyle: AppTextStyles.body.copyWith(
                                color: AppColors.textTertiary,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Toggle
                  Row(
                    children: [
                      if (widget.trainer == null)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _filterType = 'my_members';
                              _filterMembers();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _filterType == 'my_members'
                                  ? AppColors.primaryYellow
                                  : AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Üyelerim',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.callout.copyWith(
                                color: _filterType == 'my_members'
                                    ? Colors.black
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.trainer == null) const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _filterType = 'multisport';
                              _filterMembers();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _filterType == 'multisport'
                                  ? AppColors.primaryYellow
                                  : AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Multisport',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.callout.copyWith(
                                color: _filterType == 'multisport'
                                    ? Colors.black
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _filterType = 'all';
                              _filterMembers();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _filterType == 'all'
                                  ? AppColors.primaryYellow
                                  : AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Tümü',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.callout.copyWith(
                                color: _filterType == 'all'
                                    ? Colors.black
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
