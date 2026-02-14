import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/route_detail_screen.dart';
import 'screens/routes_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/stop_detail_screen.dart';
import 'screens/dropoff_screen.dart';
import 'screens/verify_bags_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const ProviderScope(child: LundrayDriverApp()));
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = auth.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoginRoute) {
        return '/login';
      }
      if (isAuthenticated && isLoginRoute) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/routes',
                builder: (context, state) => const RoutesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/route/:routeId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final routeId = state.pathParameters['routeId']!;
          return RouteDetailScreen(routeId: routeId);
        },
      ),
      GoRoute(
        path: '/route/:routeId/stop/:stopId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final routeId = state.pathParameters['routeId']!;
          final stopId = state.pathParameters['stopId']!;
          return StopDetailScreen(routeId: routeId, stopId: stopId);
        },
      ),
      GoRoute(
        path: '/route/:routeId/stop/:stopId/scan',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final routeId = state.pathParameters['routeId']!;
          final stopId = state.pathParameters['stopId']!;
          return QrScannerScreen(routeId: routeId, stopId: stopId);
        },
      ),
      GoRoute(
        path: '/route/:routeId/stop/:stopId/verify',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final routeId = state.pathParameters['routeId']!;
          final stopId = state.pathParameters['stopId']!;
          return VerifyBagsScreen(routeId: routeId, stopId: stopId);
        },
      ),
      GoRoute(
        path: '/route/:routeId/dropoff',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final routeId = state.pathParameters['routeId']!;
          return DropoffScreen(routeId: routeId);
        },
      ),
    ],
  );
});

class LundrayDriverApp extends ConsumerWidget {
  const LundrayDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Lundray Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          primary: const Color(0xFF10B981),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF10B981),
              width: 2,
            ),
          ),
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
