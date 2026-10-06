import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_styles.dart';
import '../../utils/feedback.dart';
import '../../utils/validators.dart';
import '../../widgets/mascot_logo.dart';
import '../../widgets/ui.dart';

/// Sign in, create an account, continue with Google or continue as a guest.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignIn = true;
  bool _showPassword = false;
  bool _attempted = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? get _nameError => _attempted && !_isSignIn ? Validators.name(_nameController.text) : null;
  String? get _emailError => _attempted ? Validators.email(_emailController.text) : null;
  String? get _passwordError => !_attempted
      ? null
      : (_isSignIn ? Validators.existingPassword(_passwordController.text) : Validators.newPassword(_passwordController.text));

  /// Runs an auth call, then returns to the root so [AuthWrapper] shows the
  /// signed-in app. Failures are shown as a message and the form stays put.
  Future<void> _run(Future<bool> Function(AuthProvider) action) async {
    final auth = context.read<AuthProvider>();
    final ok = await action(auth);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (auth.errorMessage != null) {
      showMessage(context, auth.errorMessage!, error: true);
    }
  }

  Future<void> _submit() async {
    setState(() => _attempted = true);
    if (_emailError != null || _passwordError != null || _nameError != null) return;
    FocusScope.of(context).unfocus();
    await _run((auth) => _isSignIn
        ? auth.signIn(_emailController.text.trim(), _passwordController.text)
        : auth.signUp(_emailController.text.trim(), _nameController.text.trim(), _passwordController.text));
  }

  Future<void> _forgotPassword() async {
    final auth = context.read<AuthProvider>();
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPasswordDialog(initialEmail: _emailController.text.trim()),
    );
    if (email == null || !mounted) return;

    final ok = await auth.sendPasswordReset(email);
    if (!mounted) return;
    showMessage(
      context,
      ok
          ? 'If an account exists for $email, a reset link is on its way.'
          : (auth.errorMessage ?? 'Could not send the reset email.'),
      error: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.select<AuthProvider, bool>((a) => a.isLoading);
    final linkColor = readableOn(context.primary, context.cs.surface);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: context.primaryGradient),
                      child: const Center(child: MascotLogo(size: 72)),
                    ),
                    const SizedBox(height: 16),
                    Text('TimeWise', style: context.h1),
                    const SizedBox(height: 4),
                    Text(_isSignIn ? 'Welcome back' : 'Create your account', style: context.bodyMuted),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: context.cs.surfaceContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Row(
                    children: [
                      Expanded(child: _ModeTab(label: 'Sign In', selected: _isSignIn, onTap: () => setState(() => _isSignIn = true))),
                      Expanded(child: _ModeTab(label: 'Sign Up', selected: !_isSignIn, onTap: () => setState(() => _isSignIn = false))),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!_isSignIn) ...[
                  LabeledField(
                    label: 'Name',
                    hint: 'Jane Doe',
                    controller: _nameController,
                    icon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    errorText: _nameError,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                ],
                LabeledField(
                  label: 'Email',
                  hint: 'you@email.com',
                  controller: _emailController,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  errorText: _emailError,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                LabeledField(
                  label: 'Password',
                  hint: _isSignIn ? 'Your password' : 'At least 6 characters',
                  controller: _passwordController,
                  icon: Icons.lock_outline,
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: [_isSignIn ? AutofillHints.password : AutofillHints.newPassword],
                  errorText: _passwordError,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => busy ? null : _submit(),
                  suffix: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                if (_isSignIn)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: busy ? null : _forgotPassword,
                      style: TextButton.styleFrom(minimumSize: const Size(48, 44), foregroundColor: linkColor),
                      child: const Text('Forgot password?', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  )
                else
                  const SizedBox(height: 12),
                const SizedBox(height: 4),
                GradientButton(
                  label: _isSignIn ? 'Sign In' : 'Create Account',
                  loading: busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: context.cs.outline)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or continue with', style: context.label),
                    ),
                    Expanded(child: Divider(color: context.cs.outline)),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _run((auth) => auth.signInWithGoogle()),
                  icon: const Icon(Icons.account_circle_outlined, size: 22),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: context.cs.onSurface),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy ? null : () => _run((auth) => auth.signInAsGuest()),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: context.cs.onSurfaceVariant),
                  child: const Text('Continue as Guest'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(_isSignIn ? "Don't have an account?" : 'Already have an account?', style: context.bodyMuted),
                    TextButton(
                      onPressed: () => setState(() => _isSignIn = !_isSignIn),
                      style: TextButton.styleFrom(minimumSize: const Size(48, 44), foregroundColor: linkColor),
                      child: Text(_isSignIn ? 'Sign Up' : 'Sign In', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? context.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: selected ? Colors.white : context.cs.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for the account email. Owns its controller so the controller lives as
/// long as the dialog's closing animation (disposing it from the caller would
/// leave the animating TextField with a dead controller).
class _ResetPasswordDialog extends StatefulWidget {
  final String initialEmail;
  const _ResetPasswordDialog({required this.initialEmail});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final _controller = TextEditingController(text: widget.initialEmail);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final problem = Validators.email(_controller.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Enter your account email and we'll send you a link to choose a new password.", style: context.bodyMuted),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: 'Email', errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Send link')),
      ],
    );
  }
}
