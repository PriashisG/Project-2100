import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────
//  HOME PAGE
// ─────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;

  String _name     = '';
  String _username = '';
  bool   _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ── LOAD USER PROFILE FROM SUPABASE ──────────
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
        _name     = data['name'] ?? '';
        _username = data['username'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ── LOGOUT ────────────────────────────────────
  Future<void> _onLogout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      // 📌 NAVIGATE back to main/login page after logout
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.black),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const SizedBox(height: 32),

                    // ── TOP BAR ───────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // APP NAME / LOGO
                        // 📌 EDIT: Change app name here
                        const Text(
                          'CP TRACKER',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 3.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),

                        // LOGOUT BUTTON
                        GestureDetector(
                          onTap: _onLogout,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.black26, width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'LOG OUT',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 2.0,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 60),

                    // ── WELCOME MESSAGE ───────────────────────
                    // 📌 EDIT: Change welcome text here
                    const Text(
                      'WELCOME',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 3.0,
                        color: Colors.black45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Shows the user's name from database
                    Text(
                      'Hello,\n$_name 👋',
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

                    // Shows the username
                    Text(
                      '@$_username',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black45,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // ── DIVIDER ───────────────────────────────
                    Divider(color: Colors.black.withOpacity(0.1)),

                    const SizedBox(height: 32),

                    // ── STATS LABEL ───────────────────────────
                    // 📌 EDIT: Change section label here
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

                    // ── PLATFORM CARDS ────────────────────────
                    // 📌 NAVIGATE: Add onTap to each card to open platform stats page
                    _platformCard(
                      label: 'CODEFORCES',
                      badge: 'CF',
                      badgeColor: const Color(0xFF1A73E8),
                      subtitle: 'Track your CF rating & problems',
                    ),

                    const SizedBox(height: 14),

                    _platformCard(
                      label: 'CODECHEF',
                      badge: 'CC',
                      badgeColor: const Color(0xFF5B4638),
                      subtitle: 'Track your CC rating & contests',
                    ),

                    const SizedBox(height: 14),

                    _platformCard(
                      label: 'ATCODER',
                      badge: 'AT',
                      badgeColor: const Color(0xFF222222),
                      subtitle: 'Track your AT rating & problems',
                    ),

                    const SizedBox(height: 48),

                    // ── MOTIVATIONAL FOOTER ───────────────────
                    // 📌 EDIT: Change motivational text here
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
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'LEVEL UP EVERY DAY',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 3.0,
                              color: Colors.white38,
                              fontWeight: FontWeight.w500,
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

  // ── PLATFORM CARD WIDGET ──────────────────────
  Widget _platformCard({
    required String label,
    required String badge,
    required Color badgeColor,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap, // 📌 add navigation here
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // BADGE
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(width: 16),

            // LABEL + SUBTITLE
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black38,
                    ),
                  ),
                ],
              ),
            ),

            // ARROW
            const Icon(Icons.arrow_forward_ios,
                size: 13, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
