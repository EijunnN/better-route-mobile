import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  String? _emailError;
  String? _passwordError;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        _emailError = 'Ingresa tu correo';
        valid = false;
      } else if (!email.contains('@')) {
        _emailError = 'Ingresa un correo valido';
        valid = false;
      } else {
        _emailError = null;
      }

      if (_passwordController.text.isEmpty) {
        _passwordError = 'Ingresa tu contrasena';
        valid = false;
      } else {
        _passwordError = null;
      }
    });
    return valid;
  }

  Future<void> _login() async {
    if (!_validate()) return;

    // Hide keyboard
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    await ref.read(authProvider.notifier).login(email, password);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 32),

                    // Branding
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.local_shipping_rounded,
                              size: 40,
                              color: theme.colorScheme.primaryForeground,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'BetterRoute',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Inicia sesion para continuar').muted(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Form card
                    Card(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email field
                          const Text('Correo electronico').semiBold().small(),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !authState.isLoading,
                            placeholder: const Text('correo@ejemplo.com'),
                            onSubmitted: (_) {
                              _passwordFocus.requestFocus();
                            },
                          ),
                          if (_emailError != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _emailError!,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.destructive,
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Password field
                          const Text('Contrasena').semiBold().small(),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            obscureText: true,
                            enabled: !authState.isLoading,
                            placeholder: const Text('Tu contrasena'),
                            onSubmitted: (_) => _login(),
                            features: const [
                              InputFeature.passwordToggle(),
                            ],
                          ),
                          if (_passwordError != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _passwordError!,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.destructive,
                              ),
                            ),
                          ],

                          // Error message
                          if (authState.error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.destructive
                                    .withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: theme.colorScheme.destructive,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      authState.error!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.colorScheme.destructive,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Login button
                          SizedBox(
                            height: 56,
                            child: PrimaryButton(
                              onPressed: authState.isLoading ? null : _login,
                              size: ButtonSize.large,
                              child: authState.isLoading
                                  ? CircularProgressIndicator(
                                      size: 24,
                                      strokeWidth: 2.5,
                                      color: theme.colorScheme.primaryForeground,
                                    )
                                  : const Text(
                                      'Iniciar sesion',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Footer
                    Center(
                      child: const Text('App exclusiva para conductores')
                          .muted()
                          .small(),
                    ),

                    const SizedBox(height: 24),
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
