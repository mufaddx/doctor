import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/main_shell.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/therapist_profile/presentation/screens/therapist_profile_screen.dart';
import '../../features/booking/presentation/screens/select_slot_screen.dart';
import '../../features/booking/presentation/screens/appointment_type_screen.dart';
import '../../features/booking/presentation/screens/booking_summary_screen.dart';
import '../../features/payment/presentation/screens/payment_screen.dart';
import '../../features/payment/presentation/screens/booking_success_screen.dart';
import '../../features/appointments/presentation/screens/appointments_screen.dart';
import '../../features/appointments/presentation/screens/appointment_detail_screen.dart';
import '../../features/prescription/presentation/screens/prescription_screen.dart';
import '../../features/exercises/presentation/screens/exercises_screen.dart';
import '../../features/exercises/presentation/screens/exercise_detail_screen.dart';
import '../../features/progress/presentation/screens/progress_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/video_call/presentation/screens/video_call_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/referral/presentation/screens/referral_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/addresses_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/help_support_screen.dart';
import '../storage/preferences_storage.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String otp = '/otp';

  static const String home = '/home';
  static const String search = '/search';
  static const String appointments = '/appointments';
  static const String chatList = '/chat';
  static const String exercises = '/exercises';
  static const String profile = '/profile';

  static const String therapistProfile = 'therapist';
  static const String selectSlot = 'slot';
  static const String appointmentType = 'type';
  static const String bookingSummary = 'summary';
  static const String payment = 'payment';
  static const String bookingSuccess = 'success';
  static const String appointmentDetail = 'detail';
  static const String prescription = 'prescription';
  static const String videoCall = 'call';
  static const String chatThread = 'thread';
  static const String exerciseDetail = 'exercise';
  static const String progress = 'progress';
  static const String wallet = 'wallet';
  static const String notifications = 'notifications';
  static const String referral = 'referral';
  static const String editProfile = 'edit';
  static const String addresses = 'addresses';
  static const String settings = 'settings';
  static const String helpSupport = 'help';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Rebuilding the router on every auth change would drop navigation state, so
  // the notifier is bridged into a Listenable that only pokes refreshListenable.
  final authListenable = _AuthChangeNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: authListenable,
    debugLogDiagnostics: false,

    redirect: (context, state) {
      final AuthState auth = ref.read(authProvider);
      final String location = state.matchedLocation;

      // Hold on the splash screen until the stored session is resolved
      if (auth.status == AuthStatus.unknown) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final bool onboarded =
          ref.read(preferencesStorageProvider).hasCompletedOnboarding();

      final bool isAuthRoute = location == AppRoutes.login ||
          location == AppRoutes.otp ||
          location == AppRoutes.splash ||
          location == AppRoutes.onboarding;

      if (!auth.isAuthenticated) {
        if (!onboarded && location != AppRoutes.onboarding) {
          return AppRoutes.onboarding;
        }
        return isAuthRoute && location != AppRoutes.splash
            ? null
            : AppRoutes.login;
      }

      // An authenticated user has no reason to sit on the auth screens
      if (isAuthRoute) return AppRoutes.home;

      return null;
    },

    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) => const OtpScreen(),
      ),

      // Bottom-navigation shell: these five branches keep their own stacks
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
                routes: _homeSubRoutes,
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
                    path: '${AppRoutes.appointmentDetail}/:id',
                    builder: (context, state) => AppointmentDetailScreen(
                      appointmentId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: '${AppRoutes.prescription}/:id',
                    builder: (context, state) => PrescriptionScreen(
                      prescriptionId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.chatList,
                builder: (context, state) => const ChatListScreen(),
                routes: [
                  GoRoute(
                    path: '${AppRoutes.chatThread}/:threadId',
                    builder: (context, state) => ChatScreen(
                      threadId: state.pathParameters['threadId']!,
                      title: state.uri.queryParameters['name'] ?? 'Chat',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.exercises,
                builder: (context, state) => const ExercisesScreen(),
                routes: [
                  GoRoute(
                    path: '${AppRoutes.exerciseDetail}/:id',
                    builder: (context, state) => ExerciseDetailScreen(
                      exerciseId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.progress,
                    builder: (context, state) => const ProgressScreen(),
                  ),
                ],
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
                    path: AppRoutes.editProfile,
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: AppRoutes.addresses,
                    builder: (context, state) => const AddressesScreen(),
                  ),
                  GoRoute(
                    path: AppRoutes.wallet,
                    builder: (context, state) => const WalletScreen(),
                  ),
                  GoRoute(
                    path: AppRoutes.referral,
                    builder: (context, state) => const ReferralScreen(),
                  ),
                  GoRoute(
                    path: AppRoutes.settings,
                    builder: (context, state) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: AppRoutes.helpSupport,
                    builder: (context, state) => const HelpSupportScreen(),
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
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});

/// Booking flow nested under home so the back stack unwinds naturally.
final List<RouteBase> _homeSubRoutes = [
  GoRoute(
    path: AppRoutes.search,
    builder: (context, state) => SearchScreen(
      initialQuery: state.uri.queryParameters['q'],
    ),
  ),
  GoRoute(
    path: '${AppRoutes.therapistProfile}/:id',
    builder: (context, state) => TherapistProfileScreen(
      therapistId: state.pathParameters['id']!,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.selectSlot,
        builder: (context, state) => SelectSlotScreen(
          therapistId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.appointmentType,
        builder: (context, state) => AppointmentTypeScreen(
          therapistId: state.pathParameters['id']!,
          date: state.uri.queryParameters['date']!,
          startTime: state.uri.queryParameters['time']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.bookingSummary,
        builder: (context, state) => BookingSummaryScreen(
          therapistId: state.pathParameters['id']!,
          date: state.uri.queryParameters['date']!,
          startTime: state.uri.queryParameters['time']!,
          type: state.uri.queryParameters['type']!,
        ),
      ),
    ],
  ),
  GoRoute(
    path: '${AppRoutes.payment}/:appointmentId',
    builder: (context, state) => PaymentScreen(
      appointmentId: state.pathParameters['appointmentId']!,
    ),
  ),
  GoRoute(
    path: '${AppRoutes.bookingSuccess}/:appointmentId',
    builder: (context, state) => BookingSuccessScreen(
      appointmentId: state.pathParameters['appointmentId']!,
    ),
  ),
];

/// Adapts the Riverpod auth state into a [Listenable] for GoRouter.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    _subscription = ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        // Only a change in the coarse status affects routing
        if (previous?.status != next.status) notifyListeners();
      },
    );
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
