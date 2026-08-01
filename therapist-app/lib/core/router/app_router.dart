import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/presentation/screens/appointments_screen.dart';
import '../../features/appointments/presentation/screens/appointment_detail_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/availability/presentation/screens/availability_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/main_shell.dart';
import '../../features/exercise_assignment/presentation/screens/assign_exercises_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/patients/presentation/screens/my_patients_screen.dart';
import '../../features/patients/presentation/screens/patient_profile_screen.dart';
import '../../features/prescription/presentation/screens/write_prescription_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/reviews/presentation/screens/reviews_screen.dart';
import '../../features/settings/presentation/screens/bank_details_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/video_call/presentation/screens/video_call_screen.dart';
import '../../features/wallet/presentation/screens/earnings_screen.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';

  static const String dashboard = '/dashboard';
  static const String appointments = '/appointments';
  static const String patients = '/patients';
  static const String earnings = '/earnings';
  static const String profile = '/profile';

  static const String availability = '/availability';
  static const String reviews = '/reviews';
  static const String bankDetails = '/bank-details';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String chat = '/chat';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthChangeNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: listenable,

    redirect: (context, state) {
      final AuthState auth = ref.read(authProvider);
      final String location = state.matchedLocation;

      // Stay on the splash screen until the stored session is resolved
      if (auth.status == AuthStatus.unknown) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final bool onAuthRoute =
          location == AppRoutes.login || location == AppRoutes.splash;

      if (!auth.isAuthenticated) {
        return location == AppRoutes.login ? null : AppRoutes.login;
      }

      // A signed-in therapist has no reason to sit on login or splash
      if (onAuthRoute) return AppRoutes.dashboard;

      return null;
    },

    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),

      // Bottom-navigation shell; each branch keeps its own stack
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.appointments,
                builder: (context, state) => const AppointmentsScreen(),
                routes: [
                  GoRoute(
                    path: 'detail/:id',
                    builder: (context, state) => AppointmentDetailScreen(
                      appointmentId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'prescription',
                        builder: (context, state) => WritePrescriptionScreen(
                          appointmentId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.patients,
                builder: (context, state) => const MyPatientsScreen(),
                routes: [
                  GoRoute(
                    path: ':patientId',
                    builder: (context, state) => PatientProfileScreen(
                      patientId: state.pathParameters['patientId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'assign-exercises',
                        builder: (context, state) => AssignExercisesScreen(
                          patientId: state.pathParameters['patientId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.earnings,
                builder: (context, state) => const EarningsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'availability',
                    builder: (context, state) => const AvailabilityScreen(),
                  ),
                  GoRoute(
                    path: 'reviews',
                    builder: (context, state) => const ReviewsScreen(),
                  ),
                  GoRoute(
                    path: 'bank-details',
                    builder: (context, state) => const BankDetailsScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Full-screen routes that must cover the bottom navigation bar
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/call/:appointmentId',
        builder: (context, state) => VideoCallScreen(
          appointmentId: state.pathParameters['appointmentId']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.chat,
        builder: (context, state) => const ChatListScreen(),
        routes: [
          GoRoute(
            path: 'thread/:threadId',
            builder: (context, state) => ChatScreen(
              threadId: state.pathParameters['threadId']!,
              title: state.uri.queryParameters['name'] ?? 'Chat',
            ),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.dashboard),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// Bridges the Riverpod auth state into a Listenable for GoRouter, notifying
/// only when the coarse status changes so navigation state is preserved.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    _subscription = ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
