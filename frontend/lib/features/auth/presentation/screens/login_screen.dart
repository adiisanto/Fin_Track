import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: BlocConsumer<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.errorMessage)),
                  );
                } else if (state is Authenticated) {
                  // Navigate to Dashboard
                  // Navigator.of(context).pushReplacementNamed('/dashboard');
                }
              },
              builder: (context, state) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Welcome Back',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscureText = !_obscureText),
                        ),
                      ),
                      obscureText: _obscureText,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: state is AuthLoading
                          ? null
                          : () {
                              context.read<AuthBloc>().add(
                                AuthLoginSubmitted(
                                  _emailController.text,
                                  _passwordController.text,
                                ),
                              );
                            },
                      child: state is AuthLoading
                          ? const CircularProgressIndicator()
                          : const Text('Login'),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to Register Screen
                      },
                      child: const Text('Don\'t have an account? Register'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
