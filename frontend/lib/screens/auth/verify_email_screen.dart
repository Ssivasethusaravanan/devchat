import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../bloc/auth/auth_bloc.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthEmailVerified) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green),
            );
            context.go('/login');
          } else if (state is AuthVerificationResent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green),
            );
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: theme.colorScheme.error),
            );
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Email icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.mark_email_read_outlined, size: 36, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 24),
                  Text('Verify Your Email', style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 12),
                  Text(
                    'We sent a 6-digit code to',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.textTheme.bodySmall?.color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Uri.decodeComponent(widget.email),
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 40),

                  // 6-digit code input
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) => _buildCodeField(i, theme)),
                  ),
                  const SizedBox(height: 32),

                  // Verify button
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoading;
                      return SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _verify,
                          child: isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Verify Email'),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Resend code
                  TextButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(
                        AuthResendVerificationRequested(email: Uri.decodeComponent(widget.email)),
                      );
                    },
                    child: Text(
                      'Didn\'t get the code? Resend',
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ),

                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text('Back to Sign In', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeField(int index, ThemeData theme) {
    return Container(
      width: 48,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          // Auto-submit when all 6 digits entered
          if (_code.length == 6) {
            _verify();
          }
        },
      ),
    );
  }

  void _verify() {
    if (_code.length == 6) {
      context.read<AuthBloc>().add(AuthVerifyEmailRequested(
            email: Uri.decodeComponent(widget.email),
            code: _code,
          ));
    }
  }
}
