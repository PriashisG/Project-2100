import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────
//  📌 BACKEND URL
// ─────────────────────────────────────────────
const String _backendUrl = 'https://cp-tracker-backend-b8e0.onrender.com';

// ─────────────────────────────────────────────
//  NOTIFICATION SERVICE
// ─────────────────────────────────────────────
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

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
          importance: Importance.max,
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

  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  // ── TEST NOTIFICATION (fires after 5 seconds) ──
  static Future<void> testNotification() async {
    final testTime = DateTime.now().add(const Duration(seconds: 5));
    await scheduleNotification(
      id: 9999,
      title: '✅ Notification Test',
      body: 'CP Tracker notifications are working!',
      scheduledTime: testTime,
    );
  }
}

// ─────────────────────────────────────────────
//  PLATFORM CONFIG
// ─────────────────────────────────────────────
class _PlatformConfig {
  final String badge;
  final Color  color;
  final String contestsUrl;
  const _PlatformConfig({
    required this.badge,
    required this.color,
    required this.contestsUrl,
  });
}

const Map<String, _PlatformConfig> _platformMap = {
  'Codeforces': _PlatformConfig(
    badge: 'CF', color: Color(0xFF1A73E8),
    contestsUrl: 'https://codeforces.com/contests',
  ),
  'Codechef': _PlatformConfig(
    badge: 'CC', color: Color(0xFF5B4638),
    contestsUrl: 'https://www.codechef.com/contests',
  ),
  'Atcoder': _PlatformConfig(
    badge: 'AT', color: Color(0xFF222222),
    contestsUrl: 'https://atcoder.jp/contests',
  ),
  'Other': _PlatformConfig(
    badge: 'OT', color: Color(0xFF888888),
    contestsUrl: 'https://google.com',
  ),
};

// ─────────────────────────────────────────────
//  CONTEST REMINDER PAGE
// ─────────────────────────────────────────────
class ContestReminderPage extends StatefulWidget {
  const ContestReminderPage({super.key});

  @override
  State<ContestReminderPage> createState() => _ContestReminderPageState();
}

class _ContestReminderPageState extends State<ContestReminderPage>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  // ── UPCOMING CONTESTS ─────────────────────────
  List<Map<String, dynamic>> _allContests      = [];
  List<Map<String, dynamic>> _filteredContests = [];
  bool _upcomingLoading = true;

  // ── FILTER ────────────────────────────────────
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Codeforces', 'Codechef', 'Atcoder'];

  // ── REMINDERS SET (contest cf_id → reminder id) ──
  final Map<String, int> _setReminders = {};

  // ── CUSTOM REMINDERS ──────────────────────────
  List<Map<String, dynamic>> _reminders = [];
  bool _remindersLoading = true;

  // ── ADD FORM ──────────────────────────────────
  final _titleController = TextEditingController();
  final _linkController  = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _remind10Min        = true;
  bool _remind24Hr         = true;
  bool _isSaving           = false;
  String _selectedPlatform = 'Codeforces';
  final List<String> _platforms = ['Codeforces', 'Codechef', 'Atcoder', 'Other'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUpcomingContests();
    _loadReminders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  // ── LOAD UPCOMING ─────────────────────────────
  Future<void> _loadUpcomingContests() async {
    setState(() => _upcomingLoading = true);
    try {
      final res = await http.get(Uri.parse('$_backendUrl/contests'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final all  = List<Map<String, dynamic>>.from(data['contests'] ?? []);
        final now  = DateTime.now().toUtc();
        final upcoming = all.where((c) {
          final start = DateTime.tryParse(c['start_time'] ?? '');
          return start != null && start.isAfter(now);
        }).toList();
        upcoming.sort((a, b) => DateTime.parse(a['start_time'])
            .compareTo(DateTime.parse(b['start_time'])));
        setState(() {
          _allContests      = upcoming;
          _upcomingLoading  = false;
        });
        _applyFilter(_selectedFilter);
      }
    } catch (e) {
      setState(() => _upcomingLoading = false);
    }
  }

  // ── APPLY FILTER ──────────────────────────────
  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == 'All') {
        _filteredContests = List.from(_allContests);
      } else {
        _filteredContests = _allContests
            .where((c) => (c['platform'] as String? ?? '') == filter)
            .toList();
      }
    });
  }

  // ── LOAD CUSTOM REMINDERS ─────────────────────
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
        _reminders        = List<Map<String, dynamic>>.from(data);
        _remindersLoading = false;
        // track which upcoming contests already have reminders
        for (final r in _reminders) {
          final cfId = r['cf_id'] as String? ?? '';
          if (cfId.isNotEmpty) _setReminders[cfId] = r['id'] as int;
        }
      });
    } catch (e) {
      setState(() => _remindersLoading = false);
    }
  }

  // ── SET REMINDER FROM UPCOMING ────────────────
  Future<void> _setReminderFromUpcoming(Map<String, dynamic> contest) async {
    final cfId    = contest['cf_id']?.toString() ?? contest['id']?.toString() ?? '';
    final name    = contest['name'] as String? ?? '';
    final platform = contest['platform'] as String? ?? 'Other';
    final url     = contest['url'] as String? ?? '';
    final startStr = contest['start_time'] as String? ?? '';
    final contestTime = DateTime.tryParse(startStr)?.toLocal();

    if (contestTime == null) {
      _showSnack('Invalid contest time');
      return;
    }

    // already set — cancel it
    if (_setReminders.containsKey(cfId)) {
      final remId = _setReminders[cfId]!;
      await _supabase.from('contest_reminders').delete().eq('id', remId);
      await NotificationService.cancelNotification(remId * 10);
      await NotificationService.cancelNotification(remId * 10 + 1);
      setState(() => _setReminders.remove(cfId));
      await _loadReminders();
      _showSnack('Reminder removed');
      return;
    }

    // save to Supabase
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final result = await _supabase.from('contest_reminders').insert({
        'user_id':      userId,
        'title':        name,
        'platform':     platform,
        'contest_time': contestTime.toIso8601String(),
        'remind_10min': true,
        'remind_24hr':  true,
        'link':         url,
        'cf_id':        cfId,
      }).select().single();

      final int remId = result['id'] as int;

      // schedule 10min notification
      final t10 = contestTime.subtract(const Duration(minutes: 10));
      if (t10.isAfter(DateTime.now())) {
        await NotificationService.scheduleNotification(
          id:            remId * 10,
          title:         '⚡ Contest in 10 minutes!',
          body:          '$name on $platform starts soon!',
          scheduledTime: t10,
        );
      }

      // schedule 24h notification
      final t24 = contestTime.subtract(const Duration(hours: 24));
      if (t24.isAfter(DateTime.now())) {
        await NotificationService.scheduleNotification(
          id:            remId * 10 + 1,
          title:         '📅 Contest tomorrow!',
          body:          '$name on $platform is in 24 hours.',
          scheduledTime: t24,
        );
      }

      setState(() => _setReminders[cfId] = remId);
      await _loadReminders();
      _showSnack('Reminder set! 🔔 You\'ll be notified 24h & 10min before');
    } catch (e) {
      _showSnack('Error: ${e.toString()}');
    }
  }

  // ── OPEN URL ──────────────────────────────────
  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── TIME UNTIL ────────────────────────────────
  String _timeUntil(String startStr) {
    final start = DateTime.tryParse(startStr)?.toLocal();
    if (start == null) return '';
    final diff = start.difference(DateTime.now());
    if (diff.inDays > 0)    return 'In ${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0)   return 'In ${diff.inHours}h ${diff.inMinutes % 60}m';
    if (diff.inMinutes > 0) return 'In ${diff.inMinutes}m';
    return 'Starting!';
  }

  Color _urgencyColor(String startStr) {
    final start = DateTime.tryParse(startStr)?.toLocal();
    if (start == null) return Colors.green;
    final diff = start.difference(DateTime.now());
    if (diff.inHours < 1)  return Colors.redAccent;
    if (diff.inHours < 24) return Colors.orange;
    return Colors.green;
  }

  Color _platformColor(String p) => _platformMap[p]?.color ?? Colors.black54;
  String _platformBadge(String p) => _platformMap[p]?.badge ?? 'OT';

  // ── PICK DATE / TIME ──────────────────────────
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

  // ── SAVE CUSTOM REMINDER ──────────────────────
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
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        _selectedTime!.hour, _selectedTime!.minute,
      );
      final config = _platformMap[_selectedPlatform]!;
      final link   = _linkController.text.trim().isNotEmpty
          ? _linkController.text.trim()
          : config.contestsUrl;

      final result = await _supabase.from('contest_reminders').insert({
        'user_id':      userId,
        'title':        _titleController.text.trim(),
        'platform':     _selectedPlatform,
        'contest_time': contestTime.toIso8601String(),
        'remind_10min': _remind10Min,
        'remind_24hr':  _remind24Hr,
        'link':         link,
      }).select().single();

      final int remId = result['id'] as int;

      if (_remind10Min) {
        final t = contestTime.subtract(const Duration(minutes: 10));
        if (t.isAfter(DateTime.now())) {
          await NotificationService.scheduleNotification(
            id: remId * 10,
            title: '⚡ Contest in 10 minutes!',
            body: '${_titleController.text.trim()} on $_selectedPlatform starts soon!',
            scheduledTime: t,
          );
        }
      }
      if (_remind24Hr) {
        final t = contestTime.subtract(const Duration(hours: 24));
        if (t.isAfter(DateTime.now())) {
          await NotificationService.scheduleNotification(
            id: remId * 10 + 1,
            title: '📅 Contest tomorrow!',
            body: '${_titleController.text.trim()} on $_selectedPlatform is in 24 hours.',
            scheduledTime: t,
          );
        }
      }

      _titleController.clear();
      _linkController.clear();
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
      await _supabase.from('contest_reminders').delete().eq('id', reminder['id']);
      await NotificationService.cancelNotification(reminder['id'] * 10);
      await NotificationService.cancelNotification(reminder['id'] * 10 + 1);
      final cfId = reminder['cf_id'] as String? ?? '';
      if (cfId.isNotEmpty) setState(() => _setReminders.remove(cfId));
      await _loadReminders();
      _showSnack('Reminder deleted');
    } catch (e) {
      _showSnack('Error deleting reminder');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.black,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── ADD CUSTOM REMINDER SHEET ─────────────────
  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ADD CUSTOM REMINDER',
                        style: TextStyle(fontSize: 11, letterSpacing: 3.0, fontWeight: FontWeight.w700)),
                    GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, size: 20)),
                  ],
                ),
                const SizedBox(height: 24),

                _sheetLabel('CONTEST NAME'),
                const SizedBox(height: 8),
                TextField(controller: _titleController, style: const TextStyle(fontSize: 15),
                    decoration: _sheetInputDecoration('e.g. Codeforces Round 999')),
                const SizedBox(height: 20),

                _sheetLabel('PLATFORM'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPlatform,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                      items: _platforms.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedPlatform = val);
                          setSheetState(() => _selectedPlatform = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                _sheetLabel('CONTEST LINK (OPTIONAL)'),
                const SizedBox(height: 8),
                TextField(controller: _linkController, keyboardType: TextInputType.url,
                    style: const TextStyle(fontSize: 15),
                    decoration: _sheetInputDecoration('https://codeforces.com/contest/...')),
                const SizedBox(height: 20),

                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _sheetLabel('DATE'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async { await _pickDate(); setSheetState(() {}); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.black54),
                          const SizedBox(width: 8),
                          Text(
                            _selectedDate == null ? 'Pick date'
                                : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                            style: TextStyle(fontSize: 13,
                                color: _selectedDate == null ? Colors.black38 : Colors.black),
                          ),
                        ]),
                      ),
                    ),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _sheetLabel('TIME'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async { await _pickTime(); setSheetState(() {}); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.black54),
                          const SizedBox(width: 8),
                          Text(
                            _selectedTime == null ? 'Pick time' : _selectedTime!.format(context),
                            style: TextStyle(fontSize: 13,
                                color: _selectedTime == null ? Colors.black38 : Colors.black),
                          ),
                        ]),
                      ),
                    ),
                  ])),
                ]),
                const SizedBox(height: 20),

                _sheetLabel('NOTIFICATIONS'),
                const SizedBox(height: 12),
                _notifToggle(label: '24 hours before', subtitle: 'Reminder the day before',
                    icon: Icons.notifications_outlined, value: _remind24Hr,
                    onChanged: (val) { setState(() => _remind24Hr = val); setSheetState(() => _remind24Hr = val); }),
                const SizedBox(height: 8),
                _notifToggle(label: '10 minutes before', subtitle: 'Last-minute reminder',
                    icon: Icons.alarm, value: _remind10Min,
                    onChanged: (val) { setState(() => _remind10Min = val); setSheetState(() => _remind10Min = val); }),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveReminder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(height: 18, width: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('SAVE REMINDER',
                            style: TextStyle(fontSize: 12, letterSpacing: 2.5, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
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
          children: [

            // ── TOP BAR ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CONTESTS',
                      style: TextStyle(fontSize: 11, letterSpacing: 3.5,
                          fontWeight: FontWeight.w700, color: Colors.black)),
                  Row(children: [
                    // Test notification button
                    GestureDetector(
                      onTap: () async {
                        await NotificationService.testNotification();
                        _showSnack('Test notification in 5 seconds! 🔔');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.notifications_active_outlined,
                            size: 16, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Add custom reminder
                    GestureDetector(
                      onTap: _openAddSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.black, borderRadius: BorderRadius.circular(6)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('ADD', style: TextStyle(fontSize: 10, letterSpacing: 1.5,
                                fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── TAB BAR ───────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                      color: Colors.black, borderRadius: BorderRadius.circular(8)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.black45,
                  labelPadding: EdgeInsets.zero,
                  labelStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                  dividerColor: Colors.transparent,
                  tabs: [
                    const Tab(text: 'UPCOMING'),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('MY REMINDERS'),
                          if (_reminders.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_reminders.length}',
                                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── TAB VIEWS ─────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _upcomingTab(),
                  _remindersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UPCOMING TAB ──────────────────────────────
  Widget _upcomingTab() {
    return Column(
      children: [

        // ── FILTER CHIPS ──────────────────────────
        SizedBox(
          height: 36,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f        = _filters[i];
              final isActive = _selectedFilter == f;
              Color chipColor = Colors.black;
              if (f == 'Codeforces') chipColor = const Color(0xFF1A73E8);
              if (f == 'Codechef')   chipColor = const Color(0xFF5B4638);
              if (f == 'Atcoder')    chipColor = const Color(0xFF222222);

              return GestureDetector(
                onTap: () => _applyFilter(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? chipColor : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isActive ? chipColor : Colors.black.withOpacity(0.1)),
                  ),
                  child: Text(
                    f == 'All' ? 'ALL' : _platformMap[f]?.badge ?? f,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: isActive ? Colors.white : Colors.black54,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // ── CONTEST LIST ──────────────────────────
        Expanded(
          child: _upcomingLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : _filteredContests.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.event_busy, size: 48, color: Colors.black26),
                        const SizedBox(height: 16),
                        const Text('No contests found',
                            style: TextStyle(fontSize: 18, fontFamily: 'Georgia', color: Colors.black45)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _loadUpcomingContests,
                          child: const Text('Pull to refresh',
                              style: TextStyle(fontSize: 12, color: Colors.black38,
                                  decoration: TextDecoration.underline)),
                        ),
                      ]),
                    )
                  : RefreshIndicator(
                      color: Colors.black,
                      onRefresh: _loadUpcomingContests,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _filteredContests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _upcomingCard(_filteredContests[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  // ── UPCOMING CARD ─────────────────────────────
  Widget _upcomingCard(Map<String, dynamic> c) {
    final platform = c['platform'] as String? ?? 'Other';
    final color    = _platformColor(platform);
    final badge    = _platformBadge(platform);
    final timeLeft = _timeUntil(c['start_time'] ?? '');
    final urgency  = _urgencyColor(c['start_time'] ?? '');
    final url      = c['url'] as String? ?? _platformMap[platform]?.contestsUrl ?? '';
    final cfId     = c['cf_id']?.toString() ?? c['id']?.toString() ?? '';
    final hasReminder = _setReminders.containsKey(cfId);

    final startTime = DateTime.tryParse(c['start_time'] ?? '')?.toLocal();
    final months    = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr   = startTime != null ? '${startTime.day} ${months[startTime.month-1]}' : '';
    final timeStr   = startTime != null
        ? '${startTime.hour.toString().padLeft(2,'0')}:${startTime.minute.toString().padLeft(2,'0')}'
        : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: hasReminder ? Border.all(color: Colors.black, width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Platform + time left
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(platform,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: urgency.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(timeLeft,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: urgency)),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Contest name — tap to open
            GestureDetector(
              onTap: () => _openUrl(url),
              child: Row(
                children: [
                  Expanded(
                    child: Text(c['name'] as String? ?? '',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                            color: Colors.black, height: 1.3)),
                  ),
                  const Icon(Icons.open_in_new, size: 14, color: Colors.black26),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Bottom row: badge + date + alarm + register
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(badge,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                ),
                const SizedBox(width: 8),
                Text('$dateStr  $timeStr',
                    style: const TextStyle(fontSize: 11, color: Colors.black38)),
                const Spacer(),

                // ── ALARM BUTTON ──────────────────
                GestureDetector(
                  onTap: () => _setReminderFromUpcoming(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: hasReminder ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: hasReminder ? Colors.black : Colors.black26),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasReminder ? Icons.notifications_active : Icons.notifications_outlined,
                          size: 13,
                          color: hasReminder ? Colors.white : Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasReminder ? 'SET' : 'REMIND',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: hasReminder ? Colors.white : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // REGISTER button
                GestureDetector(
                  onTap: () => _openUrl(url),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(8)),
                    child: const Text('REGISTER',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: 1.0)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── MY REMINDERS TAB ─────────────────────────
  Widget _remindersTab() {
    if (_remindersLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.black));
    }
    if (_reminders.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.notifications_none, size: 48, color: Colors.black26),
          const SizedBox(height: 16),
          const Text('No reminders yet',
              style: TextStyle(fontSize: 18, fontFamily: 'Georgia', color: Colors.black45)),
          const SizedBox(height: 8),
          const Text('Tap REMIND on any contest or tap ADD',
              style: TextStyle(fontSize: 12, color: Colors.black38)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _reminders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _reminderCard(_reminders[i]),
    );
  }

  // ── REMINDER CARD ─────────────────────────────
  Widget _reminderCard(Map<String, dynamic> reminder) {
    final contestTime = DateTime.parse(reminder['contest_time'] as String).toLocal();
    final isPast      = contestTime.isBefore(DateTime.now());
    final platform    = reminder['platform'] as String? ?? 'Other';
    final link        = reminder['link'] as String? ?? '';
    final config      = _platformMap[platform] ?? _platformMap['Other']!;
    final months      = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPast ? Colors.white.withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: config.color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(platform,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: config.color)),
              ),
              Row(children: [
                Text(
                  '${contestTime.day} ${months[contestTime.month-1]}  '
                  '${contestTime.hour.toString().padLeft(2,'0')}:${contestTime.minute.toString().padLeft(2,'0')}',
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _deleteReminder(reminder),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                    child: Icon(Icons.delete_outline, size: 14, color: Colors.red.shade400),
                  ),
                ),
              ]),
            ],
          ),

          const SizedBox(height: 10),

          GestureDetector(
            onTap: () => _openUrl(link.isNotEmpty ? link : config.contestsUrl),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    reminder['title'] as String? ?? '',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: isPast ? Colors.black38 : Colors.black),
                  ),
                ),
                const Icon(Icons.open_in_new, size: 13, color: Colors.black26),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                if (reminder['remind_24hr'] == true) _notifBadge('🔔 24h', isPast),
                if (reminder['remind_10min'] == true) ...[
                  const SizedBox(width: 6), _notifBadge('⚡ 10m', isPast)],
                if (isPast) ...[const SizedBox(width: 6), _notifBadge('PAST', true)],
              ]),
              GestureDetector(
                onTap: () => _openUrl(link.isNotEmpty ? link : config.contestsUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: config.color, borderRadius: BorderRadius.circular(8)),
                  child: const Text('REGISTER',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: 1.0)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _notifBadge(String label, bool isPast) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPast ? Colors.black.withOpacity(0.04) : Colors.black.withOpacity(0.07),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                color: isPast ? Colors.black26 : Colors.black54)),
      );

  Widget _sheetLabel(String label) => Text(label,
      style: const TextStyle(fontSize: 10, letterSpacing: 2.5,
          fontWeight: FontWeight.w600, color: Colors.black54));

  InputDecoration _sheetInputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26),
        filled: true, fillColor: const Color(0xFFF2F2F2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 1.2)),
      );

  Widget _notifToggle({
    required String label, required String subtitle,
    required IconData icon, required bool value, required ValueChanged<bool> onChanged,
  }) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black45)),
          ])),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.black),
        ]),
      );
}