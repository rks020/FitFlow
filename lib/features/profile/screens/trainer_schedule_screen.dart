import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/class_session.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../shared/widgets/glass_card.dart';

class TrainerScheduleScreen extends StatefulWidget {
  const TrainerScheduleScreen({super.key});

  @override
  State<TrainerScheduleScreen> createState() => _TrainerScheduleScreenState();
}

class _TrainerScheduleScreenState extends State<TrainerScheduleScreen> {
  final _repository = ClassRepository();
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Map of date -> List of sessions
  Map<DateTime, List<ClassSession>> _events = {};
  List<ClassSession> _selectedDaySessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMonthSessions(_focusedDay);
  }

  Future<void> _loadMonthSessions(DateTime month) async {
    setState(() => _isLoading = true);

    // Get 1st day of month to last day
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    try {
      final sessions = await _repository.getSessions(firstDay, lastDay);
      
      final newEvents = <DateTime, List<ClassSession>>{};
      
      for (var session in sessions) {
        // Normalize date to remove time for key
        final date = DateTime(
          session.startTime.year, 
          session.startTime.month, 
          session.startTime.day
        );
        
        if (newEvents[date] == null) newEvents[date] = [];
        newEvents[date]!.add(session);
      }

      if (mounted) {
        setState(() {
          _events = newEvents;
          _isLoading = false;
        });
        _updateSelectedDaySessions(_selectedDay!);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateSelectedDaySessions(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    setState(() {
      _selectedDaySessions = _events[normalizedDay] ?? [];
      // Sort by time
      _selectedDaySessions.sort((a, b) => a.startTime.compareTo(b.startTime));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eğitmen Programı'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.primaryYellow,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Galaxy Calendar
          GlassCard(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.only(bottom: 8),
            child: TableCalendar(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _updateSelectedDaySessions(selectedDay);
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _loadMonthSessions(focusedDay);
              },
              eventLoader: (day) {
                final normalizedDay = DateTime(day.year, day.month, day.day);
                return _events[normalizedDay] ?? [];
              },
              
              // Styling
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: AppTextStyles.title3.copyWith(fontWeight: FontWeight.bold),
                leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.primaryYellow),
                rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.primaryYellow),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(color: Colors.white),
                weekendTextStyle: const TextStyle(color: AppColors.textSecondary),
                outsideTextStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primaryYellow,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                todayDecoration: BoxDecoration(
                  color: AppColors.primaryYellow.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: AppColors.accentBlue,
                  shape: BoxShape.circle,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: const TextStyle(color: AppColors.textSecondary),
                weekendStyle: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),

          const Divider(color: AppColors.glassBorder),
          
          // Event List
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _selectedDaySessions.isEmpty
                  ? Center(
                      child: Text(
                        'Bu tarihte planlanmış ders yok',
                        style: AppTextStyles.caption1,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _selectedDaySessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final session = _selectedDaySessions[index];
                        return _buildSessionItem(session);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(ClassSession session) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Time Column
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('HH:mm').format(session.startTime),
                style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('HH:mm').format(session.endTime),
                style: AppTextStyles.caption2,
              ),
            ],
          ),
          Container(
            height: 40,
            width: 1,
            color: AppColors.glassBorder,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: AppColors.accentBlue),
                    const SizedBox(width: 4),
                    Text(
                      'PT: ${session.trainerName ?? "-"}',
                      style: AppTextStyles.caption1.copyWith(color: AppColors.accentBlue),
                    ),
                  ],
                ),
                if (session.status == 'completed') ...[
                   const SizedBox(height: 4),
                   Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: AppColors.accentGreen),
                      const SizedBox(width: 4),
                       Text(
                        'Tamamlandı',
                        style: AppTextStyles.caption2.copyWith(color: AppColors.accentGreen),
                      ),
                    ],
                   ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}
