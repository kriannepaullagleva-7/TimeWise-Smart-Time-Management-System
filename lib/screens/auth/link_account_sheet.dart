import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_styles.dart';
import '../../utils/feedback.dart';
import '../../utils/validators.dart';
import '../../widgets/ui.dart';

/// Upgrades a guest to an email account. The uid does not change, so every
/// task and event the guest created stays in the account.
Future<void> showLinkAccountSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _LinkAccountForm());
}

class _LinkAccountForm extends StatefulWidget {
  const _LinkAccountForm();

  @override
  State<_LinkAccountForm> createState() => _LinkAccountFormState();
}

class _LinkAccountFormState extends State<_LinkAccountForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;
  bool _attempted = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _attempted = true);
    if (Validators.name(_name.text) != null ||
        Validators.email(_email.text) != null ||
        Validators.newPassword(_password.text) != null) {
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.linkGuestToEmail(
      email: _email.text.trim(),
      name: _name.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      showMessage(context, 'Account created. Your data is now saved to ${_email.text.trim()}.');
    } else {
      showMessage(context, auth.errorMessage ?? 'Could not create the account.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.select<AuthProvider, bool>((a) => a.isLoading);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Create your account', style: context.h2),
          const SizedBox(height: 4),
          Text('Everything you have added so far will be kept.', style: context.bodyMuted),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Name',
            hint: 'Jane Doe',
            controller: _name,
            icon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            errorText: _attempted ? Validators.name(_name.text) : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: 'Email',
            hint: 'you@email.com',
            controller: _email,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            errorText: _attempted ? Validators.email(_email.text) : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: 'Password',
            hint: 'At least 6 characters',
            controller: _password,
            icon: Icons.lock_outline,
            obscureText: !_show,
            textInputAction: TextInputAction.done,
            errorText: _attempted ? Validators.newPassword(_password.text) : null,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => busy ? null : _submit(),
            suffix: IconButton(
              tooltip: _show ? 'Hide password' : 'Show password',
              icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(label: 'Create account', loading: busy, onPressed: _submit),
        ],
      ),
    );
  }
}
