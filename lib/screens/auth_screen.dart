import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // ── mode: 'signup' | 'login' ──
  String _mode = 'login';

  // ── Sign-up state ──
  // step 0 = phone, 1 = OTP, 2 = profile form
  int _signupStep = 0;
  final _signupPhoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmController = TextEditingController();
  final _referralController = TextEditingController();
  bool _obscureSignupPassword = true;
  bool _obscureSignupConfirm = true;

  // ── Login state ──
  final _loginPhoneController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;

  String? _errorMessage;

  @override
  void dispose() {
    _signupPhoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmController.dispose();
    _referralController.dispose();
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  String _formatted(String phone) {
    final p = phone.trim();
    if (p.startsWith('+')) return p;
    return '+91$p';
  }

  void _switchMode(String mode) {
    setState(() {
      _mode = mode;
      _errorMessage = null;
      _signupStep = 0;
      _otpController.clear();
      _nameController.clear();
      _signupPasswordController.clear();
      _signupConfirmController.clear();
      _referralController.clear();
    });
  }

  // ── SIGN-UP STEP 0: send OTP ──
  Future<void> _sendSignupOtp() async {
    final phone = _signupPhoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _errorMessage = 'Enter a valid 10-digit phone number.');
      return;
    }
    setState(() => _errorMessage = null);
    FocusScope.of(context).unfocus();
    await context.read<AuthProvider>().sendSignUpOtp(
      phoneNumber: _formatted(phone),
      onCodeSent: (_) => setState(() => _signupStep = 1),
      onError: (e) => setState(() => _errorMessage = e),
    );
  }

  // ── SIGN-UP STEP 1: verify OTP ──
  Future<void> _verifySignupOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _errorMessage = 'Enter the 6-digit OTP.');
      return;
    }
    setState(() => _errorMessage = null);
    FocusScope.of(context).unfocus();
    final isNew = await context.read<AuthProvider>().verifySignUpOtp(
      smsCode: otp,
      onError: (e) => setState(() => _errorMessage = e),
    );
    if (!mounted) return;
    if (isNew == true) {
      setState(() => _signupStep = 2);
    } else if (isNew == false) {
      // Existing user — switch to login, pre-fill phone
      await context.read<AuthProvider>().signOut();
      _loginPhoneController.text = _signupPhoneController.text.trim();
      setState(() {
        _mode = 'login';
        _signupStep = 0;
        _errorMessage = 'This number is already registered. Please log in.';
      });
    }
  }

  // ── SIGN-UP STEP 2: complete profile ──
  Future<void> _completeSignup() async {
    final name = _nameController.text.trim();
    final pass = _signupPasswordController.text;
    final confirm = _signupConfirmController.text;

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }
    if (pass != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    setState(() => _errorMessage = null);
    FocusScope.of(context).unfocus();
    final success = await context.read<AuthProvider>().completeSignUp(
      name: name,
      password: pass,
      referralCode: _referralController.text.trim().isEmpty
          ? null
          : _referralController.text.trim(),
      onError: (e) => setState(() => _errorMessage = e),
    );
    if (success && mounted) Navigator.of(context).pop();
  }

  // ── LOGIN ──
  Future<void> _login() async {
    final phone = _loginPhoneController.text.trim();
    final pass = _loginPasswordController.text;
    if (phone.length < 10) {
      setState(() => _errorMessage = 'Enter a valid phone number.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _errorMessage = 'Enter your password.');
      return;
    }
    setState(() => _errorMessage = null);
    FocusScope.of(context).unfocus();
    final success = await context.read<AuthProvider>().loginWithPhoneAndPassword(
      phoneNumber: _formatted(phone),
      password: pass,
      onError: (e) => setState(() => _errorMessage = e),
    );
    if (success && mounted) Navigator.of(context).pop();
  }

  void _openForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ForgotPasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            if (_mode == 'signup' && _signupStep > 0) {
              setState(() {
                _signupStep = _signupStep - 1;
                _errorMessage = null;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.shadowSm,
            ),
            child: Icon(
              (_mode == 'signup' && _signupStep > 0)
                  ? Icons.arrow_back
                  : Icons.close,
              size: 20,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Logo ──
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radius2XL),
                      boxShadow: AppTheme.shadowGreen,
                    ),
                    child: const Center(
                      child: Text(
                        'S',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                ),

                const SizedBox(height: 28),

                // ── Mode Toggle ──
                if (_mode == 'signup' && _signupStep == 0 || _mode == 'login')
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: AppTheme.shadowSm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ToggleTab(
                            label: 'Log In',
                            active: _mode == 'login',
                            onTap: () => _switchMode('login'),
                          ),
                          _ToggleTab(
                            label: 'Sign Up',
                            active: _mode == 'signup',
                            onTap: () => _switchMode('signup'),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 350.ms),

                const SizedBox(height: 30),

                // ── Error Banner ──
                AnimatedSize(
                  duration: 250.ms,
                  child: _errorMessage != null
                      ? Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed.withValues(alpha: 0.06),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                            border: Border.all(
                                color:
                                    AppTheme.errorRed.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: AppTheme.errorRed, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: AppTheme.errorRed,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().shake(duration: 400.ms)
                      : const SizedBox.shrink(),
                ),

                // ── Content ──
                AnimatedSwitcher(
                  duration: 300.ms,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _mode == 'login'
                      ? _LoginForm(
                          key: const ValueKey('login'),
                          phoneController: _loginPhoneController,
                          passwordController: _loginPasswordController,
                          obscurePassword: _obscureLoginPassword,
                          onToggleObscure: () => setState(
                              () => _obscureLoginPassword = !_obscureLoginPassword),
                          isLoading: auth.isLoading,
                          onSubmit: _login,
                          onForgotPassword: _openForgotPassword,
                        )
                      : _SignupContent(
                          key: ValueKey('signup_$_signupStep'),
                          step: _signupStep,
                          phoneController: _signupPhoneController,
                          otpController: _otpController,
                          nameController: _nameController,
                          passwordController: _signupPasswordController,
                          confirmController: _signupConfirmController,
                          referralController: _referralController,
                          obscurePassword: _obscureSignupPassword,
                          obscureConfirm: _obscureSignupConfirm,
                          onToggleObscurePassword: () => setState(
                              () => _obscureSignupPassword = !_obscureSignupPassword),
                          onToggleObscureConfirm: () => setState(
                              () => _obscureSignupConfirm = !_obscureSignupConfirm),
                          isLoading: auth.isLoading,
                          onSendOtp: _sendSignupOtp,
                          onVerifyOtp: _verifySignupOtp,
                          onComplete: _completeSignup,
                        ),
                ),

                const SizedBox(height: 40),

                Center(
                  child: Text(
                    'By continuing, you agree to our\nTerms of Service and Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textHint,
                      height: 1.5,
                    ),
                  ).animate(delay: 400.ms).fadeIn(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Toggle Tab
// ═══════════════════════════════════════════
class _ToggleTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: active ? AppTheme.shadowGreen : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Sign-up Content (3 steps)
// ═══════════════════════════════════════════
class _SignupContent extends StatelessWidget {
  final int step;
  final TextEditingController phoneController;
  final TextEditingController otpController;
  final TextEditingController nameController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final TextEditingController referralController;
  final bool obscurePassword;
  final bool obscureConfirm;
  final VoidCallback onToggleObscurePassword;
  final VoidCallback onToggleObscureConfirm;
  final bool isLoading;
  final VoidCallback onSendOtp;
  final VoidCallback onVerifyOtp;
  final VoidCallback onComplete;

  const _SignupContent({
    super.key,
    required this.step,
    required this.phoneController,
    required this.otpController,
    required this.nameController,
    required this.passwordController,
    required this.confirmController,
    required this.referralController,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.onToggleObscurePassword,
    required this.onToggleObscureConfirm,
    required this.isLoading,
    required this.onSendOtp,
    required this.onVerifyOtp,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (step == 0) return _buildPhoneStep(context);
    if (step == 1) return _buildOtpStep(context);
    return _buildProfileStep(context);
  }

  Widget _buildPhoneStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          title: 'Create Account',
          subtitle: "Enter your phone number to get started",
          icon: Icons.waving_hand_rounded,
        ),
        const SizedBox(height: 28),
        _phoneField(),
        const SizedBox(height: 24),
        _primaryButton(label: 'Send OTP', onPressed: onSendOtp, isLoading: isLoading),
      ],
    );
  }

  Widget _buildOtpStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          title: 'Verify Number',
          subtitle: 'Enter the 6-digit code sent to\n+91 ${phoneController.text.trim()}',
          icon: Icons.sms_outlined,
        ),
        const SizedBox(height: 32),
        // OTP Large digit display
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.shadowSm,
          ),
          child: TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 18,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '------',
              hintStyle: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                letterSpacing: 18,
                color: AppTheme.textHint,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 22,
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),
        const SizedBox(height: 24),
        _primaryButton(label: 'Verify OTP', onPressed: onVerifyOtp, isLoading: isLoading),
        const SizedBox(height: 16),
        Center(
          child: Text(
            "Didn't receive the code? Wait 60 seconds to resend.",
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          title: 'Set Up Profile',
          subtitle: 'Almost there! Tell us a bit about yourself.',
          icon: Icons.person_add_outlined,
        ),
        const SizedBox(height: 28),

        // Name
        _inputField(
          controller: nameController,
          label: 'Full Name',
          hint: 'John Doe',
          icon: Icons.person_outline,
          keyboardType: TextInputType.name,
          capitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),

        // Password
        _passwordField(
          controller: passwordController,
          label: 'Password',
          hint: 'min. 6 characters',
          obscure: obscurePassword,
          onToggle: onToggleObscurePassword,
        ),
        const SizedBox(height: 14),

        // Confirm Password
        _passwordField(
          controller: confirmController,
          label: 'Confirm Password',
          hint: 'repeat your password',
          obscure: obscureConfirm,
          onToggle: onToggleObscureConfirm,
        ),
        const SizedBox(height: 14),

        // Referral Code (optional)
        _inputField(
          controller: referralController,
          label: 'Referral Code (optional)',
          hint: 'e.g. JOHN12345',
          icon: Icons.card_giftcard_outlined,
          keyboardType: TextInputType.text,
          capitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 26),

        _primaryButton(
          label: 'Create Account',
          onPressed: onComplete,
          isLoading: isLoading,
          trailingIcon: Icons.arrow_forward,
        ),
      ],
    );
  }

  Widget _phoneField() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.shadowSm,
      ),
      child: TextField(
        controller: phoneController,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        decoration: InputDecoration(
          labelText: 'Phone Number',
          hintText: '9876543210',
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_outlined, color: AppTheme.primaryGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          labelStyle: TextStyle(color: AppTheme.textMuted),
          hintStyle: TextStyle(color: AppTheme.textHint, fontWeight: FontWeight.w400),
        ),
      ),
    ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.05);
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.shadowSm,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primaryGreen, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          labelStyle: TextStyle(color: AppTheme.textMuted),
          hintStyle:
              TextStyle(color: AppTheme.textHint, fontWeight: FontWeight.w400),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.04);
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.shadowSm,
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon:
              const Icon(Icons.lock_outline, color: AppTheme.primaryGreen, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppTheme.textHint,
              size: 20,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          labelStyle: TextStyle(color: AppTheme.textMuted),
          hintStyle:
              TextStyle(color: AppTheme.textHint, fontWeight: FontWeight.w400),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.04);
  }

  Widget _stepHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.primaryGreen, size: 22),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.04);
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onPressed,
    required bool isLoading,
    IconData? trailingIcon,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        boxShadow: isLoading ? null : AppTheme.shadowGreen,
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailingIcon, size: 18),
                  ],
                ],
              ),
      ),
    ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05);
  }
}

// ═══════════════════════════════════════════
// Login Form
// ═══════════════════════════════════════════
class _LoginForm extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;

  const _LoginForm({
    super.key,
    required this.phoneController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.isLoading,
    required this.onSubmit,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: const [
            Icon(Icons.lock_open_rounded, color: AppTheme.primaryGreen, size: 22),
            SizedBox(width: 8),
            Text(
              'Welcome Back',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.04),
        const SizedBox(height: 6),
        const Text(
          'Log in with your phone number and password.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ).animate(delay: 50.ms).fadeIn(),

        const SizedBox(height: 28),

        // Phone
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.shadowSm,
          ),
          child: TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '9876543210',
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 16, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_outlined,
                        color: AppTheme.primaryGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '+91',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              labelStyle: TextStyle(color: AppTheme.textMuted),
              hintStyle: TextStyle(
                  color: AppTheme.textHint, fontWeight: FontWeight.w400),
            ),
          ),
        ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.05),

        const SizedBox(height: 14),

        // Password
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.shadowSm,
          ),
          child: TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'your password',
              prefixIcon: const Icon(Icons.lock_outline,
                  color: AppTheme.primaryGreen, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.textHint,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              labelStyle: TextStyle(color: AppTheme.textMuted),
              hintStyle: TextStyle(
                  color: AppTheme.textHint, fontWeight: FontWeight.w400),
            ),
          ),
        ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),

        const SizedBox(height: 24),

        // Login Button
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            boxShadow: isLoading ? null : AppTheme.shadowGreen,
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppTheme.primaryGreen.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text(
                    'Log In',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.05),

        const SizedBox(height: 18),

        Center(
          child: TextButton(
            onPressed: onForgotPassword,
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ).animate(delay: 300.ms).fadeIn(),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// Forgot Password Bottom Sheet
// ═══════════════════════════════════════════
class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet();

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  // step 0 = phone, step 1 = OTP + new password
  int _step = 0;
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _formatted {
    final p = _phoneController.text.trim();
    return p.startsWith('+') ? p : '+91$p';
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.trim().length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number.');
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    await context.read<AuthProvider>().sendResetOtp(
      phoneNumber: _formatted,
      onCodeSent: (_) => setState(() => _step = 1),
      onError: (e) => setState(() => _error = e),
    );
  }

  Future<void> _resetPassword() async {
    final otp = _otpController.text.trim();
    final pass = _newPasswordController.text;
    final confirm = _confirmController.text;

    if (otp.length < 6) {
      setState(() => _error = 'Enter the 6-digit OTP.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    final ok = await context.read<AuthProvider>().resetPasswordWithOtp(
      smsCode: otp,
      newPassword: pass,
      onError: (e) => setState(() => _error = e),
    );
    if (ok && mounted) setState(() => _success = true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + bottom),
          decoration: const BoxDecoration(
            color: AppTheme.backgroundLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: AnimatedSwitcher(
            duration: 300.ms,
            child: _success
                ? _buildSuccess()
                : (_step == 0
                    ? _buildPhoneStep(auth)
                    : _buildResetStep(auth)),
          ),
        );
      },
    );
  }

  Widget _buildSuccess() {
    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreenLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              color: AppTheme.primaryGreen, size: 32),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 18),
        const Text(
          'Password Reset!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your password has been updated.\nPlease log in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100)),
              elevation: 0,
            ),
            child: const Text('Go to Log In',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneStep(AuthProvider auth) {
    return Column(
      key: const ValueKey('phone'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle indicator
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your registered phone number to receive an OTP.',
          style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.5),
        ),
        const SizedBox(height: 22),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.errorRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: TextStyle(
                          color: AppTheme.errorRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ).animate().shake(duration: 400.ms),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.shadowSm,
          ),
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '9876543210',
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 16, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_outlined, color: AppTheme.primaryGreen, size: 20),
                    const SizedBox(width: 8),
                    Text('+91', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              labelStyle: TextStyle(color: AppTheme.textMuted),
              hintStyle: TextStyle(color: AppTheme.textHint, fontWeight: FontWeight.w400),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              elevation: 0,
            ),
            child: auth.isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildResetStep(AuthProvider auth) {
    return SingleChildScrollView(
      child: Column(
        key: const ValueKey('reset'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Set New Password',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the OTP sent to +91 ${_phoneController.text.trim()} and set your new password.',
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.5),
          ),
          const SizedBox(height: 22),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppTheme.errorRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!, style: TextStyle(color: AppTheme.errorRed, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ).animate().shake(duration: 400.ms),
          // OTP
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.shadowSm,
            ),
            child: TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 16,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '------',
                hintStyle: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 16,
                  color: AppTheme.textHint,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // New Password
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.shadowSm,
            ),
            child: TextField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1),
              decoration: InputDecoration(
                labelText: 'New Password',
                hintText: 'min. 6 characters',
                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryGreen, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.textHint, size: 20),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                labelStyle: TextStyle(color: AppTheme.textMuted),
                hintStyle: TextStyle(color: AppTheme.textHint, fontWeight: FontWeight.w400),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Confirm Password
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.shadowSm,
            ),
            child: TextField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'repeat password',
                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryGreen, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.textHint, size: 20),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                labelStyle: TextStyle(color: AppTheme.textMuted),
                hintStyle: TextStyle(color: AppTheme.textHint, fontWeight: FontWeight.w400),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: auth.isLoading ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                elevation: 0,
              ),
              child: auth.isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Reset Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
