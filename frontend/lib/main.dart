import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/network/dio_client.dart';
import 'core/storage/secure_storage.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  final secureStorage = SecureStorage();
  final dioClient = DioClient(
    baseUrl: 'http://localhost:8000', // Points to FastAPI backend
    secureStorage: secureStorage,
  );
  
  final authRepository = AuthRepository(
    dio: dioClient.dio,
    secureStorage: secureStorage,
  );

  runApp(MyApp(authRepository: authRepository));
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;

  const MyApp({Key? key, required this.authRepository}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc(authRepository: authRepository)
            ..add(AuthCheckRequested()),
        ),
      ],
      child: MaterialApp(
        title: 'Financial Tracker',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const AppNavigator(),
      ),
    );
  }
}

class AppNavigator extends StatelessWidget {
  const AppNavigator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (state is Authenticated) {
          // If authenticated, go to a temporary Dashboard
          return Scaffold(
            appBar: AppBar(title: const Text('Dashboard')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Welcome, ${state.user.fullName}!'),
                  ElevatedButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(AuthLogoutRequested());
                    },
                    child: const Text('Logout'),
                  )
                ],
              ),
            ),
          );
        } else {
          // Unauthenticated or Error, show Login Screen
          return const LoginScreen();
        }
      },
    );
  }
}
