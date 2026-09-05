import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:runova/core/theme/runova_theme.dart';
import 'package:runova/features/auth/presentation/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _displayName = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authControllerProvider.notifier).login(
          email: _email.text,
          username: _username.text,
          displayName: _displayName.text,
        );
    if (success && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.route_rounded, size: 64, color: RunovaColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'RUNOVA',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const Text(
                      'Create your runner profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: RunovaColors.textMuted),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      key: const Key('email-field'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) => value != null && value.contains('@')
                          ? null
                          : 'Enter a valid email',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('username-field'),
                      controller: _username,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (value) => value != null && value.trim().length >= 3
                          ? null
                          : 'Use at least 3 characters',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _displayName,
                      decoration: const InputDecoration(labelText: 'Display name (optional)'),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      key: const Key('direct-login-button'),
                      onPressed: auth.isLoading ? null : _submit,
                      child: Text(auth.isLoading ? 'CREATING…' : 'CONTINUE'),
                    ),
                    if (auth.hasError) ...[
                      const SizedBox(height: 14),
                      Text(
                        _errorMessage(auth.error),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: RunovaColors.danger),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'Development login for the MVP. Email OTP will replace this before release.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: RunovaColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _errorMessage(Object? error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['detail'] is String) {
      return data['detail'] as String;
    }
    return 'Cannot reach the Runova server.';
  }
  return 'Could not create the account.';
}
