import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/utils/friendly_errors.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../notifications/services/fcm_service.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({
    super.key,
    this.redirectLocation,
  });

  final String? redirectLocation;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstname = TextEditingController();
  final _lastname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _firstname.dispose();
    _lastname.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).register(
            firstname: _firstname.text.trim(),
            lastname: _lastname.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
      ref.invalidate(currentUserProvider);
      if (mounted) {
        context.replace(_safeRedirect(widget.redirectLocation));
      }
      unawaited(
        ref
            .read(fcmServiceProvider)
            .registerForCurrentUser()
            .catchError((error) {
          debugPrint('FCM error: $error');
        }),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyRegisterMessage(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _safeRedirect(String? value) {
    if (value == null || value.isEmpty || !value.startsWith('/')) {
      return '/account';
    }
    if (value.startsWith('//') ||
        value.startsWith('/login') ||
        value.startsWith('/register')) {
      return '/account';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Créer un compte',
        showBack: true,
        backFallbackLocation: '/account',
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ResponsivePagePadding(
              maxWidth: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: HelianthaLogo(
                      size: 92,
                      padding: 6,
                      showShadow: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _RegisterPanel(
                    formKey: _formKey,
                    firstname: _firstname,
                    lastname: _lastname,
                    email: _email,
                    password: _password,
                    confirmPassword: _confirmPassword,
                    loading: _loading,
                    error: _error,
                    onRegister: _register,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterPanel extends StatefulWidget {
  const _RegisterPanel({
    required this.formKey,
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.loading,
    required this.error,
    required this.onRegister,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstname;
  final TextEditingController lastname;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirmPassword;
  final bool loading;
  final String? error;
  final VoidCallback onRegister;

  @override
  State<_RegisterPanel> createState() => _RegisterPanelState();
}

class _RegisterPanelState extends State<_RegisterPanel> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadii.lg,
      shadow: true,
      child: Form(
        key: widget.formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Créer votre compte',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Retrouvez vos commandes et vos informations plus facilement.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 22),
              _RegisterField(
                controller: widget.firstname,
                label: 'Prénom',
                icon: Icons.person_outline_rounded,
                autofillHints: const [AutofillHints.givenName],
              ),
              const SizedBox(height: 12),
              _RegisterField(
                controller: widget.lastname,
                label: 'Nom',
                icon: Icons.badge_outlined,
                autofillHints: const [AutofillHints.familyName],
              ),
              const SizedBox(height: 12),
              _RegisterField(
                controller: widget.email,
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 12),
              _RegisterField(
                controller: widget.password,
                label: 'Mot de passe',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.muted,
                  ),
                  tooltip: _obscurePassword
                      ? 'Afficher le mot de passe'
                      : 'Masquer le mot de passe',
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: widget.confirmPassword,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => widget.onRegister(),
                validator: (value) {
                  if ((value ?? '').isEmpty) {
                    return 'Champ requis';
                  }
                  if (value != widget.password.text) {
                    return 'Les mots de passe ne correspondent pas.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.muted,
                    ),
                    tooltip: _obscureConfirmPassword
                        ? 'Afficher le mot de passe'
                        : 'Masquer le mot de passe',
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
              ),
              if (widget.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEFEF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.loading ? null : widget.onRegister,
                  icon: widget.loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded),
                  label:
                      Text(widget.loading ? 'Création...' : 'Créer un compte'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterField extends StatelessWidget {
  const _RegisterField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofillHints: autofillHints,
      validator: (value) =>
          (value ?? '').trim().isEmpty ? 'Champ requis' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
