import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design/tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/app/app.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;

  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      final email = _emailController.text.trim();
      _emailError = email.isEmpty
          ? 'Ingresa tu correo'
          : !email.contains('@')
              ? 'Ingresa un correo válido'
              : null;
      _passwordError = _passwordController.text.isEmpty
          ? 'Ingresa tu contraseña'
          : null;
      if (_emailError != null || _passwordError != null) valid = false;
    });
    return valid;
  }

  Future<void> _login() async {
    if (!_validate()) return;
    await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _intro,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_intro.value);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 16),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 48),
                      // Eyebrow + headline. Big, with intentional negative
                      // tracking so it reads as a brand statement, not a
                      // form label.
                      Text('Driver Cockpit', style: AppTypography.overline.copyWith(letterSpacing: 4)),
                      const SizedBox(height: 16),
                      Text('Iniciá tu turno.', style: AppTypography.h1),
                      const SizedBox(height: 8),
                      Text(
                        'Acceso solo para conductores autorizados de la empresa.',
                        style: AppTypography.body.copyWith(color: AppColors.fgSecondary),
                      ),
                      const SizedBox(height: 48),

                      // Auth error banner — surfaces backend-side errors
                      // without masking inline field errors.
                      if (authState.error != null) ...[
                        _ErrorBanner(message: authState.error!),
                        const SizedBox(height: 20),
                      ],

                      AppTextField(
                        controller: _emailController,
                        label: 'Correo',
                        placeholder: 'tu@empresa.com',
                        leadingIcon: Icons.alternate_email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofocus: true,
                        errorText: _emailError,
                        onChanged: (_) {
                          if (_emailError != null) setState(() => _emailError = null);
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        placeholder: '••••••••',
                        leadingIcon: Icons.lock_outline_rounded,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        errorText: _passwordError,
                        onSubmitted: (_) => _login(),
                        onChanged: (_) {
                          if (_passwordError != null) setState(() => _passwordError = null);
                        },
                      ),
                      const SizedBox(height: 32),
                      AppButton.primaryCta(
                        label: 'Entrar',
                        icon: Icons.arrow_forward_rounded,
                        isLoading: authState.isLoading,
                        onPressed: _login,
                      ),

                      const SizedBox(height: 32),
                      const _Divider(),
                      const SizedBox(height: 24),
                      // Help footer — discreet but reachable.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.support_agent_rounded, size: 14, color: AppColors.fgTertiary),
                          const SizedBox(width: 6),
                          Text(
                            '¿Problemas para entrar? Contactá a tu coordinador.',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.fgTertiary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.statusFailedBg,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.accentDanger.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: AppColors.accentDanger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(color: AppColors.fgPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.borderSubtle)),
      ],
    );
  }
}
