import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/logger.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../providers/auth_provider.dart';
import '../notifiers/login_notifier.dart';
import '../state/login_state.dart';

// --- LoginPage Implementation ---

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key}); // Use super.key

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LoginState>(loginNotifierProvider, (previousState, nextState) {
      if (previousState?.status != LoginStatus.success && nextState.status == LoginStatus.success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
        );
      } else if (previousState?.status != LoginStatus.failure && nextState.status == LoginStatus.failure) {
        if (nextState.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(nextState.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });

    final loginState = ref.watch(loginNotifierProvider);
    final loginNotifier = ref.read(loginNotifierProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLogo(),
                const SizedBox(height: 40),

                Text(
                  'Sign in to your account',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),

                _buildTextField(
                  label: 'Username',
                  controller: _usernameController,
                  enabled: loginState.status != LoginStatus.loading,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  label: 'Password',
                  controller: _passwordController,
                  isPassword: true,
                  enabled: loginState.status != LoginStatus.loading,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 20),

                _buildRememberForgotRow(context),
                const SizedBox(height: 28),

                _buildSignInButton(loginState, loginNotifier),
                const SizedBox(height: 32),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 8),
        Text(
          'Xiangle ERP',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[800]),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isPassword = false,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0), // Slightly rounded corners
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Adjust padding
          ),
        ),
      ],
    );
  }

  Widget _buildRememberForgotRow(BuildContext context) {
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox( // Constrain checkbox size and padding
              width: 24,
              height: 24,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _rememberMe = value;
                    });
                  }
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap target size
                visualDensity: VisualDensity.compact, // Make it more compact
              ),
            ),
            const SizedBox(width: 8),
            Text('Remember me', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        TextButton(
          onPressed: () {
            logger.d('Forgot password tapped'); // Placeholder action
          },
          child: Text(
              'Forgot password?',
              style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton(LoginState loginState, LoginNotifier loginNotifier) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      onPressed: loginState.status == LoginStatus.loading
          ? null
          : () {
        final username = _usernameController.text;
        final password = _passwordController.text;
        if (username.isNotEmpty && password.isNotEmpty) {
          // 读取 _rememberMe 状态并传递给 loginNotifier
          loginNotifier.login(username, password, _rememberMe); // <--- 传入 _rememberMe
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter username and password')),
          );
        }
      },
      child: loginState.status == LoginStatus.loading
          ? const SizedBox(
          height: 24.0,
          width: 24.0,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
          : const Text('Sign in'),
    );
  }
}