import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/class_session.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/glass_card.dart';

class AddClassScreen extends StatefulWidget {
  final DateTime? initialDate;
  
  const AddClassScreen({super.key, this.initialDate});

  @override
  State<AddClassScreen> createState() => _AddClassScreenState();
}

class _AddClassScreenState extends State<AddClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ClassRepository();
  bool _isLoading = false;

  final _titleController = TextEditingController();
  final _capacityController = TextEditingController(text: '10');
  
  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  int _durationMinutes = 60;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }



  @override
  void dispose() {
    _titleController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = startDateTime.add(Duration(minutes: _durationMinutes));

      final session = ClassSession(
        title: _titleController.text,
        startTime: startDateTime,
        endTime: endDateTime,
        capacity: int.parse(_capacityController.text),
      );

      await _repository.createSession(session);

      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Ders başarıyla oluşturuldu');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Ders oluşturulurken hata: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryYellow,
              onPrimary: Colors.black,
              surface: AppColors.surfaceDark,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: AppColors.surfaceDark,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryYellow,
              onPrimary: Colors.black,
              surface: AppColors.surfaceDark,
              onSurface: AppColors.textPrimary,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppColors.surfaceDark,
              hourMinuteTextColor: AppColors.primaryYellow,
              dayPeriodTextColor: AppColors.textSecondary,
              dialHandColor: AppColors.primaryYellow,
              dialBackgroundColor: AppColors.cardDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Ders'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.primaryYellow,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Ders Bilgileri'),
              CustomTextField(
                controller: _titleController,
                label: 'Ders Adı',
                hint: 'Örn: Reformer Pilates, PT Seansı',
                validator: (v) => v?.isEmpty == true ? 'Başlık gerekli' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _capacityController,
                label: 'Kapasite',
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty == true ? 'Kapasite gerekli' : null,
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Zamanlama'),
              GlassCard(
                child: Column(
                  children: [
                    _buildRowItem(
                      'Tarih',
                      '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                      Icons.calendar_today_rounded,
                      () => _selectDate(context),
                    ),
                    const Divider(color: AppColors.glassBorder),
                    _buildRowItem(
                      'Başlangıç Saati',
                      _startTime.format(context),
                      Icons.access_time_rounded,
                      () => _selectTime(context),
                    ),
                    const Divider(color: AppColors.glassBorder),
                    _buildDurationPicker(),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              CustomButton(
                text: 'Dersi Oluştur',
                onPressed: _saveClass,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: AppTextStyles.headline.copyWith(
          color: AppColors.primaryYellow,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRowItem(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryYellow, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: AppTextStyles.body),
            ),
            Text(value, style: AppTextStyles.headline.copyWith(color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.timer_rounded, color: AppColors.primaryYellow, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Süre', style: AppTextStyles.body),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: _durationMinutes,
              dropdownColor: AppColors.cardDark,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryYellow),
              style: AppTextStyles.headline.copyWith(color: Colors.white),
              items: [30, 45, 60, 90, 120].map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text('$value dk'),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  setState(() => _durationMinutes = newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
