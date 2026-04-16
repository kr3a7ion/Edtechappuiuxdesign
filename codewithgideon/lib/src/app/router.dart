import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/state/app_providers.dart';
import '../core/widgets/app_scaffold.dart';
import '../features/assessments/assessment_screens.dart';
import '../features/classes/class_screens.dart';
import '../features/community/community_screens.dart';
import '../features/community/models/mentor_request_model.dart';
import '../features/entry/entry_screens.dart';
import '../features/home/dashboard_screen.dart';
import '../features/live/live_session_screen.dart';
import '../features/payment/models/payment_checkout_model.dart';
import '../features/payment/payment_screen.dart';
import '../features/profile/profile_screens.dart';
import '../features/recorded/recorded_screens.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
GlobalKey<NavigatorState> get appRootNavigatorKey => _rootNavigatorKey;
final _dashboardNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'dashboard',
);
final _classesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'classes');
final _communityNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'community',
);
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final onboardingState = ref.watch(hasSeenOnboardingProvider);
  final hasSeenOnboarding = onboardingState.maybeWhen(
    data: (value) => value,
    orElse: () => false,
  );

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isBooting =
          authState.status == AuthStatus.booting || onboardingState.isLoading;
      final isProtected = const [
        '/dashboard',
        '/classes',
        '/community',
        '/profile',
        '/live',
        '/recorded',
        '/resources',
        '/ai-tutor',
        '/payment',
        '/quiz',
        '/assignment',
        '/certificates',
        '/settings',
      ].any(location.startsWith);
      final isPaymentRoute = location.startsWith('/payment');
      final isPendingShellRoute = const [
        '/dashboard',
        '/classes',
        '/community',
        '/profile',
        '/settings',
        '/profile/edit',
      ].any(location.startsWith);
      final isAuthFlow = const [
        '/welcome',
        '/login',
        '/signup',
        '/forgot-password',
        '/continue-registration',
      ].contains(location);
      final isVerificationRoute = location == '/verify-email';

      if (isBooting) {
        return location == '/' ? null : '/';
      }

      if (location == '/') {
        if (!hasSeenOnboarding) return '/onboarding';
        if (!authState.isAuthenticated) return '/welcome';
        return _signedInHome(authState);
      }

      if (!hasSeenOnboarding && location != '/onboarding') {
        return '/onboarding';
      }

      if (hasSeenOnboarding && location == '/onboarding') {
        if (!authState.isAuthenticated) return '/welcome';
        return _signedInHome(authState);
      }

      if (!authState.isAuthenticated) {
        if (isProtected ||
            location == '/enrollment' ||
            location == '/continue-registration' ||
            isVerificationRoute) {
          return '/welcome';
        }
        return null;
      }

      if (authState.requiresEmailVerification) {
        return isVerificationRoute ? null : '/verify-email';
      }

      if (isVerificationRoute) {
        return _signedInHome(authState);
      }

      if (authState.enrollmentStatus == EnrollmentStatus.notRegistered &&
          location != '/continue-registration' &&
          !isPaymentRoute) {
        return '/continue-registration';
      }

      if (isAuthFlow && location != '/continue-registration') {
        if (authState.enrollmentStatus == EnrollmentStatus.notRegistered) {
          return '/continue-registration';
        }
        if (authState.enrollmentStatus == EnrollmentStatus.enrolled ||
            authState.enrollmentStatus == EnrollmentStatus.pending) {
          return '/dashboard';
        }
        return '/enrollment';
      }

      if (authState.enrollmentStatus != EnrollmentStatus.enrolled &&
          isProtected &&
          !isPaymentRoute &&
          !(authState.enrollmentStatus == EnrollmentStatus.pending &&
              isPendingShellRoute)) {
        return '/enrollment';
      }

      if (location == '/enrollment' &&
          (authState.enrollmentStatus == EnrollmentStatus.enrolled ||
              authState.enrollmentStatus == EnrollmentStatus.pending)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/continue-registration',
        builder: (context, state) => const ContinueRegistrationScreen(),
      ),
      GoRoute(
        path: '/enrollment',
        builder: (context, state) => const EnrollmentGateScreen(),
      ),
      GoRoute(
        path: '/payment',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'];
          final rawReturnTo = state.uri.queryParameters['returnTo'];
          final returnTo = rawReturnTo != null && rawReturnTo.startsWith('/')
              ? rawReturnTo
              : null;
          return PaymentScreen(
            kind: mode == 'topup'
                ? PaymentFlowKind.topUp
                : PaymentFlowKind.initial,
            returnTo: returnTo,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _dashboardNavigatorKey,
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _classesNavigatorKey,
            routes: [
              GoRoute(
                path: '/classes',
                builder: (context, state) => const ClassListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _communityNavigatorKey,
            routes: [
              GoRoute(
                path: '/community',
                builder: (context, state) => const CommunityChannelsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
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
        path: '/classes/:id',
        builder: (context, state) =>
            ClassDetailsScreen(classId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/live/:id',
        builder: (context, state) =>
            LiveSessionScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/recorded/:id',
        builder: (context, state) =>
            RecordedPlayerScreen(lessonId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/resources',
        builder: (context, state) => const ResourcesLibraryScreen(),
      ),
      GoRoute(
        path: '/ai-tutor/:lessonId',
        builder: (context, state) {
          final source = state.uri.queryParameters['source'];
          return AskMentorScreen(
            sessionId: state.pathParameters['lessonId']!,
            contextType: source == 'live'
                ? MentorRequestContext.live
                : MentorRequestContext.recorded,
          );
        },
      ),
      GoRoute(
        path: '/quiz/:id/intro',
        builder: (context, state) =>
            QuizIntroScreen(quizId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/quiz/:id/question/:questionId',
        builder: (context, state) => QuizQuestionScreen(
          quizId: state.pathParameters['id']!,
          questionId: state.pathParameters['questionId']!,
        ),
      ),
      GoRoute(
        path: '/quiz/:id/results',
        builder: (context, state) =>
            QuizResultsScreen(quizId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/assignment/:id',
        builder: (context, state) => AssignmentSubmissionScreen(
          assignmentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/community/chat/:channelId',
        builder: (context, state) =>
            ClassChatScreen(channelId: state.pathParameters['channelId']!),
      ),
      GoRoute(
        path: '/community/messages',
        builder: (context, state) => const DirectMessagesScreen(),
      ),
      GoRoute(
        path: '/certificates',
        builder: (context, state) => const CertificatesScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

String _signedInHome(AuthState authState) {
  if (authState.requiresEmailVerification) {
    return '/verify-email';
  }
  if (authState.enrollmentStatus == EnrollmentStatus.notRegistered) {
    return '/continue-registration';
  }
  if (authState.enrollmentStatus == EnrollmentStatus.enrolled ||
      authState.enrollmentStatus == EnrollmentStatus.pending) {
    return '/dashboard';
  }
  return '/enrollment';
}
