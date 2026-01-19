import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../data/models/member.dart';
import '../models/workout_model.dart';
import '../repositories/workout_repository.dart';
import '../repositories/workout_assignment_repository.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../data/models/class_session.dart';

class AssignWorkoutScreen extends StatefulWidget {
  final Member member;
  const AssignWorkoutScreen({super.key, required this.member});

  @override
  State<AssignWorkoutScreen> createState() => _AssignWorkoutScreenState();
}

class _AssignWorkoutScreenState extends State<AssignWorkoutScreen> {
  final _workoutRepo = WorkoutRepository();
  final _assignmentRepo = WorkoutAssignmentRepository();
  final _classRepo = ClassRepository();
  
  List<Workout> _workouts = [];
  List<ClassSession> _dailyClasses = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String? _selectedClassId; // If null, assign to date. If set, assign to class.

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadWorkouts(),
      _loadClasses(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadWorkouts() async {
    try {
      final workouts = await _workoutRepo.getWorkouts();
      if (mounted) setState(() => _workouts = workouts);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadClasses() async {
    try {
      // We need a method to get classes for a specific member and date.
      // _classRepo.getSessions returns all sessions.
      // _classRepo.getMemberUpcomingClasses returns upcoming.
      // We need something like "getMemberSessionsForDate".
      // Let's implement a quick custom fetch or reuse getSessions and filter locally (not efficient but works for now if sessions not huge).
      // Actually ClassRepository.getSessions(start, end) gets ALL sessions. 
      // We can filter by member enrollment? That's complex.
      // Better: Get member's enrolled classes for that day.
      final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final end = start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
      
      // We can use getSessions and check enrollments? 
      // Or simply add a method to ClassRepository? 
      // For now, let's use a workaround: Get ALL sessions for that trainer/gym for that day, then check enrollments?
      // No, let's just stick to "General Date Assignment" if we can't easily find the class.
      // BUT user specifically asked for it.
      // Let's use `getMemberUpcomingClasses` and filter for date? 
      final upcoming = await _classRepo.getMemberUpcomingClasses(widget.member.id);
      final relevant = upcoming.where((s) {
        return s.startTime.year == _selectedDate.year && 
               s.startTime.month == _selectedDate.month && 
               s.startTime.day == _selectedDate.day;
      }).toList();
      
      if (mounted) {
        setState(() {
          _dailyClasses = relevant;
          _selectedClassId = relevant.isNotEmpty ? relevant.first.id : null;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _assign(Workout workout) async {
    try {
       String targetText = _selectedClassId != null 
           ? 'Seçili derse (${DateFormat('HH:mm').format(_dailyClasses.firstWhere((c) => c.id == _selectedClassId).startTime)})' 
           : '${DateFormat('dd MMM yyyy', 'tr_TR').format(_selectedDate)} tarihine';

       // Show confirm
       final confirm = await showDialog<bool>(
         context: context,
         builder: (ctx) => AlertDialog(
           backgroundColor: AppColors.surfaceDark,
           title: Text('Programı Ata', style: AppTextStyles.headline.copyWith(color: Colors.white)),
           content: Text(
             '${workout.name} programını ${widget.member.name} kullanıcısının\n$targetText atamak istiyor musunuz?',
             style: const TextStyle(color: Colors.white),
           ),
           actions: [
             TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
             TextButton(
               onPressed: () => Navigator.pop(ctx, true),
               child: const Text('Ata', style: TextStyle(color: AppColors.primaryYellow)),
             ),
           ],
         ),
       );

       if (confirm == true) {
         if (_selectedClassId != null) {
           // Update Class Session
           final session = _dailyClasses.firstWhere((c) => c.id == _selectedClassId);
           // We need a method to update ONLY workout_id? Or update whole session.
           // Let's use updateSession but we need full object. session is full object.
           // We just modify workout details.
           final updated = ClassSession(
             id: session.id,
             title: session.title,
             description: session.description,
             startTime: session.startTime,
             endTime: session.endTime,
             capacity: session.capacity,
             trainerId: session.trainerId,
             status: session.status,
             isCancelled: session.isCancelled,
             trainerSignatureUrl: session.trainerSignatureUrl,
             workoutId: workout.id, // NEW
             workoutName: workout.name, 
           );
           await _classRepo.updateSession(updated);
         } else {
           // Standard assignment
           await _assignmentRepo.assignWorkout(
             memberId: widget.member.id,
             workoutId: workout.id,
             date: _selectedDate,
           );
         }
         
         if (mounted) {
           CustomSnackBar.showSuccess(context, 'Program başarıyla atandı');
           Navigator.pop(context, true);
         }
       }

    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, 'Hata: $e');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 0)), 
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryYellow,
              onPrimary: Colors.black,
              surface: AppColors.surfaceDark,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _isLoading = true;
      });
      await _loadClasses();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Program Ata: ${widget.member.name}', style: AppTextStyles.headline.copyWith(fontSize: 16)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Date Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surfaceDark,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tarih:', style: AppTextStyles.headline),
                    TextButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, color: AppColors.primaryYellow),
                      label: Text(
                        DateFormat('dd MMMM yyyy', 'tr_TR').format(_selectedDate),
                        style: const TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (_dailyClasses.isNotEmpty) ...[
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<String>(
                      value: _selectedClassId,
                      dropdownColor: AppColors.cardDark,
                      decoration: const InputDecoration(
                        labelText: 'İlgili Ders (Opsiyonel)',
                        labelStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.class_, color: AppColors.primaryYellow),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text("Derssiz Atama (Genel)"),
                        ),
                        ..._dailyClasses.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text("${DateFormat('HH:mm').format(c.startTime)} - ${c.title}"),
                        )),
                      ],
                      onChanged: (val) => setState(() => _selectedClassId = val),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _workouts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_add, size: 64, color: AppColors.textSecondary),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz oluşturulmuş program yok',
                            style: AppTextStyles.headline.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                             'Lütfen önce "Antrenman > Programlar"\nsekmesinden yeni bir program oluşturun.',
                             textAlign: TextAlign.center,
                             style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _workouts.length,
                  itemBuilder: (context, index) {
                    final workout = _workouts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          title: Text(workout.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${workout.exercises.length} Hareket • ${workout.difficulty ?? "Genel"}',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.primaryYellow, size: 16),
                          onTap: () => _assign(workout),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
