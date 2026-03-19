import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'profile.dart';
import 'contest_reminder.dart';

// ─────────────────────────────────────────────
//  📌 YOUR BACKEND URL — change after deploying
// ─────────────────────────────────────────────
const String _backendUrl = 'https://cp-tracker-backend-b8e0.onrender.com';

// ─────────────────────────────────────────────
//  HOME PAGE  (with Bottom Navigation Bar)
// ─────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _HomeTab(),
    const _AnalyticsTab(),
    const ContestReminderPage(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(index: 0, icon: Icons.home_outlined,          activeIcon: Icons.home_rounded,          label: 'Home'),
                _navItem(index: 1, icon: Icons.bar_chart_outlined,     activeIcon: Icons.bar_chart_rounded,     label: 'Analytics'),
                _navItem(index: 2, icon: Icons.notifications_outlined, activeIcon: Icons.notifications_rounded, label: 'Reminders'),
                _navItem(index: 3, icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,        label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon,
                size: 20, color: isActive ? Colors.white : Colors.black38),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HOME TAB
// ─────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _supabase = Supabase.instance.client;

  String _name      = '';
  String _username  = '';
  bool   _isLoading = true;

  // ── CONTESTS FROM BACKEND ─────────────────────
  List<Map<String, dynamic>> _contests = [];
  bool _contestsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadContests();
  }

  // ── LOAD PROFILE ──────────────────────────────
  Future<void> _loadProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      setState(() {
        _name      = data['name']     ?? '';
        _username  = data['username'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ── LOAD CONTESTS FROM BACKEND ────────────────
  Future<void> _loadContests() async {
    try {
      final res = await http.get(Uri.parse('$_backendUrl/contests'));
      if (res.statusCode == 200) {
        final data   = jsonDecode(res.body);
        final all    = List<Map<String, dynamic>>.from(data['contests'] ?? []);
        final now    = DateTime.now().toUtc();

        // ── AUTO REMOVE past contests ─────────────
        final upcoming = all.where((c) {
          final start = DateTime.tryParse(c['start_time'] ?? '');
          return start != null && start.isAfter(now);
        }).toList();

        // Sort by start time
        upcoming.sort((a, b) {
          final aTime = DateTime.parse(a['start_time']);
          final bTime = DateTime.parse(b['start_time']);
          return aTime.compareTo(bTime);
        });

        setState(() {
          _contests        = upcoming.take(5).toList(); // show max 5 in preview
          _contestsLoading = false;
        });
      }
    } catch (e) {
      setState(() => _contestsLoading = false);
    }
  }

  // ── MARK CONTEST AS COMPLETED ─────────────────
  Future<void> _markCompleted(Map<String, dynamic> contest) async {
    setState(() {
      _contests.removeWhere((c) => c['id'] == contest['id']);
    });

    // show undo snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${contest['name']} marked as completed',
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: Colors.black,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white70,
            onPressed: () {
              setState(() => _contests.insert(0, contest));
            },
          ),
        ),
      );
    }
  }

  // ── PLATFORM CONFIG ───────────────────────────
  Color _platformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'codeforces': return const Color(0xFF1A73E8);
      case 'codechef':   return const Color(0xFF5B4638);
      case 'atcoder':    return const Color(0xFF222222);
      default:           return Colors.black54;
    }
  }

  String _platformBadge(String platform) {
    switch (platform.toLowerCase()) {
      case 'codeforces': return 'CF';
      case 'codechef':   return 'CC';
      case 'atcoder':    return 'AT';
      default:           return 'OT';
    }
  }

  // ── TIME UNTIL CONTEST ────────────────────────
  String _timeUntil(String startTimeStr) {
    final start = DateTime.tryParse(startTimeStr)?.toLocal();
    if (start == null) return '';
    final diff = start.difference(DateTime.now());
    if (diff.inDays > 0)    return 'In ${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0)   return 'In ${diff.inHours}h ${diff.inMinutes % 60}m';
    if (diff.inMinutes > 0) return 'In ${diff.inMinutes}m';
    return 'Starting!';
  }

  Color _urgencyColor(String startTimeStr) {
    final start = DateTime.tryParse(startTimeStr)?.toLocal();
    if (start == null) return Colors.green;
    final diff = start.difference(DateTime.now());
    if (diff.inHours < 1)  return Colors.redAccent;
    if (diff.inHours < 24) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              color: Colors.black,
              onRefresh: () async {
                await _loadContests();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const SizedBox(height: 32),

                    // ── TOP BAR ─────────────────────────────
                    const Text(
                      'CP TRACKER',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 3.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(height: 60),

                    // ── WELCOME ──────────────────────────────
                    const Text(
                      'WELCOME',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 3.0,
                          color: Colors.black45),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Hello,\n$_name',
                      style: const TextStyle(
                        fontSize: 38,
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('@$_username',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black45)),

                    const SizedBox(height: 48),
                    Divider(color: Colors.black.withOpacity(0.1)),
                    const SizedBox(height: 32),

                    // ════════════════════════════════════════
                    //  UPCOMING CONTESTS SECTION
                    // ════════════════════════════════════════
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'UPCOMING CONTESTS',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 3.0,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        Row(
                          children: [
                            // Refresh button
                            GestureDetector(
                              onTap: _loadContests,
                              child: const Icon(Icons.refresh,
                                  size: 16, color: Colors.black45),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ContestReminderPage()),
                              ),
                              child: const Text(
                                'SEE ALL →',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── CONTESTS LIST ─────────────────────────
                    _contestsLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2),
                            ),
                          )
                        : _contests.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.notifications_none,
                                        size: 40, color: Colors.white38),
                                    SizedBox(height: 14),
                                    Text(
                                      'No upcoming contests',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontFamily: 'Georgia',
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Pull down to refresh',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white38,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: _contests
                                    .map((c) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 12),
                                          child: _contestCard(c),
                                        ))
                                    .toList(),
                              ),

                    const SizedBox(height: 14),

                    // ── MANAGE REMINDERS BUTTON ───────────────
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ContestReminderPage()),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.black, width: 1.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_outlined,
                                size: 14, color: Colors.black),
                            SizedBox(width: 8),
                            Text(
                              'MANAGE REMINDERS',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 2.0,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                    Divider(color: Colors.black.withOpacity(0.1)),
                    const SizedBox(height: 32),

                    // ── PLATFORM CARDS ───────────────────────
                    const Text(
                      'YOUR PLATFORMS',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 3.0,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _platformCard('CODEFORCES', 'CF',
                        const Color(0xFF1A73E8),
                        'Track your CF rating & problems'),
                    const SizedBox(height: 14),
                    _platformCard('CODECHEF', 'CC',
                        const Color(0xFF5B4638),
                        'Track your CC rating & contests'),
                    const SizedBox(height: 14),
                    _platformCard('ATCODER', 'AT',
                        const Color(0xFF222222),
                        'Track your AT rating & problems'),

                    const SizedBox(height: 48),

                    // ── MOTIVATIONAL CARD ────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Code.\nCompete.\nConquer.',
                            style: TextStyle(
                              fontSize: 28,
                              fontFamily: 'Georgia',
                              height: 1.3,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'LEVEL UP EVERY DAY',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 3.0,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
    );
  }

  // ── CONTEST CARD WITH COMPLETED BUTTON ────────
  Widget _contestCard(Map<String, dynamic> c) {
    final platform  = c['platform'] as String? ?? 'Other';
    final color     = _platformColor(platform);
    final badge     = _platformBadge(platform);
    final timeLeft  = _timeUntil(c['start_time'] ?? '');
    final urgency   = _urgencyColor(c['start_time'] ?? '');
    final startTime = DateTime.tryParse(c['start_time'] ?? '')?.toLocal();

    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = startTime != null
        ? '${startTime.day} ${months[startTime.month - 1]}'
        : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── ROW 1: Platform + date + time left ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Platform badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    platform,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),

                Row(
                  children: [
                    // Date
                    Text(
                      dateStr,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black38),
                    ),
                    const SizedBox(width: 8),
                    // Time left badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: urgency.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        timeLeft,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: urgency,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── ROW 2: Contest name ────────────────
            Text(
              c['name'] as String? ?? '',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // ── ROW 3: Badge + Completed button ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Platform badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),

                // ── COMPLETED BUTTON ──────────────
                GestureDetector(
                  onTap: () => _markCompleted(c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.green.shade200, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 13, color: Colors.green.shade600),
                        const SizedBox(width: 5),
                        Text(
                          'COMPLETED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── PLATFORM CARD ─────────────────────────────
  Widget _platformCard(
      String label, String badge, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(badge,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black38)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios,
              size: 13, color: Colors.black26),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ANALYTICS TAB — 📌 Replace with real page
// ─────────────────────────────────────────────
class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 48, color: Colors.black26),
            SizedBox(height: 16),
            Text('Analytics',
                style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'Georgia',
                    color: Colors.black45)),
            SizedBox(height: 8),
            Text('Coming soon',
                style: TextStyle(fontSize: 12, color: Colors.black26)),
          ],
        ),
      ),
    );
  }
}