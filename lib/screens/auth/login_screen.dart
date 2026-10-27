import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/realtime_notification_service.dart';
import '../../core/session.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../parent/parent_shell.dart';
import '../staff/staff_shell.dart';

enum _LoginTab { staff, parent }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _LoginTab _tab = _LoginTab.staff;
  bool _showRegister = false;
  bool _loading = false;
  String? _error;

  bool _obscureStaffPassword = true;
  bool _obscureParentPassword = true;
  bool _obscureRegPassword = true;
  bool _obscureRegPassword2 = true;

  final _authService = AuthService();

  final _staffUsername = TextEditingController();
  final _staffPassword = TextEditingController();

  final _parentPhone = TextEditingController();
  final _parentPassword = TextEditingController();
  final _regPhone = TextEditingController();
  final _regPassword = TextEditingController();
  final _regPassword2 = TextEditingController();
  final _regFullName = TextEditingController();

  @override
  void dispose() {
    _staffUsername.dispose();
    _staffPassword.dispose();
    _parentPhone.dispose();
    _parentPassword.dispose();
    _regPhone.dispose();
    _regPassword.dispose();
    _regPassword2.dispose();
    _regFullName.dispose();
    super.dispose();
  }

  Future<void> _submitStaff() async {
    if (_staffUsername.text.trim().isEmpty || _staffPassword.text.isEmpty) {
      setState(() => _error = 'Enter username and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _authService.staffLogin(_staffUsername.text.trim(), _staffPassword.text);
      if (!mounted) return;
      await context.read<Session>().applyStaffLogin(
            token: r.token, userId: r.userId, fullName: r.fullName, displayName: r.displayName, username: r.username,
            roleId: r.roleId, roleName: r.roleName, profilePicPath: r.profilePicPath, permissions: r.permissions, classRep: r.classRep,
          );
      if (!mounted) return;
      final realtime = context.read<RealtimeNotificationService>();
      realtime.onNotification = showLiveNotificationSnack;
      unawaited(realtime.connect(r.token));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StaffShell()));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not connect to server. Please check your internet connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitParentLogin() async {
    if (_parentPhone.text.trim().isEmpty || _parentPassword.text.isEmpty) {
      setState(() => _error = 'Enter phone number and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _authService.parentLogin(_parentPhone.text.trim(), _parentPassword.text);
      await _onParentLoggedIn(r);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not connect to server. Please check your internet connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitParentRegister() async {
    if (_regPhone.text.trim().isEmpty || _regPassword.text.isEmpty) {
      setState(() => _error = 'Enter phone number and password.');
      return;
    }
    if (_regPassword.text != _regPassword2.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_regPassword.text.length < 4) {
      setState(() => _error = 'Password must be at least 4 characters.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _authService.parentRegister(_regPhone.text.trim(), _regPassword.text, _regFullName.text.trim());
      await _onParentLoggedIn(r);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not connect to server. Please check your internet connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onParentLoggedIn(ParentLoginResult r) async {
    if (!mounted) return;
    await context.read<Session>().applyParentLogin(token: r.token, parentId: r.parentId, phone: r.phone, parentName: r.fullName);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ParentShell()));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final registering = _tab == _LoginTab.parent && _showRegister;
    final heading = registering ? 'Create account' : (_tab == _LoginTab.staff ? 'Welcome back' : 'Hello!');
    final sub = registering
        ? 'Use the phone number given to the school'
        : (_tab == _LoginTab.staff ? 'Sign in to manage your classes' : 'Attendance, marks, fees and updates');
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Stack(
          children: [
            // blue hero with soft discs, the same band as the Home header
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
              child: Container(
                height: top + 270,
                width: double.infinity,
                decoration: const BoxDecoration(gradient: AppGradients.primarySheen),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(top: -70, right: -60, child: _disc(220, 0.08)),
                    Positioned(top: 90, left: -80, child: _disc(190, 0.06)),
                    Positioned(bottom: -50, right: 40, child: _disc(120, 0.07)),
                    Positioned(top: top + 30, left: 26, child: Icon(Icons.auto_stories_rounded, size: 34, color: Colors.white.withValues(alpha: 0.18))),
                    Positioned(top: top + 70, right: 28, child: Icon(Icons.school_rounded, size: 40, color: Colors.white.withValues(alpha: 0.16))),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(22, top + 22, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 22, offset: const Offset(0, 10))],
                      ),
                      // the school's own logo + "RK Classes" lettering (red / blue), as on the signboard
                      child: Image.asset('assets/images/rk_logo_wordmark.png', width: 270, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Empowering Brighter Futures', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85), fontStyle: FontStyle.italic)),
                  const SizedBox(height: 26),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          boxShadow: [BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.16), blurRadius: 30, offset: const Offset(0, 14))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTabToggle(),
                            const SizedBox(height: 20),
                            Text(heading, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            const SizedBox(height: 18),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: _error == null
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding: const EdgeInsets.only(bottom: 14),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(_error ?? '', style: const TextStyle(color: AppColors.danger, fontSize: 12.5))),
                                          ],
                                        ),
                                      ),
                                    ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: KeyedSubtree(
                                key: ValueKey('$_tab-$_showRegister'),
                                child: _tab == _LoginTab.staff ? _buildStaffForm() : _buildParentForm(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_outlined, size: 14, color: AppColors.textMuted),
                      SizedBox(width: 5),
                      Text('Secure sign in  •  RK Classes', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _disc(double size, double alpha) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: Colors.white.withValues(alpha: alpha), shape: BoxShape.circle));

  Widget _buildTabToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          Expanded(child: _tabButton('Staff', Icons.badge_outlined, _LoginTab.staff)),
          Expanded(child: _tabButton('Parent / Student', Icons.family_restroom_rounded, _LoginTab.parent)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, IconData icon, _LoginTab tab) {
    final selected = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() { _tab = tab; _error = null; _showRegister = false; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: selected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscured,
    required VoidCallback onToggle,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscured,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: onToggle,
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }

  Widget _buildStaffForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _staffUsername, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 14),
        _passwordField(
          controller: _staffPassword,
          label: 'Password',
          obscured: _obscureStaffPassword,
          onToggle: () => setState(() => _obscureStaffPassword = !_obscureStaffPassword),
          onSubmitted: (_) => _submitStaff(),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _submitStaff,
          child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Sign In'),
        ),
      ],
    );
  }

  Widget _buildParentForm() {
    if (_showRegister) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: _regFullName, decoration: const InputDecoration(labelText: 'Full Name (optional)', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 14),
          TextField(controller: _regPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 14),
          _passwordField(
            controller: _regPassword,
            label: 'Password',
            obscured: _obscureRegPassword,
            onToggle: () => setState(() => _obscureRegPassword = !_obscureRegPassword),
          ),
          const SizedBox(height: 14),
          _passwordField(
            controller: _regPassword2,
            label: 'Confirm Password',
            obscured: _obscureRegPassword2,
            onToggle: () => setState(() => _obscureRegPassword2 = !_obscureRegPassword2),
            onSubmitted: (_) => _submitParentRegister(),
          ),
          const SizedBox(height: 8),
          const Text("Use the phone number given to the school: father, mother or the student's own number.",
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _submitParentRegister,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Account'),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: () => setState(() { _showRegister = false; _error = null; }), child: const Text('Already have an account? Login')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _parentPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined))),
        const SizedBox(height: 14),
        _passwordField(
          controller: _parentPassword,
          label: 'Password',
          obscured: _obscureParentPassword,
          onToggle: () => setState(() => _obscureParentPassword = !_obscureParentPassword),
          onSubmitted: (_) => _submitParentLogin(),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _submitParentLogin,
          child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Sign In'),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: () => setState(() { _showRegister = true; _error = null; }), child: const Text("New parent? Create an account")),
      ],
    );
  }
}
