import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile.dart';
import 'contest_reminder.dart';

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
                _navItem(index: 0, icon: Icons.home_outlined,           activeIcon: Icons.home_rounded,           label: 'Home'),
                _navItem(index: 1, icon: Icons.bar_chart_outlined,      activeIcon: Icons.bar_chart_rounded,      label: 'Analytics'),
                _navItem(index: 2, icon: Icons.notifications_outlined,  activeIcon: Icons.notifications_rounded,  label: 'Reminders'),
                _navItem(index: 3, icon: Icons.person_outline_rounded,  activeIcon: Icons.person_rounded,         label: 'Profile'),
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

  // ── UPCOMING CONTESTS PREVIEW ─────────────────
  // 📌 REPLACE with real API data later
  final List<Map<String, dynamic>> _upcomingContests = [
    {
      'name':     'Codeforces Round 987',
      'platform': 'CF',
      'color':    const Color(0xFF1A73E8),
      'timeLeft': 'In 26h',
      'urgency':  Colors.green,
    },
    {
      'name':     'CodeChef Starters 123',
      'platform': 'CC',
      'color':    const Color(0xFF5B4638),
      'timeLeft': 'In 5h',
      'urgency':  Colors.orange,
    },
    {
      'name':     'AtCoder ABC 390',
      'platform': 'AT',
      'color':    const Color(0xFF222222),
      'timeLeft': 'In 3d',
      'urgency':  Colors.green,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
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
                  //  UPCOMING CONTESTS PREVIEW
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
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ContestReminderPage()),
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

                  const SizedBox(height: 16),

                  // ── CONTEST PREVIEW CARDS or EMPTY STATE ─
                  if (_upcomingContests.isEmpty)
                    // ── BLACK EMPTY STATE BOX ───────────────
                    Container(
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
                            'Add reminders from the Reminders tab',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // ── CONTEST CARDS ─────────────────────────
                    Column(
                      children: _upcomingContests
                          .map((c) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 10),
                                child: _contestPreviewCard(c),
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
                        border:
                            Border.all(color: Colors.black, width: 1.2),
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
    );
  }

  // ── CONTEST PREVIEW CARD ──────────────────────
  Widget _contestPreviewCard(Map<String, dynamic> c) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (c['color'] as Color).withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              c['platform'],
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: c['color'] as Color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              c['name'],
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (c['urgency'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              c['timeLeft'],
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: c['urgency'] as Color,
              ),
            ),
          ),
        ],
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
                style:
                    TextStyle(fontSize: 12, color: Colors.black26)),
          ],
        ),
      ),
    );
  }
}