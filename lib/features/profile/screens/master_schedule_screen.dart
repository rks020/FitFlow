import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_snackbar.dart';

class MasterScheduleScreen extends StatefulWidget {
  const MasterScheduleScreen({super.key});

  @override
  State<MasterScheduleScreen> createState() => _MasterScheduleScreenState();
}

class _MasterScheduleScreenState extends State<MasterScheduleScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _orgId;
  String? _trainerId;

  final List<String> _days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  // Use local time for template calculation to match grid labels (7-23)
  final DateTime _templateStart = DateTime(2024, 1, 1);
  Map<int, List<Map<String, dynamic>>> _sessionsByDay = {
    0: [], 1: [], 2: [], 3: [], 4: [], 5: [], 6: []
  };

  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final profilePath = await _supabase.from('profiles').select('organization_id, role').eq('id', user.id).single();
      _orgId = profilePath['organization_id'];
      final role = profilePath['role'];
      _trainerId = (role == 'trainer') ? user.id : null;
      // Note: class_sessions table does NOT have organization_id. 
      // We will fetch all templates for now.

      await _fetchTemplateSessions();
    } catch (e) {
      debugPrint('Load Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTemplateSessions() async {
    try {
      // Fetch templates for the 2024-01-01 to 2024-01-08 range
      // The range is broad to capture all timezone-shifted template records
      final startRange = DateTime.utc(2023, 12, 31);
      final endRange = DateTime.utc(2024, 1, 10);

      var query = _supabase
          .from('class_sessions')
          .select('id, title, start_time, end_time, color, status, is_template, template_id, trainer_id')
          .gte('start_time', startRange.toIso8601String())
          .lt('start_time', endRange.toIso8601String())
          .eq('is_template', true);

      if (_trainerId != null) query = query.eq('trainer_id', _trainerId!);

      final data = await query;
      debugPrint('Template sessions fetched: ${data.length}');

      final Map<int, List<Map<String, dynamic>>> newMap = {0: [], 1: [], 2: [], 3: [], 4: [], 5: [], 6: []};

      for (var item in data) {
        final start = DateTime.parse(item['start_time']).toLocal();
        // Calculate diff relative to our local template start (Monday)
        final diff = start.difference(_templateStart).inDays;
        debugPrint('  ${item["title"]} → Local start=$start diff=$diff');
        if (diff >= 0 && diff <= 6) newMap[diff]!.add(item);
      }

      setState(() { _sessionsByDay = newMap; });
    } catch (e) {
      debugPrint('Fetch Sessions Error: $e');
    }
  }

  Future<void> _moveSession(Map<String, dynamic> session, int targetDay, int targetHour) async {
    setState(() => _isLoading = true);
    try {
      final oldStart = DateTime.parse(session['start_time']).toLocal();
      final oldEnd = DateTime.parse(session['end_time']).toLocal();
      final duration = oldEnd.difference(oldStart);

      final dayDate = _templateStart.add(Duration(days: targetDay));
      final newStartLocal = DateTime(dayDate.year, dayDate.month, dayDate.day, targetHour, oldStart.minute);
      final newEndLocal = newStartLocal.add(duration);

      await _supabase.from('class_sessions').update({
        'start_time': newStartLocal.toUtc().toIso8601String(),
        'end_time': newEndLocal.toUtc().toIso8601String(),
      }).eq('id', session['id']);

      if (mounted) CustomSnackBar.showSuccess(context, 'Randevu taşındı');
      await _fetchTemplateSessions();
    } catch (e) {
      debugPrint('Move Error: $e');
      if (mounted) CustomSnackBar.showError(context, 'Taşıma başarısız oldu');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _blockTimeSlot(int dayIndex, int startHour, {int durationHours = 1}) async {
    setState(() => _isLoading = true);
    try {
      final dayDate = _templateStart.add(Duration(days: dayIndex));
      final startTimeLocal = DateTime(dayDate.year, dayDate.month, dayDate.day, startHour);
      final endTimeLocal = startTimeLocal.add(Duration(hours: durationHours));
      
      final startTimeStr = startTimeLocal.toUtc().toIso8601String();
      final endTimeStr = endTimeLocal.toUtc().toIso8601String();
      final templateData = {
        'title': 'Kapalı Slot',
        'start_time': startTimeStr,
        'end_time': endTimeStr,
        'trainer_id': _trainerId ?? _supabase.auth.currentUser!.id,
        'color': '#4B5563',
        'status': 'scheduled',
        'is_template': true,
        'template_id': null
      };

      await _supabase.from('class_sessions').insert(templateData);
      if (mounted) CustomSnackBar.showSuccess(context, 'Saat kapatıldı');
      await _fetchTemplateSessions();
    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, 'Hata oluştu.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEmptySlotOptions(int dayIndex, int hour) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AddSessionForm(
          dayIndex: dayIndex,
          startHour: hour,
          trainerId: _trainerId ?? _supabase.auth.currentUser!.id,
          orgId: _orgId!,
          templateStart: _templateStart,
          onSaved: () {
            Navigator.pop(context);
            _loadData();
          },
          onBlockRequested: () {
            Navigator.pop(context);
            _blockTimeSlot(dayIndex, hour, durationHours: 1);
          },
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    const double colWidth = 100.0;
    const double rowHeight = 60.0;
    const double timeColWidth = 50.0;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Sabit Randevu Listesi'),
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
            : Column(
                children: [
                  Expanded(
                    child: InteractiveViewer(
                      constrained: false,
                      scaleEnabled: true,
                      minScale: 0.5,
                      maxScale: 2.5,
                      child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: timeColWidth,
                              child: Column(
                                children: [
                                  Container(height: 50, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10)))),
                                  for (int h = 7; h <= 23; h++)
                                    Container(
                                      height: rowHeight,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Colors.white10), right: BorderSide(color: Colors.white10)),
                                      ),
                                      child: Text('${h.toString().padLeft(2, '0')}:00', style: AppTextStyles.caption2.copyWith(color: AppColors.textSecondary)),
                                    ),
                                ],
                              ),
                            ),
                            for (int dayIndex = 0; dayIndex < 7; dayIndex++)
                              SizedBox(
                                width: colWidth,
                                child: Column(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _showDayOptions(dayIndex),
                                      child: Container(
                                        width: colWidth,
                                        height: 50,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          border: Border(bottom: BorderSide(color: Colors.white12), right: BorderSide(color: Colors.white12)),
                                        ),
                                        child: Text(_days[dayIndex], style: const TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    for (int h = 7; h <= 23; h++)
                                      _buildGridCell(dayIndex, h, rowHeight, colWidth),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    ), // InteractiveViewer
                  ),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildGridCell(int dayIndex, int hour, double rowHeight, double colWidth) {
    final sessionList = _sessionsByDay[dayIndex]!;
    final sessionsInHour = sessionList.where((s) {
      final start = DateTime.parse(s['start_time']).toLocal();
      final end = DateTime.parse(s['end_time']).toLocal();
      return start.hour <= hour && (end.hour > hour || (end.hour == hour && end.minute > 0));
    }).toList();

    // Box Decoration for grid alignment
    final decoration = const BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Colors.white10),
        right: BorderSide(color: Colors.white10),
      ),
    );

    return DragTarget<Map<String, dynamic>>(
      onWillAccept: (data) => data != null,
      onAccept: (session) => _moveSession(session, dayIndex, hour),
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;

        if (sessionsInHour.isNotEmpty) {
          return Container(
            height: rowHeight,
            decoration: decoration.copyWith(
              color: isOver ? AppColors.primaryYellow.withOpacity(0.1) : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: sessionsInHour.map((s) {
                final title = (s['title'] ?? '').toString();
                final colorStr = s['color']?.toString().replaceFirst('#', '0xFF') ?? '0xFFFACC15';
                
                final sessionWidget = Container(
                  margin: const EdgeInsets.all(1),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(int.parse(colorStr)).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w700),
                    ),
                  ),
                );

                return Expanded(
                  child: LongPressDraggable<Map<String, dynamic>>(
                    data: s,
                    feedback: SizedBox(
                      width: colWidth * 0.8,
                      height: rowHeight * 0.8,
                      child: Material(
                        color: Colors.transparent,
                        child: Opacity(opacity: 0.7, child: sessionWidget),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.3, child: sessionWidget),
                    child: GestureDetector(
                      onTap: () => _showSessionDetails(s),
                      child: sessionWidget,
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        } else {
          return InkWell(
            onTap: () => _showEmptySlotOptions(dayIndex, hour),
            child: Container(
              height: rowHeight,
              decoration: decoration.copyWith(
                color: isOver ? AppColors.primaryYellow.withOpacity(0.2) : null,
              ),
              child: isOver ? const Icon(Icons.add_circle_outline, color: AppColors.primaryYellow, size: 20) : null,
            ),
          );
        }
      },
    );
  }

  void _showDayOptions(int dayIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: Text('${_days[dayIndex]} Günü Kapat (07:00 - 23:00)', style: const TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _blockWholeDay(dayIndex);
            },
          ),
          const SizedBox(height: 20),
        ],
      )
    );
  }

  Future<void> _blockWholeDay(int dayIndex) async {
    _blockTimeSlot(dayIndex, 7, durationHours: 16);
  }

  void _showSessionDetails(Map<String, dynamic> session) async {
    // Show loading state or fetch members immediately
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _EditSessionForm(
          session: session,
          onUpdate: (newData) async {
            await _handleUpdate(session, newData);
            _fetchTemplateSessions(); // Refresh grid
          },
          onDelete: () async {
            await _handleDelete(session);
            _fetchTemplateSessions(); // Refresh grid
          },
        ),
      ),
    );
  }

  Future<void> _handleUpdate(Map<String, dynamic> session, Map<String, dynamic> newData) async {
    try {
      final String sessionId = session['id'];

      // Update basic fields
      await _supabase.from('class_sessions').update({
        'title': newData['title'],
        'color': newData['color'],
        'trainer_id': newData['trainer_id'],
      }).eq('id', sessionId);

      // Sync members for this session
      if (newData.containsKey('selectedMemberIds')) {
        final List<String> memberIds = List<String>.from(newData['selectedMemberIds']);
        await _syncSessionMembers(sessionId, memberIds);
      }

      CustomSnackBar.showSuccess(context, 'Ders güncellendi.');
    } catch (e) {
      CustomSnackBar.showError(context, 'Güncelleme sırasında hata oluştu: $e');
    }
  }

  Future<void> _handleDelete(Map<String, dynamic> session) async {
    try {
      final String sessionId = session['id'];
      await _supabase.from('class_sessions').delete().eq('id', sessionId);
      CustomSnackBar.showSuccess(context, 'Ders silindi.');
    } catch (e) {
      CustomSnackBar.showError(context, 'Silme sırasında hata oluştu: $e');
    }
  }

  Future<void> _syncSessionMembers(String sessionId, List<String> memberIds) async {
     // 1. Delete existing
     await _supabase.from('class_enrollments').delete().eq('class_id', sessionId);
     // 2. Insert new
     if (memberIds.isNotEmpty) {
       final inserts = memberIds.map((mId) => {
         'class_id': sessionId,
         'member_id': mId,
         'status': 'booked'
       }).toList();
       await _supabase.from('class_enrollments').insert(inserts);
     }
  }
}

class _EditSessionForm extends StatefulWidget {
  final Map<String, dynamic> session;
  final Function(Map<String, dynamic> newData) onUpdate;
  final Function() onDelete;

  const _EditSessionForm({
    required this.session,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_EditSessionForm> createState() => _EditSessionFormState();
}

class _EditSessionFormState extends State<_EditSessionForm> {
  late TextEditingController _titleController;
  late String _selectedColor;
  String? _selectedTrainerId;
  List<Map<String, dynamic>> _trainers = [];
  List<Map<String, dynamic>> _members = [];
  List<String> _selectedMemberIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.session['title']);
    _selectedColor = widget.session['color'] ?? '#FACC15';
    _selectedTrainerId = widget.session['trainer_id'];
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final supabase = Supabase.instance.client;
      final orgResponse = await supabase.from('profiles').select('organization_id').eq('id', supabase.auth.currentUser!.id).single();
      final orgId = orgResponse['organization_id'];

      final trainersResponse = await supabase.from('profiles')
          .select('id, first_name, last_name')
          .eq('organization_id', orgId)
          .inFilter('role', ['trainer', 'admin', 'owner']);
      final membersResponse = await supabase.from('members').select('id, name').eq('organization_id', orgId).eq('is_active', true);
      
      // Load current enrollments
      final enrollmentsResponse = await supabase.from('class_enrollments').select('member_id').eq('class_id', widget.session['id']);
      final currentMemberIds = (enrollmentsResponse as List).map((e) => e['member_id'].toString()).toList();

      if (mounted) {
        setState(() {
          _trainers = List<Map<String, dynamic>>.from(trainersResponse);
          _members = List<Map<String, dynamic>>.from(membersResponse);
          _selectedMemberIds = currentMemberIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow));

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dersi Düzenle', style: AppTextStyles.title2.copyWith(color: Colors.white)),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _confirmDelete()),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Ders Adı',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.primaryYellow), borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          // Trainer Dropdown
          DropdownButtonFormField<String>(
            value: _selectedTrainerId,
            dropdownColor: AppColors.surfaceDark,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Eğitmen',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
            ),
            items: _trainers.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text('${t['first_name']} ${t['last_name']}'))).toList(),
            onChanged: (val) => setState(() => _selectedTrainerId = val),
          ),
          const SizedBox(height: 16),
          const Text('Renk Seçimi', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['#FACC15', '#06B6D4', '#8B5CF6', '#EC4899', '#10B981', '#F97316', '#4B5563'].map((color) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                      border: _selectedColor == color ? Border.all(color: Colors.white, width: 3) : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Üye Seçimi', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: _members.map((member) {
                final isSelected = _selectedMemberIds.contains(member['id']);
                return CheckboxListTile(
                  title: Text(member['name'], style: const TextStyle(color: Colors.white)),
                  value: isSelected,
                  activeColor: AppColors.primaryYellow,
                  checkColor: Colors.black,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) _selectedMemberIds.add(member['id']);
                      else _selectedMemberIds.remove(member['id']);
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Güncelle',
            onPressed: () => _submit(),
          ),
        ],
      ),
    );
  }

  void _submit() {
    String finalTitle = _titleController.text;
    
    // Auto-generate title if it's currently "Ders" or empty
    if (finalTitle.isEmpty || finalTitle == 'Ders') {
      if (_selectedMemberIds.isNotEmpty) {
        final selectedNames = _members
            .where((m) => _selectedMemberIds.contains(m['id']))
            .map((m) => m['name'] as String)
            .toList();
        finalTitle = selectedNames.join(' - ');
      } else {
        finalTitle = 'Kapalı Slot';
      }
    }

    widget.onUpdate({
      'title': finalTitle,
      'color': _selectedColor,
      'trainer_id': _selectedTrainerId,
      'selectedMemberIds': _selectedMemberIds,
    });
    Navigator.pop(context);
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Dersi Sil', style: TextStyle(color: Colors.white)),
        content: const Text('Bu dersi silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç', style: TextStyle(color: Colors.white))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
              Navigator.pop(context);
            }, 
            child: const Text('Sil', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _AddSessionForm extends StatefulWidget {
  final int dayIndex;
  final int startHour;
  final String trainerId;
  final String orgId;
  final DateTime templateStart;
  final VoidCallback onSaved;
  final VoidCallback onBlockRequested;

  const _AddSessionForm({
    required this.dayIndex,
    required this.startHour,
    required this.trainerId,
    required this.orgId,
    required this.templateStart,
    required this.onSaved,
    required this.onBlockRequested,
  });

  @override
  State<_AddSessionForm> createState() => _AddSessionFormState();
}

class _AddSessionFormState extends State<_AddSessionForm> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isEvent = false;
  String _selectedColor = '#FACC15'; // Default Yellow

  late TextEditingController _titleController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  
  List<Map<String, dynamic>> _members = [];
  List<String> _selectedMemberIds = [];

  final List<Map<String, dynamic>> _colors = [
    {'hex': '#06B6D4', 'color': Color(0xFF06B6D4)},
    {'hex': '#FACC15', 'color': Color(0xFFFACC15)},
    {'hex': '#10B981', 'color': Color(0xFF10B981)},
    {'hex': '#EF4444', 'color': Color(0xFFEF4444)},
    {'hex': '#8B5CF6', 'color': Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Ders');
    _startTime = TimeOfDay(hour: widget.startHour, minute: 0);
    _endTime = TimeOfDay(hour: widget.startHour + 1, minute: 0);
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    try {
      final res = await _supabase
          .from('members')
          .select('id, name')
          .eq('organization_id', widget.orgId)
          .eq('is_active', true);
      if (mounted) {
        setState(() { _members = List<Map<String, dynamic>>.from(res); });
      }
    } catch (e) {
      debugPrint('Error fetching members: $e');
    }
  }

  Future<void> _saveSession() async {
    setState(() => _isLoading = true);
    try {
      // 1. Determine Title automatically if it's still default
      String finalTitle = _titleController.text;
      String finalColor = _selectedColor;

      if (_selectedMemberIds.isNotEmpty) {
        final selectedNames = _members
            .where((m) => _selectedMemberIds.contains(m['id']))
            .map((m) => m['name'] as String)
            .toList();
        finalTitle = selectedNames.join(' - ');
      } else if (finalTitle == 'Ders') {
        finalTitle = 'Kapalı Slot';
        finalColor = '#4B5563'; // Grey for blocked slots
      }

      // 2. Setup Template Start (Anchor for grid)
      final startTimeTemplate = DateTime(
        widget.templateStart.year, 
        widget.templateStart.month, 
        widget.templateStart.day + widget.dayIndex, 
        _startTime.hour, 
        _startTime.minute
      );
      final endTimeTemplate = DateTime(
        widget.templateStart.year, 
        widget.templateStart.month, 
        widget.templateStart.day + widget.dayIndex, 
        _endTime.hour, 
        _endTime.minute
      );
      
      final templateData = {
        'title': finalTitle,
        'start_time': startTimeTemplate.toUtc().toIso8601String(),
        'end_time': endTimeTemplate.toUtc().toIso8601String(),
        'trainer_id': widget.trainerId,
        'color': finalColor,
        'status': 'scheduled',
        'is_template': true,
        'template_id': null
      };

      final insertedTemplate = await _supabase.from('class_sessions').insert(templateData).select().single();

      // Insert members if selected
      if (_selectedMemberIds.isNotEmpty) {
         List<Map<String, dynamic>> memberInserts = [];
         for (var mId in _selectedMemberIds) {
            memberInserts.add({
              'class_id': insertedTemplate['id'], 
              'member_id': mId,
              'status': 'booked'
            });
         }
         await _supabase.from('class_enrollments').insert(memberInserts);
      }

      CustomSnackBar.showSuccess(context, 'Ders başarıyla eklendi!');
      widget.onSaved();
    } catch (e) {
      debugPrint('Save Error: $e');
      CustomSnackBar.showError(context, 'Kaydedilirken hata oluştu.');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primaryYellow, surface: AppColors.surfaceDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startTime = picked;
        else _endTime = picked;
      });
    }
  }

  void _showMultiSelect() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceDark,
              title: Text('Üyeleri Seç', style: AppTextStyles.title3),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final m = _members[index];
                    final isChecked = _selectedMemberIds.contains(m['id']);
                    return CheckboxListTile(
                      title: Text(m['name'], style: const TextStyle(color: Colors.white)),
                      value: isChecked,
                      activeColor: AppColors.primaryYellow,
                      checkColor: Colors.black,
                      onChanged: (val) {
                        setDialogState(() {
                           if (val == true) _selectedMemberIds.add(m['id']);
                           else _selectedMemberIds.remove(m['id']);
                        });
                        setState((){});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(child: Text('Tamam', style: TextStyle(color: AppColors.primaryYellow)), onPressed: () => Navigator.pop(context))
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A), // Matches screenshot dark theme
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   const Icon(Icons.add, color: AppColors.textSecondary),
                   const SizedBox(width: 8),
                   Text('Yeni Ekle', style: AppTextStyles.title2.copyWith(color: AppColors.primaryYellow, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),

          // Tabs
          Container(
            height: 48,
            decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isEvent = false;
                      _titleController.text = 'Ders';
                    }),
                    child: Container(
                      decoration: BoxDecoration(
                        color: !_isEvent ? AppColors.primaryYellow : Colors.transparent,
                        borderRadius: BorderRadius.circular(12)
                      ),
                      alignment: Alignment.center,
                      child: Text('📋 Ders', style: TextStyle(color: !_isEvent ? Colors.black : AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    ),
                  )
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isEvent = true;
                      _titleController.text = 'Etkinlik';
                    }),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isEvent ? AppColors.primaryYellow : Colors.transparent,
                        borderRadius: BorderRadius.circular(12)
                      ),
                      alignment: Alignment.center,
                      child: Text('🎉 Etkinlik', style: TextStyle(color: _isEvent ? Colors.black : AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    ),
                  )
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Üye Seç (Birden fazla seçebilirsiniz)', style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _showMultiSelect,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(child: Text(_selectedMemberIds.isEmpty ? 'Üye ara...' : '${_selectedMemberIds.length} Üye Seçildi', style: TextStyle(color: _selectedMemberIds.isEmpty ? AppColors.textSecondary : Colors.white))),
                  const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('Renk', style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: _colors.map((c) => GestureDetector(
              onTap: () => setState(() => _selectedColor = c['hex']),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c['color'], shape: BoxShape.circle,
                  border: Border.all(color: _selectedColor == c['hex'] ? Colors.white : Colors.transparent, width: 2)
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),

          // Time Segment
          Row(
            children: [
               const Icon(Icons.access_time_rounded, color: AppColors.textSecondary),
               const SizedBox(width: 12),
               Expanded(
                 child: InkWell(
                    onTap: () => _selectTime(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_startTime.format(context), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const Icon(Icons.access_time, size: 16, color: Colors.white),
                        ],
                      ),
                    ),
                 ),
               ),
               const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('-', style: TextStyle(color: AppColors.textSecondary))),
               Expanded(
                 child: InkWell(
                    onTap: () => _selectTime(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_endTime.format(context), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const Icon(Icons.access_time, size: 16, color: Colors.white),
                        ],
                      ),
                    ),
                 ),
               ),
            ],
          ),
          const SizedBox(height: 24),

          _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow))
            : CustomButton(text: 'Kaydet', onPressed: _saveSession, backgroundColor: AppColors.primaryYellow, foregroundColor: Colors.black),
          
          const SizedBox(height: 16),
          // Block Hour Toggle / Expansion
          ExpansionTile(
            title: const Text('Gelişmiş Seçenekler', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            collapsedIconColor: AppColors.textSecondary,
            iconColor: AppColors.primaryYellow,
            children: [
               ListTile(
                  leading: const Icon(Icons.block, color: AppColors.accentRed),
                  title: const Text('Bu Saati Kapat', style: TextStyle(color: Colors.white)),
                  onTap: widget.onBlockRequested,
               )
            ],
          )
        ],
      ),
    );
  }
}
