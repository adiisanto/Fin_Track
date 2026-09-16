import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/network/dio_client.dart';
import 'core/storage/secure_storage.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/finance/data/finance_repository.dart';
import 'features/finance/presentation/bloc/dashboard_bloc.dart';
import 'features/finance/presentation/screens/dashboard_screen.dart';

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

  final financeRepository = FinanceRepository(
    dio: dioClient.dio,
  );

  runApp(MyApp(authRepository: authRepository, financeRepository: financeRepository));
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;
  final FinanceRepository financeRepository;

  const MyApp({Key? key, required this.authRepository, required this.financeRepository}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: financeRepository),
      ],
      child: MultiBlocProvider(
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
          return BlocProvider(
            create: (context) => DashboardBloc(
              financeRepository: context.read<FinanceRepository>(),
            ),
            child: const DashboardScreen(),
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
