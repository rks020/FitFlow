import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../shared/widgets/glass_card.dart';
import 'chat_screen.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final _repository = ProfileRepository();
  List<Profile> _allUsers = [];
  List<Profile> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      // 1. Get current user profile to check role
      final currentUser = await _repository.getProfile();
      final isMember = currentUser?.role == 'member';

      // 2. Get all organization users
      final users = await _repository.getOrganizationUsers();
      
      // 3. Filter users based on role
      List<Profile> visibleUsers = users;
      
      if (isMember) {
        // Members can ONLY see Trainers and Owners
        visibleUsers = users.where((u) => u.role == 'trainer' || u.role == 'owner').toList();
      }

      // Remove self from list (always good practice)
      final currentUserId = currentUser?.id;
      if (currentUserId != null) {
        visibleUsers = visibleUsers.where((u) => u.id != currentUserId).toList();
      }

      if (mounted) {
        setState(() {
          _allUsers = visibleUsers;
          _filteredUsers = visibleUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers.where((user) {
          final fullName = '${user.firstName} ${user.lastName}'.toLowerCase();
          return fullName.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Yeni Mesaj', style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryYellow),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              cursorColor: AppColors.primaryYellow,
              decoration: InputDecoration(
                hintText: 'Kişi ara...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(
                        child: Text(
                          'Kullanıcı bulunamadı', 
                          style: TextStyle(color: AppColors.textSecondary)
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredUsers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _buildUserItem(user);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserItem(Profile user) {
    final isOwner = user.role == 'owner';
    final isTrainer = user.role == 'trainer';
    
    final Color badgeColor;
    final String badgeText;

    if (isOwner) {
      badgeColor = AppColors.primaryYellow; // Gold/Yellow for Owner
      badgeText = 'Salon Sahibi';
    } else if (isTrainer) {
      badgeColor = AppColors.accentOrange;  // Orange for Trainer
      badgeText = 'Antrenör';
    } else {
      badgeColor = AppColors.success;       // Green for Member
      badgeText = 'Üye';
    }

    return GlassCard(
      child: ListTile(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(otherUser: user),
            ),
          );
        },
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.accentOrange,
          backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
          child: user.avatarUrl == null
              ? Text(
                  (user.firstName?[0] ?? '') + (user.lastName?[0] ?? ''),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${user.firstName} ${user.lastName}',
                style: AppTextStyles.title3.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeColor.withOpacity(0.5)),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: user.specialty != null
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  user.specialty!,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              )
            : null,
      ),
    );
  }
}
