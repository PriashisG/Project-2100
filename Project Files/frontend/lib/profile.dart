import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────
//  PROFILE PAGE
// ─────────────────────────────────────────────
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _supabase = Supabase.instance.client;

  // ── CONTROLLERS ─────────────────────────────
  final _cfController = TextEditingController();
  final _ccController = TextEditingController();
  final _atController = TextEditingController();

  // ── USER DATA ────────────────────────────────
  String _name = '';
  String _username = '';
  String _email = '';
  String _cfHandle = '';
  String _ccHandle = '';
  String _atHandle = '';

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  String? _message;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _cfController.dispose();
    _ccController.dispose();
    _atController.dispose();
    super.dispose();
  }

  // ── LOAD PROFILE FROM SUPABASE ────────────────
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
        _name = data['name'] ?? '';
        _username = data['username'] ?? '';
        _email = data['email'] ?? '';
        _cfHandle = data['cf_handle'] ?? '';
        _ccHandle = data['cc_handle'] ?? '';
        _atHandle = data['at_handle'] ?? '';

        // pre-fill controllers
        _cfController.text = _cfHandle;
        _ccController.text = _ccHandle;
        _atController.text = _atHandle;

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ── SAVE HANDLES TO SUPABASE ──────────────────
  Future<void> _saveHandles() async {
    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('profiles')
          .update({
            'cf_handle': _cfController.text.trim(),
            'cc_handle': _ccController.text.trim(),
            'at_handle': _atController.text.trim(),
          })
          .eq('id', userId);

      setState(() {
        _cfHandle = _cfController.text.trim();
        _ccHandle = _ccController.text.trim();
        _atHandle = _atController.text.trim();
        _isEditing = false;
        _isError = false;
        _message = 'Handles updated successfully!';
      });
    } on PostgrestException catch (e) {
      setState(() {
        _isError = true;
        _message = 'Error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _message = 'Something went wrong. Try again.';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── LOGOUT ────────────────────────────────────
  Future<void> _onLogout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      // 📌 NAVIGATE back to main page after logout
      Navigator.of(context).popUntil((route) => route.isFirst);
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PROFILE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 3.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      GestureDetector(
                        onTap: _onLogout,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black26, width: 1),
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

                  const SizedBox(height: 40),

                  // ── AVATAR + NAME ────────────────────────
                  Center(
                    child: Column(
                      children: [
                        // AVATAR CIRCLE WITH INITIAL
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 32,
                                fontFamily: 'Georgia',
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // NAME
                        Text(
                          _name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // USERNAME
                        Text(
                          '@$_username',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black45,
                            letterSpacing: 0.3,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // EMAIL
                        Text(
                          _email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                  Divider(color: Colors.black.withOpacity(0.1)),
                  const SizedBox(height: 32),

                  // ════════════════════════════════════════
                  //  CP HANDLES SECTION
                  // ════════════════════════════════════════
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel('CP HANDLES'),

                      // EDIT / CANCEL BUTTON
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_isEditing) {
                              // cancel — reset to saved values
                              _cfController.text = _cfHandle;
                              _ccController.text = _ccHandle;
                              _atController.text = _atHandle;
                              _message = null;
                            }
                            _isEditing = !_isEditing;
                          });
                        },
                        child: Text(
                          _isEditing ? 'CANCEL' : 'EDIT',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w700,
                            color: _isEditing ? Colors.redAccent : Colors.black,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── SUCCESS / ERROR MESSAGE ──────────────
                  if (_message != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isError
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isError
                              ? Colors.red.shade200
                              : Colors.green.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isError
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color: _isError ? Colors.redAccent : Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _message!,
                              style: TextStyle(
                                fontSize: 12,
                                color: _isError
                                    ? Colors.redAccent
                                    : Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── CODEFORCES ───────────────────────────
                  _fieldLabel('CODEFORCES HANDLE'),
                  const SizedBox(height: 8),
                  _isEditing
                      ? _editField(
                          controller: _cfController,
                          hint: 'e.g. tourist',
                          badge: 'CF',
                          badgeColor: const Color(0xFF1A73E8),
                        )
                      : _handleDisplay(
                          value: _cfHandle,
                          badge: 'CF',
                          badgeColor: const Color(0xFF1A73E8),
                        ),

                  const SizedBox(height: 20),

                  // ── CODECHEF ─────────────────────────────
                  _fieldLabel('CODECHEF HANDLE'),
                  const SizedBox(height: 8),
                  _isEditing
                      ? _editField(
                          controller: _ccController,
                          hint: 'e.g. gennady',
                          badge: 'CC',
                          badgeColor: const Color(0xFF5B4638),
                        )
                      : _handleDisplay(
                          value: _ccHandle,
                          badge: 'CC',
                          badgeColor: const Color(0xFF5B4638),
                        ),

                  const SizedBox(height: 20),

                  // ── ATCODER ──────────────────────────────
                  _fieldLabel('ATCODER HANDLE'),
                  const SizedBox(height: 8),
                  _isEditing
                      ? _editField(
                          controller: _atController,
                          hint: 'e.g. rng_58',
                          badge: 'AT',
                          badgeColor: const Color(0xFF222222),
                        )
                      : _handleDisplay(
                          value: _atHandle,
                          badge: 'AT',
                          badgeColor: const Color(0xFF222222),
                        ),

                  const SizedBox(height: 32),

                  // ── SAVE BUTTON (only in edit mode) ──────
                  if (_isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveHandles,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'SAVE CHANGES',
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 2.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  // ── HELPERS ───────────────────────────────────

  Widget _sectionLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 3.0,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    ),
  );

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 2.5,
      fontWeight: FontWeight.w600,
      color: Colors.black54,
    ),
  );

  // Read-only handle display
  Widget _handleDisplay({
    required String value,
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: badgeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value.isNotEmpty ? value : 'Not set',
            style: TextStyle(
              fontSize: 15,
              color: value.isNotEmpty ? Colors.black : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  // Editable handle field
  Widget _editField({
    required TextEditingController controller,
    required String hint,
    required String badge,
    required Color badgeColor,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 15, color: Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: badgeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black, width: 1.2),
        ),
      ),
    );
  }
}
