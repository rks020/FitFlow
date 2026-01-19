import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../data/models/member.dart';
import '../models/assigned_workout_model.dart';
import '../repositories/workout_assignment_repository.dart';
import '../../../data/repositories/class_repository.dart';
import '../../classes/screens/class_detail_screen.dart';
import 'workout_detail_screen.dart';

class MemberWorkoutsScreen extends StatefulWidget {
  final Member member;
  const MemberWorkoutsScreen({super.key, required this.member});

  @override
  State<MemberWorkoutsScreen> createState() => _MemberWorkoutsScreenState();
}

class _MemberWorkoutsScreenState extends State<MemberWorkoutsScreen> {
  final _repo = WorkoutAssignmentRepository();
  final _classRepo = ClassRepository();
  List<AssignedWorkout> _assignments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    try {
      final data = await _repo.getMemberWorkouts(widget.member.id);
      if (mounted) {
        setState(() {
          _assignments = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${widget.member.name} - Programlar', style: AppTextStyles.headline.copyWith(fontSize: 16)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
              ? Center(child: Text('Henüz program atanmamış.', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _assignments.length,
                  itemBuilder: (context, index) {
                    final assignment = _assignments[index];
                    final isCompleted = assignment.isCompleted;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          title: Text(
                            assignment.workoutName ?? 'Program', // Use the name from the model
                            style: AppTextStyles.headline.copyWith(
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                              color: isCompleted ? Colors.grey : Colors.white,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tarih: ${DateFormat('dd MMM yyyy', 'tr_TR').format(assignment.assignedDate)}',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                              if (assignment.source == 'class')
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryYellow.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Ders Programı', style: TextStyle(color: AppColors.primaryYellow, fontSize: 10)),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Icon(
                            isCompleted ? Icons.check_circle : Icons.circle_outlined,
                            color: isCompleted ? AppColors.accentGreen : AppColors.primaryYellow,
                          ),
                          onTap: () async {
                            if (assignment.source == 'class' && assignment.classSessionId != null) {
                              try {
                                showDialog(
                                  context: context, 
                                  barrierDismissible: false,
                                  builder: (_) => const Center(child: CircularProgressIndicator())
                                );
                                
                                final session = await _classRepo.getSession(assignment.classSessionId!);
                                if (!mounted) return;
                                Navigator.pop(context); // Close loading

                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ClassDetailScreen(session: session),
                                  ),
                                );
                              } catch (e) {
                                Navigator.pop(context); // Close loading
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                              }
                            } else {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WorkoutDetailScreen(assignmentId: assignment.id),
                                ),
                              );
                            }
                            _loadAssignments(); // Refresh on return
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
