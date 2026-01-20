import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../data/models/member.dart';
import '../../../data/models/measurement.dart';
import '../../../data/repositories/member_repository.dart';
import '../../../shared/widgets/custom_button.dart';
import 'progress_charts_screen.dart';
import 'measurement_comparison_screen.dart';
import 'dart:async';
import '../../../../shared/widgets/custom_snackbar.dart';
import '../../../../data/repositories/measurement_repository.dart';
import 'add_measurement_screen.dart';

class MemberMeasurementsScreen extends StatefulWidget {
  final String? memberId; // Optional: If provided, viewing that member. If null, view key user.

  const MemberMeasurementsScreen({super.key, this.memberId});

  @override
  State<MemberMeasurementsScreen> createState() => _MemberMeasurementsScreenState();
}

class _MemberMeasurementsScreenState extends State<MemberMeasurementsScreen> {
  final _supabase = Supabase.instance.client;
  final _repository = MeasurementRepository();
  List<dynamic> _measurements = [];
  bool _isLoading = true;
  final Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;
  Member? _member;

  StreamSubscription? _measSubscription;

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
    _loadMember();
    _subscribeToMeasurements();
  }

  @override
  void dispose() {
    _measSubscription?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToMeasurements() async {
    final targetUserId = widget.memberId ?? _supabase.auth.currentUser?.id;
    if (targetUserId == null) return;

    _measSubscription = _supabase
        .from('measurements')
        .stream(primaryKey: ['id'])
        .eq('member_id', targetUserId)
        .listen((data) {
          _loadMeasurements();
        });
  }

  Future<void> _loadMember() async {
    if (widget.memberId == null) return;
    
    try {
      final member = await MemberRepository().getById(widget.memberId!);
      if (mounted) {
        setState(() {
          _member = member;
        });
      }
    } catch (e) {
      debugPrint('Error loading member: $e');
    }
  }

  Future<void> _loadMeasurements() async {
    try {
      final targetUserId = widget.memberId ?? _supabase.auth.currentUser?.id;
      if (targetUserId == null) return;

      final response = await _supabase
          .from('measurements')
          .select()
          .eq('member_id', targetUserId)
          .order('measurement_date', ascending: true); // Ascending for Chart

      if (mounted) {
        setState(() {
          _measurements = response as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading measurements: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openDetailedAnalysis() async {
    try {
      final user = _supabase.auth.currentUser;
      final targetId = widget.memberId ?? user?.id;
      
      if (targetId == null) return;

      final member = await MemberRepository().getById(targetId);
      
      if (member != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProgressChartsScreen(member: member),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _deleteMeasurement(String measurementId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text('Ölçümü Sil', style: AppTextStyles.title3),
        content: Text('Bu ölçüm kaydını silmek istediğinize emin misiniz?', style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal', style: AppTextStyles.callout),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentRed),
            child: Text('Sil', style: AppTextStyles.callout),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.delete(measurementId);
        _loadMeasurements();
        if (mounted) CustomSnackBar.showSuccess(context, 'Ölçüm silindi.');
      } catch (e) {
        if (mounted) CustomSnackBar.showError(context, 'Silme hatası: $e');
      }
    }
  }

  void _editMeasurement(Measurement measurement) async {
    // Need to fetch member object first if we don't have it fully populated,
    // but we likely have it from widget.memberId context or we can create a temporary one
    // Actually MemberMeasurementsScreen is usually pushed with a Member object if called from Trainer side?
    // Let's check constructor. It usually takes memberId.
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Prepare data for chart (Weight progress)
    // final weightSpots = _measurements.asMap().entries.map((entry) {
    //     final m = entry.value;
    //     final weight = (m['weight'] as num?)?.toDouble() ?? 0.0;
    //     return FlSpot(entry.key.toDouble(), weight);
    // }).toList();

    final String title = widget.memberId != null && _member != null
        ? '${_member!.name} Ölçümleri'
        : 'Gelişim Analizim';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        leading: widget.memberId != null 
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            )
          : null,
        actions: widget.memberId == null
          ? [
              TextButton.icon(
                onPressed: _openDetailedAnalysis,
                icon: const Icon(Icons.analytics_outlined, color: AppColors.primaryYellow, size: 20),
                label: const Text('Detaylı Analiz', style: TextStyle(color: AppColors.primaryYellow, fontSize: 12)),
              ),
            ]
          : null,
      ),
      body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            // Weight Chart removed as per request
            // if (widget.memberId == null && weightSpots.isNotEmpty) ...

            const SizedBox(height: 24),
            
            // Selection mode header
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedIndices.clear();
                        });
                      },
                    ),
                    Text(
                      '${_selectedIndices.length} Seçildi',
                      style: AppTextStyles.headline,
                    ),
                    TextButton.icon(
                      onPressed: _selectedIndices.length == 2 ? () {
                        final indices = _selectedIndices.toList()..sort();
                        final m1 = Measurement.fromSupabaseMap(_measurements[indices[0]]);
                        final m2 = Measurement.fromSupabaseMap(_measurements[indices[1]]);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MeasurementComparisonScreen(
                              oldMeasurement: m1,
                              newMeasurement: m2,
                            ),
                          ),
                        );
                      } : null,
                      icon: const Icon(Icons.compare_arrows, color: AppColors.primaryYellow),
                      label: const Text('Karşılaştır', style: TextStyle(color: AppColors.primaryYellow)),
                    ),
                  ],
                ),
              ),
            
            Text('Ölçüm Geçmişi', style: AppTextStyles.title3),
            const SizedBox(height: 12),
            
            // History List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMeasurements,
                color: AppColors.primaryYellow,
                backgroundColor: AppColors.surfaceDark,
                child: _measurements.isEmpty 
                 ? Stack(
                    children: [
                      ListView(),
                      Center(child: Text('Henüz ölçüm yok', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary))),
                    ], 
                   )
                 : Stack(
                    children: [
                      ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _measurements.length,
                      itemBuilder: (context, index) {
                        final currentIdx = _measurements.length - 1 - index;
                        final m = _measurements[currentIdx];
                        final date = DateTime.parse(m['measurement_date']);
                        final isSelected = _selectedIndices.contains(currentIdx);
                        
                        return GlassCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          onTap: () {
                            if (_isSelectionMode) {
                              setState(() {
                                if (isSelected) {
                                  _selectedIndices.remove(currentIdx);
                                  if (_selectedIndices.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  if (_selectedIndices.length < 2) {
                                    _selectedIndices.add(currentIdx);
                                  }
                                }
                              });
                            } else {
                              setState(() {
                                _isSelectionMode = true;
                                _selectedIndices.add(currentIdx);
                              });
                            }
                          },
                          backgroundColor: isSelected ? AppColors.primaryYellow.withOpacity(0.15) : null,
                          border: isSelected ? Border.all(color: AppColors.primaryYellow, width: 2) : null,
                          child: Row(
                            children: [
                              // Selection indicator
                              if (_isSelectionMode)
                                Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Icon(
                                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                                    color: isSelected ? AppColors.primaryYellow : Colors.white54,
                                    size: 24,
                                  ),
                                ),
                              
                              // Profile icon
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceDark,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.person, color: Colors.white54, size: 20),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // Date and metrics
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('dd MMMM yyyy', 'tr_TR').format(date),
                                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryYellow.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Kilo: ${m['weight'] ?? '-'} kg',
                                            style: const TextStyle(
                                              color: AppColors.primaryYellow,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Yağ: %${m['body_fat_percentage'] ?? '-'}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Actions for Trainer, Arrow for Member
                              if (widget.memberId != null && !_isSelectionMode)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                                  color: AppColors.surfaceDark,
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                        // We need the Member object. 
                                        // Since we only have memberId in the widget, we might need to fetch it or pass it.
                                        // But wait, AddMeasurementScreen requires a Member object. 
                                        // We should probably construct a minimal Member object or fetch it.
                                        // For now, let's construct one with ID and Name (if available).
                                        // Actually the screen title usually has name if passed.
                                        // Let's assume we can pass a dummy Member with correct ID.
                                        final member = Member(
                                          id: widget.memberId!,
                                          name: 'Üye', // Placeholder, used for title potentially
                                          email: '',
                                          phone: '',
                                          joinDate: DateTime.now(),
                                        ); // Placeholder
                                        
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AddMeasurementScreen(
                                              member: member,
                                              existingMeasurement: Measurement.fromSupabaseMap(m),
                                            ),
                                          ),
                                        );

                                        if (result == true) {
                                          _loadMeasurements();
                                        }
                                    } else if (value == 'delete') {
                                      _deleteMeasurement(m['id']);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, color: AppColors.primaryYellow, size: 20),
                                          SizedBox(width: 8),
                                          Text('Düzenle', style: TextStyle(color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: AppColors.accentRed, size: 20),
                                          SizedBox(width: 8),
                                          Text('Sil', style: TextStyle(color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              else if (!_isSelectionMode)
                                const Icon(Icons.chevron_right, color: Colors.white54),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    // FAB for comparison
                    if (_selectedIndices.length == 2)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton.extended(
                          onPressed: () {
                            final indices = _selectedIndices.toList()..sort();
                            final m1 = Measurement.fromSupabaseMap(_measurements[indices[0]]);
                            final m2 = Measurement.fromSupabaseMap(_measurements[indices[1]]);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MeasurementComparisonScreen(
                                  oldMeasurement: m1,
                                  newMeasurement: m2,
                                ),
                              ),
                            );
                          },
                          backgroundColor: AppColors.primaryYellow,
                          icon: const Icon(Icons.compare_arrows, color: Colors.black),
                          label: const Text('Karşılaştır', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
             ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
