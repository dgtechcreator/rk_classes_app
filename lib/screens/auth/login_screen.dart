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
            token: r.token, userId: r.userId, fullName: r.fullName, username: r.username,
            roleId: r.roleId, roleName: r.roleName, permissions: r.permissions,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(child: Image.asset('assets/images/rk_logo_full.png', height: 72, fit: BoxFit.contain)),
              const SizedBox(height: 32),
              _buildTabToggle(),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],
              if (_tab == _LoginTab.staff) _buildStaffForm() else _buildParentForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Expanded(child: _tabButton('Staff Login', _LoginTab.staff)),
          Expanded(child: _tabButton('Parent Login', _LoginTab.parent)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _LoginTab tab) {
    final selected = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() { _tab = tab; _error = null; _showRegister = false; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
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
          const Text('Use the same phone number registered as father/mother contact for your child.',
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
        TextField(controller: _parentPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined))),
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
