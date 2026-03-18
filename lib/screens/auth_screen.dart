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
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  // 0: Phone input, 1: Login (Password), 2: Signup (Name + Password)
  int _currentStep = 0; 
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String get _formattedPhone {
    final phone = _phoneController.text.trim();
    if (phone.startsWith('+')) return phone;
    if (phone.startsWith('91')) return '+$phone';
    return '+91$phone';
  }

  Future<void> _checkPhone() async {
    if (_phoneController.text.trim().length < 10) {
      setState(() => _errorMessage = 'Please enter a valid phone number');
      return;
    }

    setState(() => _errorMessage = null);

    final provider = context.read<AuthProvider>();
    final exists = await provider.checkPhoneExists(_formattedPhone);

    if (mounted) {
      setState(() {
        _currentStep = exists ? 1 : 2;
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitAuth() async {
    if (_passwordController.text.trim().length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    if (_currentStep == 2 && _nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }

    setState(() => _errorMessage = null);
    final provider = context.read<AuthProvider>();
    bool success = false;

    if (_currentStep == 1) {
      // Login
      success = await provider.loginWithPhoneAndPassword(
        phoneNumber: _formattedPhone,
        password: _passwordController.text.trim(),
        onError: (msg) => setState(() => _errorMessage = msg),
      );
    } else if (_currentStep == 2) {
      // Signup
      success = await provider.signUpWithPhoneAndPassword(
        phoneNumber: _formattedPhone,
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        onError: (msg) => setState(() => _errorMessage = msg),
      );
    }

    if (success && mounted && provider.isLoggedIn) {
      Navigator.of(context).pop();
    }
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
            if (_currentStep > 0) {
              setState(() {
                _currentStep = 0;
                _passwordController.clear();
                _nameController.clear();
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
              _currentStep > 0 ? Icons.arrow_back : Icons.close,
              size: 20,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // ─── Branding ───
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                      boxShadow: AppTheme.shadowGreen,
                    ),
                    child: const Center(
                      child: Text('🍕', style: TextStyle(fontSize: 40)),
                    ),
                  ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                ),

                const SizedBox(height: 32),

                // ─── Title ───
                Center(
                  child: Text(
                    _currentStep == 0
                        ? 'Welcome to Snaccit'
                        : (_currentStep == 1 ? 'Welcome Back' : 'Create Account'),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05),

                const SizedBox(height: 8),

                Center(
                  child: Text(
                    _currentStep == 0
                        ? 'Enter your phone number to continue'
                        : (_currentStep == 1
                            ? 'Enter password for $_formattedPhone'
                            : 'Set up your profile for $_formattedPhone'),
                    style: const TextStyle(fontSize: 15, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ).animate(delay: 100.ms).fadeIn(),

                const SizedBox(height: 36),

                // ─── Error ───
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: AppTheme.errorRed, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ).animate().shake(duration: 400.ms),

                // ─── Step 0: Phone Input ───
                if (_currentStep == 0) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: AppTheme.shadowSm,
                    ),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 1),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '9876543210',
                        prefixText: '+91  ',
                        prefixStyle: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        prefixIcon: Container(
                          margin: const EdgeInsets.only(left: 14, right: 6),
                          child: const Icon(Icons.phone_outlined, color: AppTheme.primaryGreen),
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
                  ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),

                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: authProvider.isLoading ? null : AppTheme.shadowGreen,
                    ),
                    child: ElevatedButton(
                      onPressed: authProvider.isLoading ? null : _checkPhone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        ),
                        elevation: 0,
                      ),
                      child: authProvider.isLoading
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.05),
                ],

                // ─── Step 1 & 2: Password and Name Input ───
                if (_currentStep > 0) ...[
                  if (_currentStep == 2) ...[
                    // Name Field
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: AppTheme.shadowSm,
                      ),
                      child: TextField(
                        controller: _nameController,
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'John Doe',
                          prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryGreen),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          labelStyle: TextStyle(color: AppTheme.textMuted),
                          hintStyle: TextStyle(color: AppTheme.textHint, fontWeight: FontWeight.w400),
                        ),
                      ),
                    ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05),
                    const SizedBox(height: 16),
                  ],

                  // Password Field
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: AppTheme.shadowSm,
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'min. 6 characters',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryGreen),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: AppTheme.textHint,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        labelStyle: TextStyle(color: AppTheme.textMuted),
                        hintStyle: TextStyle(color: AppTheme.textHint, fontWeight: FontWeight.w400),
                      ),
                    ),
                  ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),

                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: authProvider.isLoading ? null : AppTheme.shadowGreen,
                    ),
                    child: ElevatedButton(
                      onPressed: authProvider.isLoading ? null : _submitAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        ),
                        elevation: 0,
                      ),
                      child: authProvider.isLoading
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentStep == 1 ? 'Login' : 'Create Account',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
                    ),
                  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.05),

                  const SizedBox(height: 20),

                  if (_currentStep == 1) // Only show forgot password on login
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // Optional: Implement Forgot Password logic
                          setState(() => _errorMessage = 'Please contact support to reset your password.');
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],

                const SizedBox(height: 50),

                // ─── Terms ───
                Center(
                  child: Text(
                    'By continuing, you agree to our\nTerms of Service and Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textHint,
                      height: 1.5,
                    ),
                  ).animate(delay: 500.ms).fadeIn(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

