import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/profile.dart'; // Needed for navigation if ChatScreen requires Profile
import '../../../data/repositories/message_repository.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../chat/screens/chat_screen.dart';
import 'new_message_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _repository = MessageRepository();
  List<InboxItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    try {
      final items = await _repository.getInboxItems();
      if (mounted) {
        setState(() {
          _items = items;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mesaj Kutusu', style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryYellow),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Henüz mesaj yok', style: TextStyle(color: Colors.white)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Dismissible(
                      key: Key(item.userId),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppColors.surfaceDark,
                            title: Text('Konuşmayı Sil', style: AppTextStyles.title3),
                            content: Text(
                              '${item.userName} ile olan tüm mesajlar silinecek. Bu işlem geri alınamaz.',
                              style: AppTextStyles.body,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Vazgeç', style: TextStyle(color: Colors.white)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Sil', style: TextStyle(color: AppColors.accentRed)),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) async {
                        try {
                          await _repository.deleteConversation(item.userId);
                          setState(() {
                            _items.removeAt(index);
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Konuşma silindi')),
                            );
                          }
                        } catch (e) {
                          _loadInbox(); // Refresh if failed
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Hata: $e')),
                            );
                          }
                        }
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.accentRed.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      child: _buildInboxItem(item),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewMessageScreen()),
          );
          _loadInbox(); // Refresh on return
        },
        backgroundColor: AppColors.primaryYellow,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildInboxItem(InboxItem item) {
    final isTrainer = item.role == 'trainer' || item.role == 'owner';
    final badgeColor = isTrainer ? AppColors.accentOrange : AppColors.success;
    final badgeText = isTrainer ? 'Antrenör' : 'Üye';

    return GlassCard(
      child: ListTile(
        onTap: () async {
          // Construct minimal profile for navigation
          final dummyProfile = Profile(
            id: item.userId,
            firstName: item.userName.split(' ').first,
            lastName: item.userName.split(' ').length > 1 ? item.userName.split(' ').last : '',
            avatarUrl: item.userAvatar,
            // other fields null
          );
          
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChatScreen(otherUser: dummyProfile)),
          );
          // Refresh inbox on return
          _loadInbox();
        },
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.accentOrange,
              backgroundImage: item.userAvatar != null ? NetworkImage(item.userAvatar!) : null,
              child: item.userAvatar == null
                  ? Text(item.userName.substring(0, 1), style: const TextStyle(color: Colors.white))
                  : null,
            ),
            if (item.unreadCount > 0)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryYellow,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    item.unreadCount.toString(),
                    style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.userName,
                style: AppTextStyles.title3.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
             // Role Badge
            if (item.role != null) ...[
              const SizedBox(width: 8),
               Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withOpacity(0.5), width: 0.5),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
         trailing: Text( // Moved time to trailing
            DateFormat('HH:mm').format(item.lastMessageTime),
            style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
          ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            item.lastMessage,
            style: TextStyle(
              color: item.unreadCount > 0 ? Colors.white : AppColors.textSecondary,
              fontWeight: item.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
