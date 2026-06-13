import 'package:flutter/material.dart';

import 'auth_screens.dart';
import 'legal_support_screens.dart';
import 'main_shell.dart';
import 'settings_screens.dart';
import 'smart_widget_screens.dart';
import 'state.dart';
import 'theme.dart';

void runTodoUpApp() {
  runApp(const TodoUpApp());
}

void runTodoUpBootstrapErrorApp(String message) {
  runApp(TodoUpBootstrapErrorApp(message: message));
}

class TodoUpApp extends StatefulWidget {
  const TodoUpApp({super.key});

  @override
  State<TodoUpApp> createState() => _TodoUpAppState();
}

class _TodoUpAppState extends State<TodoUpApp> {
  final TodoAppController _controller = TodoAppController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TodoAppScope(
      controller: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return MaterialApp(
            key: ValueKey(
              'app-${_controller.isInitialized}-${_controller.isAuthenticated}',
            ),
            debugShowCheckedModeBanner: false,
            title: 'ToDoUp',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _controller.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const _AppBootstrapGate(),
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case LoginScreen.routeName:
                  return MaterialPageRoute<void>(
                    builder: (_) => _controller.isAuthenticated
                        ? const AppShell()
                        : const LoginScreen(),
                  );
                case SignUpScreen.routeName:
                  return MaterialPageRoute<void>(
                    builder: (_) => _controller.isAuthenticated
                        ? const AppShell()
                        : const SignUpScreen(),
                  );
                case AppShell.routeName:
                  final initialIndex = settings.arguments is int
                      ? settings.arguments as int
                      : 0;
                  return MaterialPageRoute<void>(
                    builder: (_) => _controller.isAuthenticated
                        ? AppShell(initialIndex: initialIndex)
                        : const LoginScreen(),
                  );
                case ProfileEditScreen.routeName:
                  return MaterialPageRoute<void>(
                    builder: (_) => _controller.isAuthenticated
                        ? const ProfileEditScreen()
                        : const LoginScreen(),
                  );
                case SettingsScreen.routeName:
                  return MaterialPageRoute<void>(
                    builder: (_) => _controller.isAuthenticated
                        ? const SettingsScreen()
                        : const LoginScreen(),
                  );
                case SupportScreen.routeName:
                  return MaterialPageRoute<void>(
                    builder: (_) => _controller.isAuthenticated
                        ? const SupportScreen()
                        : const LoginScreen(),
                  );
                case SmartWidgetScreen.routeName:
                  return MaterialPageRoute<void>(
                    builder: (_) => _controller.isAuthenticated
                        ? const SmartWidgetScreen()
                        : const LoginScreen(),
                  );
                case PrivacyPolicyScreen.routeName:
                  return MaterialPageRoute<void>(
                    builder: (_) => _controller.isAuthenticated
                        ? const PrivacyPolicyScreen()
                        : const LoginScreen(),
                  );
                case TermsOfServiceScreen.routeName:
                  return MaterialPageRoute<void>(
                    builder: (_) => _controller.isAuthenticated
                        ? const TermsOfServiceScreen()
                        : const LoginScreen(),
                  );
                default:
                  return MaterialPageRoute<void>(
                    builder: (_) => const _AppBootstrapGate(),
                  );
              }
            },
          );
        },
      ),
    );
  }
}

class _AppBootstrapGate extends StatelessWidget {
  const _AppBootstrapGate();

  @override
  Widget build(BuildContext context) {
    final controller = TodoAppScope.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: !controller.isInitialized
          ? const SplashScreen(key: ValueKey('splash'))
          : controller.isAuthenticated
          ? const AppShell(key: ValueKey('app-shell'))
          : const LoginScreen(key: ValueKey('login')),
    );
  }
}

class TodoUpBootstrapErrorApp extends StatelessWidget {
  const TodoUpBootstrapErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ToDoUp Setup',
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supabase setup required',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This build needs SUPABASE_URL and SUPABASE_ANON_KEY before it can start.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SelectableText(
                      'flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key',
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
