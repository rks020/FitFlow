with open("lib/features/diets/widgets/water_tracker_widget.dart", "r") as f:
    text = f.read()

import re

# Add imports
text = text.replace("import '../repositories/water_repository.dart';", "import '../repositories/water_repository.dart';\nimport 'package:shared_preferences/shared_preferences.dart';\nimport '../../../../core/services/notification_service.dart';")

# Add state variable
text = text.replace("bool _notificationsEnabled = true;", "bool _notificationsEnabled = true;\n  int _intervalHours = 2;")

# Modify _loadNotificationPref
load_pref_old = """      if (res != null && mounted) {
        setState(() {
          _notificationsEnabled = res['water_notification_enabled'] == true;
        });
      }"""
load_pref_new = """      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _intervalHours = prefs.getInt('water_interval') ?? 2;
      });
      if (res != null && mounted) {
        setState(() {
          _notificationsEnabled = res['water_notification_enabled'] == true;
        });
      }"""
text = text.replace(load_pref_old, load_pref_new)

# Modify _toggleNotifications
toggle_old = """    try {
      await Supabase.instance.client
          .from('members')
          .update({'water_notification_enabled': value})
          .eq('id', user.id);
    } catch (e) {"""

toggle_new = """    try {
      await Supabase.instance.client
          .from('members')
          .update({'water_notification_enabled': value})
          .eq('id', user.id);
      
      final notificationService = NotificationService();
      if (value) {
         await notificationService.scheduleWaterReminders(_intervalHours);
      } else {
         await notificationService.cancelWaterReminders();
      }
    } catch (e) {"""
text = text.replace(toggle_old, toggle_new)

# Add _changeInterval method
method_new = """  Future<void> _changeInterval(int hours) async {
    setState(() {
      _intervalHours = hours;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_interval', hours);
    
    if (_notificationsEnabled) {
       final notificationService = NotificationService();
       await notificationService.scheduleWaterReminders(hours);
    }
  }

  Future<void> _loadData() async {"""

text = text.replace("  Future<void> _loadData() async {", method_new)


with open("lib/features/diets/widgets/water_tracker_widget.dart", "w") as f:
    f.write(text)
