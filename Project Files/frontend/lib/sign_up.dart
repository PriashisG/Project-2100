import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────
//  SIGN UP PAGE  (Supabase Auth + Profiles table)
// ─────────────────────────────────────────────
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // ── CONTROLLERS ─────────────────────────────
  final TextEditingController _nameController     = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _cfController       = TextEditingController();
  final TextEditingController _ccController       = TextEditingController();
  final TextEditingController _atController       = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading       = false;
  String? _errorMessage;

  final _formKey  = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _cfController.dispose();
    _ccController.dispose();
    _atController.dispose();
    super.dispose();
  }

  // ── SIGN UP WITH SUPABASE ─────────────────────
  Future<void> _onSignUpPressed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Create auth user in Supabase Auth
      final response = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = response.user?.id;
      if (userId == null) throw Exception('Sign up failed');

      // Step 2: Save extra info to 'profiles' table in PostgreSQL
      // 📌 Make sure you created this table in Supabase (see setup below)
      await _supabase.from('profiles').insert({
        'id':               userId,                         // links to auth.users
        'name':             _nameController.text.trim(),
        'username':         _usernameController.text.trim(),
        'email':            _emailController.text.trim(),
        'cf_handle':        _cfController.text.trim(),      // Codeforces
        'cc_handle':        _ccController.text.trim(),      // Codechef
        'at_handle':        _atController.text.trim(),      // Atcoder
        'created_at':       DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Account created! Check your email to verify.')),
        );
        Navigator.pop(context); // go back to login
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } on PostgrestException catch (e) {
      setState(() => _errorMessage = 'DB Error: ${e.message}');
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── BACK BUTTON ───────────────────────────
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back,
                      color: Colors.black, size: 22),
                ),

                const SizedBox(height: 40),

                // ── HEADING ───────────────────────────────
                const Text(
                  'GET STARTED',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 3.0,
                    color: Colors.black54,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Create your\naccount',
                  style: TextStyle(
                    fontSize: 34,
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 36),

                // ── ERROR MESSAGE ─────────────────────────
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ════════════════════════════════════════
                //  SECTION: PERSONAL INFO
                // ════════════════════════════════════════
                _sectionLabel('PERSONAL INFO'),
                const SizedBox(height: 16),

                // ── FULL NAME ─────────────────────────────
                _fieldLabel('FULL NAME'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _nameController,
                  hint: 'John Doe',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),

                const SizedBox(height: 20),

                // ── USERNAME ──────────────────────────────
                _fieldLabel('USERNAME'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _usernameController,
                  hint: '@your_username',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Username is required' : null,
                ),

                const SizedBox(height: 20),

                // ── EMAIL ─────────────────────────────────
                _fieldLabel('EMAIL'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _emailController,
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // ── PASSWORD ──────────────────────────────
                _fieldLabel('PASSWORD'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontSize: 15, color: Colors.black),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                  decoration: _inputDecoration('••••••••').copyWith(
                    suffixIcon: GestureDetector(
                      onTap: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.black38,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // ════════════════════════════════════════
                //  SECTION: CP HANDLES
                // ════════════════════════════════════════
                _sectionLabel('CP HANDLES'),
                const SizedBox(height: 4),
                const Text(
                  'Optional — you can add these later',
                  style: TextStyle(
                      fontSize: 11, color: Colors.black38, letterSpacing: 0.3),
                ),
                const SizedBox(height: 16),

                // ── CODEFORCES ────────────────────────────
                _fieldLabel('CODEFORCES HANDLE'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _cfController,
                  hint: 'e.g. tourist',
                  prefixIcon: _badge('CF', const Color(0xFF1A73E8)),
                  required: false,
                ),

                const SizedBox(height: 20),

                // ── CODECHEF ──────────────────────────────
                _fieldLabel('CODECHEF HANDLE'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _ccController,
                  hint: 'e.g. gennady',
                  prefixIcon: _badge('CC', const Color(0xFF5B4638)),
                  required: false,
                ),

                const SizedBox(height: 20),

                // ── ATCODER ───────────────────────────────
                _fieldLabel('ATCODER HANDLE'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _atController,
                  hint: 'e.g. rng_58',
                  prefixIcon: _badge('AT', const Color(0xFF222222)),
                  required: false,
                ),

                const SizedBox(height: 48),

                // ── CREATE ACCOUNT BUTTON ─────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onSignUpPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'CREATE ACCOUNT',
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 2.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── ALREADY HAVE ACCOUNT ──────────────────
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: RichText(
                      text: const TextSpan(
                        text: 'Already have an account?  ',
                        style: TextStyle(color: Colors.black45, fontSize: 13),
                        children: [
                          TextSpan(
                            text: 'Log in',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────
  Widget _sectionLabel(String label) => Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 3.0,
                  fontWeight: FontWeight.w700,
                  color: Colors.black)),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: Colors.black.withOpacity(0.15))),
        ],
      );

  Widget _fieldLabel(String label) => Text(
        label,
        style: const TextStyle(
            fontSize: 10,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w600,
            color: Colors.black54),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 1.2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 1.2)),
      );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefixIcon,
    bool required = true,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15, color: Colors.black),
        validator: validator ??
            (required
                ? (v) => v == null || v.trim().isEmpty
                    ? 'This field is required'
                    : null
                : null),
        decoration: _inputDecoration(hint).copyWith(prefixIcon: prefixIcon),
      );

  Widget _badge(String label, Color color) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.5)),
        ),
      );
}