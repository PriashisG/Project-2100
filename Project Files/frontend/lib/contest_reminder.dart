import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// ─────────────────────────────────────────────
//  NOTIFICATION SERVICE  (all static)
// ─────────────────────────────────────────────
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── INIT ──────────────────────────────────────
  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );
  }

  // ── SCHEDULE NOTIFICATION ─────────────────────
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'contest_reminders',
          'Contest Reminders',
          channelDescription: 'Notifications for upcoming contests',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── CANCEL NOTIFICATION ───────────────────────
  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  // ── CANCEL ALL ────────────────────────────────
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

// ─────────────────────────────────────────────
//  CONTEST REMINDER PAGE
// ─────────────────────────────────────────────
class ContestReminderPage extends StatefulWidget {
  const ContestReminderPage({super.key});

  @override
  State<ContestReminderPage> createState() => _ContestReminderPageState();
}

class _ContestReminderPageState extends State<ContestReminderPage> {
  final _supabase = Supabase.instance.client;

  final _titleController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _remind10Min = true;
  bool _remind24Hr  = true;
  bool _isSaving    = false;

  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;

  String _selectedPlatform = 'Codeforces';
  final List<String> _platforms = [
    'Codeforces',
    'Codechef',
    'Atcoder',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ── LOAD REMINDERS ────────────────────────────
  Future<void> _loadReminders() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('contest_reminders')
          .select()
          .eq('user_id', userId)
          .order('contest_time', ascending: true);

      setState(() {
        _reminders = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ── PICK DATE ─────────────────────────────────
  Future<void> _pickDate() async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.black)),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  // ── PICK TIME ─────────────────────────────────
  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.black)),
        child: child!,
      ),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  // ── SAVE REMINDER ─────────────────────────────
  Future<void> _saveReminder() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnack('Enter a contest name');
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      _showSnack('Pick date and time');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final contestTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final result = await _supabase
          .from('contest_reminders')
          .insert({
            'user_id':      userId,
            'title':        _titleController.text.trim(),
            'platform':     _selectedPlatform,
            'contest_time': contestTime.toIso8601String(),
            'remind_10min': _remind10Min,
            'remind_24hr':  _remind24Hr,
          })
          .select()
          .single();

      final int reminderId = result['id'] as int;

      // schedule 10-min notification
      if (_remind10Min) {
        final notifTime =
            contestTime.subtract(const Duration(minutes: 10));
        if (notifTime.isAfter(DateTime.now())) {
          await NotificationService.scheduleNotification(
            id: reminderId * 10,
            title: '⚡ Contest in 10 minutes!',
            body:
                '${_titleController.text.trim()} on $_selectedPlatform starts soon!',
            scheduledTime: notifTime,
          );
        }
      }

      // schedule 24-hour notification
      if (_remind24Hr) {
        final notifTime =
            contestTime.subtract(const Duration(hours: 24));
        if (notifTime.isAfter(DateTime.now())) {
          await NotificationService.scheduleNotification(
            id: reminderId * 10 + 1,
            title: '📅 Contest tomorrow!',
            body:
                '${_titleController.text.trim()} on $_selectedPlatform is in 24 hours.',
            scheduledTime: notifTime,
          );
        }
      }

      _titleController.clear();
      setState(() {
        _selectedDate     = null;
        _selectedTime     = null;
        _selectedPlatform = 'Codeforces';
        _remind10Min      = true;
        _remind24Hr       = true;
      });

      await _loadReminders();
      _showSnack('Reminder saved! ✅');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── DELETE REMINDER ───────────────────────────
  Future<void> _deleteReminder(Map<String, dynamic> reminder) async {
    try {
      await _supabase
          .from('contest_reminders')
          .delete()
          .eq('id', reminder['id']);

      await NotificationService.cancelNotification(reminder['id'] * 10);
      await NotificationService.cancelNotification(
          reminder['id'] * 10 + 1);

      await _loadReminders();
      _showSnack('Reminder deleted');
    } catch (e) {
      _showSnack('Error deleting reminder');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── OPEN ADD SHEET ────────────────────────────
  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ADD REMINDER',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 3.0,
                          fontWeight: FontWeight.w700)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // CONTEST NAME
              _sheetLabel('CONTEST NAME'),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 15),
                decoration: _sheetInputDecoration(
                    'e.g. Codeforces Round 999'),
              ),

              const SizedBox(height: 20),

              // PLATFORM
              _sheetLabel('PLATFORM'),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPlatform,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.black54),
                    items: _platforms
                        .map((p) => DropdownMenuItem(
                            value: p, child: Text(p)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(
                            () => _selectedPlatform = val);
                        setSheetState(
                            () => _selectedPlatform = val);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // DATE + TIME
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _sheetLabel('DATE'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            await _pickDate();
                            setSheetState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF2F2F2),
                                borderRadius:
                                    BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: Colors.black54),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedDate == null
                                      ? 'Pick date'
                                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _selectedDate == null
                                        ? Colors.black38
                                        : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _sheetLabel('TIME'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            await _pickTime();
                            setSheetState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF2F2F2),
                                borderRadius:
                                    BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 14,
                                    color: Colors.black54),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedTime == null
                                      ? 'Pick time'
                                      : _selectedTime!
                                          .format(context),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _selectedTime == null
                                        ? Colors.black38
                                        : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // NOTIFICATION TOGGLES
              _sheetLabel('NOTIFICATIONS'),
              const SizedBox(height: 12),
              _notifToggle(
                label: '24 hours before',
                subtitle: 'Reminder the day before',
                icon: Icons.notifications_outlined,
                value: _remind24Hr,
                onChanged: (val) {
                  setState(() => _remind24Hr = val);
                  setSheetState(() => _remind24Hr = val);
                },
              ),
              const SizedBox(height: 8),
              _notifToggle(
                label: '10 minutes before',
                subtitle: 'Last-minute reminder',
                icon: Icons.alarm,
                value: _remind10Min,
                onChanged: (val) {
                  setState(() => _remind10Min = val);
                  setSheetState(() => _remind10Min = val);
                },
              ),

              const SizedBox(height: 28),

              // SAVE BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveReminder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2))
                      : const Text('SAVE REMINDER',
                          style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 2.5,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── TOP BAR ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.black, size: 22),
                      ),
                      const SizedBox(width: 16),
                      const Text('CONTEST REMINDERS',
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 3.0,
                              fontWeight: FontWeight.w700,
                              color: Colors.black)),
                    ],
                  ),
                  GestureDetector(
                    onTap: _openAddSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add,
                              color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text('ADD',
                              style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 2.0,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── REMINDER LIST ──────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Colors.black))
                  : _reminders.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notifications_none,
                                  size: 48, color: Colors.black26),
                              SizedBox(height: 16),
                              Text('No reminders yet',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontFamily: 'Georgia',
                                      color: Colors.black45)),
                              SizedBox(height: 8),
                              Text(
                                  'Tap ADD to set a contest reminder',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black38)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32),
                          itemCount: _reminders.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) =>
                              _reminderCard(_reminders[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── REMINDER CARD ─────────────────────────────
  Widget _reminderCard(Map<String, dynamic> reminder) {
    final contestTime =
        DateTime.parse(reminder['contest_time'] as String).toLocal();
    final isPast = contestTime.isBefore(DateTime.now());
    final platform = reminder['platform'] as String? ?? '';

    Color badgeColor = Colors.black;
    String badge = 'OT';
    if (platform == 'Codeforces') {
      badgeColor = const Color(0xFF1A73E8);
      badge = 'CF';
    } else if (platform == 'Codechef') {
      badgeColor = const Color(0xFF5B4638);
      badge = 'CC';
    } else if (platform == 'Atcoder') {
      badgeColor = const Color(0xFF222222);
      badge = 'AT';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isPast ? Colors.white.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(badge,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder['title'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isPast ? Colors.black38 : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${contestTime.day}/${contestTime.month}/${contestTime.year}  ${_formatTime(contestTime)}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black45),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (reminder['remind_24hr'] == true)
                      _notifBadge('24h', isPast),
                    if (reminder['remind_10min'] == true) ...[
                      const SizedBox(width: 6),
                      _notifBadge('10m', isPast),
                    ],
                    if (isPast) ...[
                      const SizedBox(width: 6),
                      _notifBadge('PAST', true),
                    ],
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _deleteReminder(reminder),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.delete_outline,
                  size: 16, color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notifBadge(String label, bool isPast) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isPast
              ? Colors.black.withOpacity(0.05)
              : Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color:
                    isPast ? Colors.black26 : Colors.black54,
                letterSpacing: 0.5)),
      );

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _sheetLabel(String label) => Text(label,
      style: const TextStyle(
          fontSize: 10,
          letterSpacing: 2.5,
          fontWeight: FontWeight.w600,
          color: Colors.black54));

  InputDecoration _sheetInputDecoration(String hint) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26),
        filled: true,
        fillColor: const Color(0xFFF2F2F2),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Colors.black, width: 1.2)),
      );

  Widget _notifToggle({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black45)),
              ],
            ),
          ),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.black),
        ],
      ),
    );
  }
}