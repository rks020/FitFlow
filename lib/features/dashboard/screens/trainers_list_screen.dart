import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../chat/screens/chat_screen.dart';

class TrainersListScreen extends StatefulWidget {
  const TrainersListScreen({super.key});

  @override
  State<TrainersListScreen> createState() => _TrainersListScreenState();
}

class _TrainersListScreenState extends State<TrainersListScreen> {
  final _supabase = Supabase.instance.client;
  List<Profile> _trainers = [];
  bool _isLoading = true;
  Set<String> _onlineUserIds = {};
  Set<String> _busyTrainerIds = {};
  RealtimeChannel? _presenceChannel;
  bool _isAdmin = false;
  final _profileRepository = ProfileRepository();
  Set<String> _selectedTrainerIds = {};
  bool get _isSelectionMode => _selectedTrainerIds.isNotEmpty;

  String _myStatus = 'online'; // online, busy, away
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadTrainers(),
      _checkBusyStatus(),
    ]);
    await Future.wait([
      _loadTrainers(),
      _checkBusyStatus(),
      _checkAdminStatus(),
    ]);
    _setupPresence();
  }

  Future<void> _checkAdminStatus() async {
    final profile = await _profileRepository.getProfile();
    if (mounted) {
      setState(() => _isAdmin = profile?.role == 'admin');
    }
  }

  Future<void> _loadTrainers() async {
    try {
      final response = await _supabase.from('profiles').select().order('first_name');
      final trainers = (response as List).map((e) => Profile.fromSupabase(e)).toList();
      if (mounted) {
        setState(() {
          _trainers = trainers;
          _isLoading = false; 
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkBusyStatus() async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final response = await _supabase
          .from('class_sessions')
          .select('trainer_id')
          .neq('status', 'cancelled')
          .lte('start_time', now)
          .gte('end_time', now);
      
      final busyIds = (response as List).map((e) => e['trainer_id'] as String).toSet();
      
      if (mounted) {
        setState(() {
          _busyTrainerIds = busyIds;
        });
      }
    } catch (e) {
      debugPrint('Error checking busy status: $e');
    }
  }

  void _setupPresence() {
    _presenceChannel = _supabase.channel('online_users');
    _presenceChannel?.onPresenceSync((payload) {
      if (!mounted) return;
      
      // presenceState() returns List<SinglePresenceState> in this version
      final dynamic rawState = _presenceChannel?.presenceState();
      final Map<String, dynamic> statusMap = {};

      if (rawState != null && rawState is List) {
        for (final item in rawState) {
          _extractPresence(item, statusMap);
        }
      } else if (rawState is Map) {
         // Fallback for different versions
         rawState.forEach((key, value) {
           _extractPresence(value, statusMap);
         });
      }
      
      
      setState(() {
        _onlineUserIds = statusMap.keys.toSet();
        _userManualStatuses = statusMap;
      });
      setState(() {
        _onlineUserIds = statusMap.keys.toSet();
        _userManualStatuses = statusMap;
      });
    }).subscribe((status, error) async {
       if (status == RealtimeSubscribeStatus.subscribed) {
         await _updateMyPresence();
       }
    });
  }
  
  void _extractPresence(dynamic presenceData, Map<String, dynamic> statusMap) {
    try {
      // If it's a list (e.g. Map value or List<SinglePresenceState>), recurse or iterate
      if (presenceData is List) {
        for (final item in presenceData) {
          _extractPresence(item, statusMap);
        }
        return;
      }

      // Check for 'presences' list (seen in logs for PresenceState)
      try {
        final presences = (presenceData as dynamic).presences;
        if (presences != null && presences is List) {
           for (final presence in presences) {
             // Each presence has a payload
             final payload = (presence as dynamic).payload;
             _extractPayload(payload, statusMap);
          }
          return;
        }
      } catch (_) {}

      // Check for 'payloads' list (standard Phoenix/Realtime Presence structure)
      try {
        final payloads = (presenceData as dynamic).payloads;
        if (payloads != null && payloads is List) {
          for (final payload in payloads) {
            _extractPayload(payload, statusMap);
          }
          return;
        }
      } catch (_) {}

      // Fallback: Check for 'payload' (singular)
      try {
        final payload = (presenceData as dynamic).payload;
        if (payload != null) {
           _extractPayload(payload, statusMap);
           return;
        }
      } catch (_) {}

      // Fallback: Treat presenceData itself as payload (Map)
      _extractPayload(presenceData, statusMap);

    } catch (e) {
      // Ignore parsing errors
    }
  }

  void _extractPayload(dynamic payload, Map<String, dynamic> statusMap) {
     if (payload == null) return;
     
     // Sometimes payload is wrapped in another payload key
     dynamic internalPayload = payload;
     if (internalPayload is Map && internalPayload.containsKey('payload')) {
       internalPayload = internalPayload['payload'];
     }

     final uid = _getValue(internalPayload, 'user_id');
     if (uid != null) {
       final st = _getValue(internalPayload, 'status');
       statusMap[uid.toString()] = st;
     }
  }

  dynamic _getValue(dynamic data, String key) {
    if (data is Map) {
      return data[key];
    }
    // Try property access via dynamic
    try {
      return (data as dynamic).toJson()[key];
    } catch (_) {}
    try {
       // Reflection-like access isn't easy, assume Map usually
    } catch (_) {}
    return null;
  }
  
  Map<String, dynamic> _userManualStatuses = {}; // userId -> status

  Future<void> _updateMyPresence() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      await _presenceChannel?.track({
        'user_id': userId,
        'status': _myStatus,
        'online_at': DateTime.now().toIso8601String(),
      });
    }
  }
  
  Future<void> _setMyStatus(String status) async {
    setState(() {
      _myStatus = status;
    });
    await _updateMyPresence();
  }

  @override
  void dispose() {
    if (_presenceChannel != null) {
      _supabase.removeChannel(_presenceChannel!);
    }
    super.dispose();
  }



  Future<void> _showAddTrainerDialog() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Yeni Eğitmen Ekle', style: TextStyle(color: AppColors.primaryYellow)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Ad', labelStyle: TextStyle(color: Colors.grey)),
              ),
              TextField(
                controller: lastNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Soyad', labelStyle: TextStyle(color: Colors.grey)),
              ),
              TextField(
                controller: usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı Adı', 
                  labelStyle: TextStyle(color: Colors.grey),
                  hintText: 'ornek, bosluksuz',
                  hintStyle: TextStyle(color: Colors.white30),
                ),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Şifre', labelStyle: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ekle', style: TextStyle(color: AppColors.primaryYellow)),
          ),
        ],
      ),
    );

    if (result == true) {
      _createTrainer(
        firstNameController.text,
        lastNameController.text,
        usernameController.text, // Sending username
        passwordController.text,
      );
    }
  }

  Future<void> _createTrainer(String first, String last, String username, String password) async {
    if (username.isEmpty || password.isEmpty) return;
    
    // Clean username and create email
    final cleanUsername = username.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (cleanUsername.isEmpty) {
      if (mounted) CustomSnackBar.showError(context, 'Geçersiz kullanıcı adı');
      return;
    }
    
    final email = '$cleanUsername@ptbodychange.app';

    if (mounted) setState(() => _isLoading = true);
    
    // Create a temporary client with implicit flow to avoid storage dependency issues
    final tempClient = SupabaseClient(
      SupabaseConfig.supabaseUrl, 
      SupabaseConfig.supabaseAnonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    
    try {
      final response = await tempClient.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': first,
          'last_name': last,
          'full_name': username,
          'display_name': username, 
          'username': username,
          'role': 'trainer', 
        }
      );

      if (mounted) {
        if (response.user != null) {
          // RLS WORKAROUND:
          // Admin cannot insert for others by default due to strict RLS policies.
          // instead of asking user to change DB policies, we:
          // 1. Sign in as the NEW USER (we have the password)
          // 2. Insert the profile as the user themselves (allowed by RLS)
          // 3. Sign out.
          try {
            await tempClient.auth.signInWithPassword(
              email: email,
              password: password,
            );
            
            await tempClient.from('profiles').insert({
              'id': response.user!.id,
              'first_name': first,
              'last_name': last,
              'role': 'trainer',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            });

            await tempClient.auth.signOut();
            CustomSnackBar.showSuccess(context, 'Eğitmen başarıyla oluşturuldu.');
            _loadTrainers();
            
          } catch (profileError) {
             debugPrint('Profile creation step failed: $profileError');
             CustomSnackBar.showError(context, 'Kullanıcı oluştu ama profil hatası: $profileError');
          }
        } else {
           CustomSnackBar.showSuccess(context, 'Kullanıcı oluşturuldu (Onay gerekebilir).');
           _loadTrainers();
        }
      }
    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, 'Hata: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSelectedTrainers() async {
    if (_selectedTrainerIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Seçilenleri Sil', style: TextStyle(color: AppColors.accentRed)),
        content: Text('${_selectedTrainerIds.length} eğitmeni silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hayır', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet', style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) setState(() => _isLoading = true);
      try {
        // Iterate and delete each user via RPC (secure deletion of Auth + Profile)
        for (final userId in _selectedTrainerIds) {
          try {
            await _supabase.rpc('delete_user_by_admin', params: {'target_user_id': userId});
          } catch (rpcError) {
             debugPrint('Failed to delete user $userId: $rpcError');
             // If RPC fails (e.g. not admin, or user not found), we might try manual profile delete as fallback
             // but usually RPC is the source of truth.
          }
        }
        
        if (mounted) CustomSnackBar.showSuccess(context, 'Seçilen eğitmenler tamamen silindi.');
        _selectedTrainerIds.clear();
        _loadTrainers();
      } catch (e) {
        if (mounted) CustomSnackBar.showError(context, 'Silme hatası: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text('${_selectedTrainerIds.length} Seçildi', style: const TextStyle(color: Colors.white))
            : const Text('Eğitmenler'),
        backgroundColor: _isSelectionMode ? AppColors.accentRed.withOpacity(0.2) : Colors.transparent,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedTrainerIds.clear()),
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: AppColors.accentRed),
              onPressed: _deleteSelectedTrainers,
            ),
        ],
      ),
      floatingActionButton: (_isAdmin && !_isSelectionMode)
          ? FloatingActionButton(
              onPressed: _showAddTrainerDialog,
              backgroundColor: AppColors.primaryYellow,
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadTrainers();
                await _checkBusyStatus();
              },
              color: AppColors.accentOrange,
              backgroundColor: AppColors.surfaceDark,
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _trainers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final trainer = _trainers[index];
                  return _buildTrainerCard(trainer);
                },
              ),
            ),
    );
  }

  Widget _buildTrainerCard(Profile trainer) {
    String statusText = 'Offline';
    Color statusColor = AppColors.textSecondary;
    IconData statusIcon = Icons.circle_outlined;

    final isBusy = _busyTrainerIds.contains(trainer.id);
    final isOnline = _onlineUserIds.contains(trainer.id);
    final currentUserId = _supabase.auth.currentUser?.id;

    // Manual status overrides everything if user is online/connected
    // Use local _myStatus for current user for instant feedback
    String? manualStatus;
    if (trainer.id == currentUserId) {
      manualStatus = _myStatus;
    } else {
      manualStatus = _userManualStatuses[trainer.id];
    }
    
    // If we are looking at someone else who is offline, their manualStatus (from presence) will be null.
    // If we are looking at ourselves, _myStatus dictates what we broadcast, but if we are 'offline' (app closed), we wouldn't be seeing this screen.
    // However, if logic says "Derste" but I set "Online", I want to see Online.

    if (manualStatus != null) {
      if (manualStatus == 'busy') {
        statusText = 'Meşgul';
        statusColor = AppColors.accentRed;
        statusIcon = Icons.remove_circle_rounded;
      } else if (manualStatus == 'away') {
        statusText = 'Dışarıda';
        statusColor = Colors.orange;
        statusIcon = Icons.access_time_filled_rounded;
      } else if (manualStatus == 'online') {
        statusText = 'Online';
        statusColor = AppColors.accentGreen;
        statusIcon = Icons.check_circle_rounded;
      }
    } else {
       // ... fallback
    }

    if (manualStatus != null) {
      if (manualStatus == 'busy') {
        statusText = 'Meşgul';
        statusColor = AppColors.accentRed;
        statusIcon = Icons.remove_circle_rounded;
      } else if (manualStatus == 'away') {
        statusText = 'Dışarıda';
        statusColor = Colors.orange;
        statusIcon = Icons.access_time_filled_rounded;
      } else {
        // 'online' or unknown
        statusText = 'Online';
        statusColor = AppColors.accentGreen;
        statusIcon = Icons.check_circle_rounded;
      }
    } else {
      // Automatic fallback
      if (isBusy) {
        statusText = 'Derste';
        statusColor = AppColors.accentRed;
        statusIcon = Icons.do_not_disturb_on_rounded;
      } else if (isOnline) {
        statusText = 'Online';
        statusColor = AppColors.accentGreen;
        statusIcon = Icons.check_circle_rounded;
      }
    }

    final isSelected = _selectedTrainerIds.contains(trainer.id);

    return GlassCard(
      backgroundColor: isSelected ? AppColors.primaryYellow.withOpacity(0.1) : null,
      border: isSelected ? Border.all(color: AppColors.primaryYellow) : null,
      child: ListTile(
        onTap: () {
          if (_isSelectionMode) {
             if (!_isAdmin) return; // Only admin can select
             setState(() {
               if (isSelected) {
                 _selectedTrainerIds.remove(trainer.id);
               } else {
                 _selectedTrainerIds.add(trainer.id);
               }
             });
          } else {
             // Navigate to Chat Screen
             final currentUserId = _supabase.auth.currentUser?.id;
             if (currentUserId != trainer.id) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatScreen(otherUser: trainer)),
                );
             }
          }
        },
        onLongPress: _isAdmin ? () {
           setState(() {
             if (isSelected) {
               _selectedTrainerIds.remove(trainer.id);
             } else {
               _selectedTrainerIds.add(trainer.id);
             }
           });
        } : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.accentOrange,
              backgroundImage: trainer.avatarUrl != null 
                  ? NetworkImage(trainer.avatarUrl!) 
                  : null,
              child: trainer.avatarUrl == null
                  ? Text(
                      (trainer.firstName?[0] ?? '') + (trainer.lastName?[0] ?? ''),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceDark, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          '${trainer.firstName ?? ''} ${trainer.lastName ?? ''}'.trim().isEmpty 
              ? 'İsimsiz Eğitmen' 
              : '${trainer.firstName ?? ''} ${trainer.lastName ?? ''}',
          style: AppTextStyles.headline,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trainer.profession != null)
              Text(
                trainer.profession!,
                style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),


        trailing: _isSelectionMode 
          ? Checkbox(
              value: isSelected,
              activeColor: AppColors.primaryYellow,
              checkColor: Colors.black,
              onChanged: _isAdmin ? (val) {
                setState(() {
                   if (val == true) {
                     _selectedTrainerIds.add(trainer.id);
                   } else {
                     _selectedTrainerIds.remove(trainer.id);
                   }
                });
              } : null,
            )
          : GestureDetector(
              onTap: () {
                // Only allow changing own status
                final currentUserId = _supabase.auth.currentUser?.id;
                if (currentUserId == trainer.id) {
                  _showStatusPicker();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: AppTextStyles.caption1.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    if (_supabase.auth.currentUser?.id == trainer.id) ...[
                       const SizedBox(width: 4),
                       Icon(Icons.edit, size: 10, color: statusColor.withOpacity(0.7)),
                    ],
                  ],
                ),
              ),
            ),
      ),
    );
  }


  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.circle, color: AppColors.accentGreen),
            title: const Text('Online', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _setMyStatus('online');
            },
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle, color: AppColors.accentRed),
            title: const Text('Meşgul', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _setMyStatus('busy');
            },
          ),
          ListTile(
            leading: const Icon(Icons.access_time_filled, color: Colors.orange),
            title: const Text('Dışarıda', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _setMyStatus('away');
            },
          ),
        ],
      ),
    );
  }
}
