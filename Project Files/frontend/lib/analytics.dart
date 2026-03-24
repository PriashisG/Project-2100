import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String _backendUrl = 'https://cp-tracker-backend-b8e0.onrender.com';

// ─────────────────────────────────────────────
//  ANALYTICS PAGE
// ─────────────────────────────────────────────
class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final _supabase = Supabase.instance.client;

  String _cfHandle = '';
  bool _isLoading = false;
  bool _hasData = false;
  String _statusMsg = '';
  double _progress = 0.0;

  // ── ANALYSIS RESULTS ─────────────────────────
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _loadHandle();
  }

  // ── LOAD CF HANDLE FROM PROFILE ──────────────
  Future<void> _loadHandle() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final profile = await _supabase
          .from('profiles')
          .select('cf_handle')
          .eq('id', userId)
          .single();
      setState(() => _cfHandle = profile['cf_handle'] as String? ?? '');
    } catch (_) {}
  }

  // ── RUN ANALYSIS ──────────────────────────────
  Future<void> _runAnalysis() async {
    if (_cfHandle.isEmpty) {
      _showSnack('Set your Codeforces handle in Profile first');
      return;
    }

    setState(() {
      _isLoading = true;
      _hasData = false;
      _progress = 0.05;
      _statusMsg = 'Starting analysis...';
    });

    try {
      // ── Poll progress messages ─────────────────
      // The analysis takes ~30-60s so we show fake progress
      _simulateProgress();

      final res = await http
          .get(
            Uri.parse('$_backendUrl/analyze/$_cfHandle'),
          )
          .timeout(const Duration(minutes: 3));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _data = Map<String, dynamic>.from(body['data'] ?? {});
          _hasData = true;
          _isLoading = false;
          _progress = 1.0;
          _statusMsg = 'Analysis complete ✅';
        });
      } else {
        final err = jsonDecode(res.body)['detail'] ?? 'Analysis failed';
        setState(() {
          _isLoading = false;
          _statusMsg = err;
        });
        _showSnack(err);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMsg = 'Error: ${e.toString()}';
      });
      _showSnack('Analysis failed. Try again.');
    }
  }

  void _simulateProgress() {
    bool _cancelled = false;
    final steps = [
      [0.10, 'Looking up handle...'],
      [0.20, 'Fetching similar rated users...'],
      [0.40, 'Analyzing peer submissions... (this takes a while)'],
      [0.65, 'Analyzing your submissions (last 800)...'],
      [0.85, 'Computing strong/mid/weak zones...'],
    ];
    int i = 0;
    Future.doWhile(() async {
      if (!mounted || !_isLoading || i >= steps.length) return false;
      await Future.delayed(const Duration(seconds: 8));
      if (!mounted || !_isLoading) return false;
      if (mounted) {
        setState(() {
          _progress = steps[i][0] as double;
          _statusMsg = steps[i][1] as String;
        });
      }
      i++;
      return mounted && _isLoading;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.black,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),

            // ── HEADER ────────────────────────────
            const Text('ANALYTICS',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 3.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),

            const SizedBox(height: 32),

            // ── CF HANDLE CARD ────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('CF',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A73E8))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _cfHandle.isEmpty ? 'No CF handle set' : _cfHandle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _cfHandle.isEmpty ? Colors.black38 : Colors.black,
                    ),
                  ),
                ),
                if (_cfHandle.isEmpty)
                  const Text('Set in Profile →',
                      style: TextStyle(fontSize: 11, color: Colors.black38)),
              ]),
            ),

            const SizedBox(height: 20),

            // ── ANALYSE BUTTON ────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isLoading || _cfHandle.isEmpty ? null : _runAnalysis,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const Text('ANALYSING...',
                        style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w700))
                    : const Text('RUN ANALYSIS',
                        style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 2.5,
                            fontWeight: FontWeight.w700)),
              ),
            ),

            // ── PROGRESS BAR ──────────────────────
            if (_isLoading || _statusMsg.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(_statusMsg,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54))),
                            Text('${(_progress * 100).toInt()}%',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black)),
                          ]),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.black.withOpacity(0.08),
                          color: Colors.black,
                          minHeight: 6,
                        ),
                      ),
                      if (_isLoading) ...[
                        const SizedBox(height: 8),
                        const Text(
                            '⚠️ This takes 30-60 seconds. Please wait...',
                            style:
                                TextStyle(fontSize: 10, color: Colors.black38)),
                      ],
                    ]),
              ),
            ],

            // ── RESULTS ───────────────────────────
            if (_hasData) ...[
              const SizedBox(height: 32),
              _buildResults(),
            ],

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ── BUILD RESULTS ─────────────────────────────
  Widget _buildResults() {
    final rating = _data['rating'] as int? ?? 0;
    final maxRating = _data['max_rating'] as int? ?? 0;
    final rank = _data['rank'] as String? ?? 'unrated';
    final strong = List<String>.from(_data['strong'] ?? []);
    final mid = List<String>.from(_data['mid'] ?? []);
    final weak = List<String>.from(_data['weak'] ?? []);
    final total = Map<String, dynamic>.from(_data['total'] ?? {});
    final good = Map<String, dynamic>.from(_data['good'] ?? {});
    final bad = Map<String, dynamic>.from(_data['bad'] ?? {});
    final tagcount = Map<String, dynamic>.from(_data['tagcount'] ?? {});

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── RATING CARD ─────────────────────────────
      _sectionLabel('RATING'),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _statCard('Current', '$rating', Colors.black)),
        const SizedBox(width: 12),
        Expanded(
            child: _statCard('Peak', '$maxRating', const Color(0xFF1A73E8))),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Rank', rank, _rankColor(rating))),
      ]),

      const SizedBox(height: 32),

      // ── STRONG TOPICS ────────────────────────────
      _sectionLabel('💪 STRONG TOPICS'),
      const SizedBox(height: 4),
      const Text('You solve these well — keep practicing to maintain',
          style: TextStyle(fontSize: 11, color: Colors.black38)),
      const SizedBox(height: 12),
      strong.isEmpty
          ? _emptyChip('Not enough data yet')
          : _tagGrid(strong, Colors.green),

      const SizedBox(height: 28),

      // ── NEEDS WORK ───────────────────────────────
      _sectionLabel('⚠️ NEEDS WORK'),
      const SizedBox(height: 4),
      const Text('Focus on these — your success rate is low',
          style: TextStyle(fontSize: 11, color: Colors.black38)),
      const SizedBox(height: 12),
      weak.isEmpty
          ? _emptyChip('No weak zones detected!')
          : _tagGrid(weak, Colors.redAccent),

      const SizedBox(height: 28),

      // ── DEVELOPING ───────────────────────────────
      _sectionLabel('📈 DEVELOPING'),
      const SizedBox(height: 4),
      const Text('Making progress — keep going!',
          style: TextStyle(fontSize: 11, color: Colors.black38)),
      const SizedBox(height: 12),
      mid.isEmpty
          ? _emptyChip('No mid-zone topics')
          : _tagGrid(mid, Colors.orange),

      const SizedBox(height: 32),

      // ── TAG BREAKDOWN TABLE ──────────────────────
      _sectionLabel('TAG BREAKDOWN'),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              const Expanded(
                  flex: 3,
                  child: Text('TAG',
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w700,
                          color: Colors.black45))),
              const Expanded(
                  child: Text('✅',
                      style: TextStyle(fontSize: 11),
                      textAlign: TextAlign.center)),
              const Expanded(
                  child: Text('❌',
                      style: TextStyle(fontSize: 11),
                      textAlign: TextAlign.center)),
              const Expanded(
                  child: Text('%',
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black45),
                      textAlign: TextAlign.center)),
            ]),
          ),
          Divider(height: 1, color: Colors.black.withOpacity(0.06)),

          // Rows — sorted by total desc
          ...(() {
            final entries = total.entries.toList();
            entries.sort((a, b) => (b.value as int).compareTo(a.value as int));
            return entries.take(20).map((e) {
              final tag = e.key;
              final tot = (total[tag] as int?) ?? 0;
              final g = (good[tag] as int?) ?? 0;
              final b = (bad[tag] as int?) ?? 0;
              final pct = tot > 0 ? (g / tot * 100).toStringAsFixed(0) : '0';
              final pctVal = tot > 0 ? g / tot : 0.0;
              final barColor = pctVal >= 0.75
                  ? Colors.green
                  : pctVal <= 0.6
                      ? Colors.redAccent
                      : Colors.orange;

              return Column(children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Expanded(
                        flex: 3,
                        child: Text(tag,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black),
                            overflow: TextOverflow.ellipsis)),
                    Expanded(
                        child: Text('$g',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('$b',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('$pct%',
                            style: TextStyle(
                                fontSize: 12,
                                color: barColor,
                                fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center)),
                  ]),
                ),
                // Mini progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pctVal.toDouble(),
                      backgroundColor: Colors.black.withOpacity(0.05),
                      color: barColor,
                      minHeight: 3,
                    ),
                  ),
                ),
                Divider(height: 1, color: Colors.black.withOpacity(0.04)),
              ]);
            }).toList();
          })(),
        ]),
      ),

      const SizedBox(height: 32),

      // ── TRENDING AMONG PEERS ─────────────────────
      _sectionLabel('🔥 TRENDING AMONG PEERS'),
      const SizedBox(height: 4),
      const Text('Most solved tags by similar-rated users',
          style: TextStyle(fontSize: 11, color: Colors.black38)),
      const SizedBox(height: 12),
      _tagGrid(
        tagcount.keys.take(10).toList(),
        const Color(0xFF1A73E8),
        counts: tagcount,
      ),
    ]);
  }

  // ── HELPERS ───────────────────────────────────
  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(
          fontSize: 10,
          letterSpacing: 3.0,
          fontWeight: FontWeight.w700,
          color: Colors.black));

  Widget _statCard(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Colors.black38, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color),
              overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _tagGrid(List<dynamic> tags, Color color,
      {Map<String, dynamic>? counts}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        final count = counts != null ? ' (${counts[tag]})' : '';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text('$tag$count',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        );
      }).toList(),
    );
  }

  Widget _emptyChip(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20)),
        child: Text(msg,
            style: const TextStyle(fontSize: 11, color: Colors.black38)),
      );

  Color _rankColor(int rating) {
    if (rating >= 2400) return const Color(0xFFFF0000);
    if (rating >= 2100) return const Color(0xFFFF8C00);
    if (rating >= 1900) return const Color(0xFFAA00AA);
    if (rating >= 1600) return const Color(0xFF0000FF);
    if (rating >= 1400) return const Color(0xFF03A89E);
    if (rating >= 1200) return const Color(0xFF008000);
    return Colors.black54;
  }
}
