import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'contest_reminder.dart';

// ─────────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 📌 SUPABASE INIT
  await Supabase.initialize(
    url: 'https://ctsafjnagyjhprjtqchq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0c2Fmam5hZ3lqaHByanRxY2hxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1MDgxNjQsImV4cCI6MjA4OTA4NDE2NH0.L-keAhtKpM9OAzLrcgSoi3S69W09RNwrB3sGtX2GO5c',
  );

  // 📌 NOTIFICATION INIT — static call (no brackets)
  await NotificationService.init();

  runApp(const RealEstateApp());
}

// ─────────────────────────────────────────────
//  APP
// ─────────────────────────────────────────────
class RealEstateApp extends StatelessWidget {
  const RealEstateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CP Tracker',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF2F2F2),
        fontFamily: 'Georgia',
      ),
      home: const RealEstateMainPage(),
    );
  }
}

// ─────────────────────────────────────────────
//  MAIN / STARTING PAGE
// ─────────────────────────────────────────────
class RealEstateMainPage extends StatelessWidget {
  const RealEstateMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),

              // ── ILLUSTRATION ──────────────────────────
              Center(
                child: Image.asset(
                  'assets/images/starting_page_image.png',
                  height: 220,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 40),

              // ── EYEBROW LABEL ─────────────────────────
              // 📌 EDIT text here
              const Text(
                'LEVEL UP EVERY DAY',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Helvetica Neue',
                  letterSpacing: 3.0,
                  color: Colors.black87,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 12),

              // ── MAIN HEADING ──────────────────────────
              // 📌 EDIT text here
              const Text(
                'Code.\nCompete.\nConquer.',
                style: TextStyle(
                  fontSize: 40,
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w400,
                  height: 1.15,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 36),

              // ── GET STARTED BUTTON ────────────────────
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GET STARTED',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Helvetica Neue',
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.play_arrow, size: 16, color: Colors.black),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}