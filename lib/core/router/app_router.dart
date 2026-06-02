import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/role_choice_screen.dart';
import '../../features/auth/screens/phone_login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/liveness_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/education/screens/education_home_screen.dart';
import '../../features/education/screens/session_active_screen.dart';
import '../../features/education/screens/teacher_requests_screen.dart';
import '../../features/education/screens/student_notebook_screen.dart';
import '../../features/education/screens/rate_session_screen.dart';
import '../../features/education/screens/weekly_schedule_screen.dart';
import '../../features/education/screens/monthly_billing_screen.dart';
import '../../features/education/screens/teacher_portfolio_screen.dart';
import '../../features/education/screens/group_sessions_screen.dart';
import '../../features/artisans/screens/artisans_home_screen.dart';
import '../../features/artisans/screens/artisan_request_screen.dart';
import '../../features/artisans/screens/artisan_search_screen.dart';
import '../../features/artisans/screens/rate_client_screen.dart';
import '../../features/artisans/screens/artisan_portfolio_screen.dart';
import '../../features/artisans/screens/artisan_quote_detail_screen.dart';
import '../../features/artisans/screens/artisan_quotes_screen.dart';
import '../../features/artisans/screens/rate_artisan_screen.dart';
import '../../features/messages/screens/conversations_screen.dart';
import '../../features/messages/screens/chat_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/immobilier/screens/immobilier_screen.dart';
import '../../features/moto/screens/moto_screen.dart';
import '../../features/marketplace/screens/marketplace_screen.dart';
import '../../features/menagere/screens/menagere_screen.dart';
import '../providers/auth_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.value?.accessToken != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isRoot = state.matchedLocation == '/';

      if (isRoot) return isLoggedIn ? '/home' : '/auth/welcome';
      if (!isLoggedIn && !isAuthRoute) return '/auth/welcome';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(path: '/auth/welcome', builder: (c, s) => const WelcomeScreen()),
      GoRoute(path: '/auth/role-choice', builder: (c, s) => const RoleChoiceScreen()),
      GoRoute(
        path: '/auth/login',
        builder: (c, s) => PhoneLoginScreen(
          initialTab: s.uri.queryParameters['tab'] == 'register' ? 1 : 0,
          preselectedRole: s.uri.queryParameters['role'],
        ),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (c, s) => OtpScreen(
          phone: s.uri.queryParameters['phone'] ?? (s.extra as String? ?? ''),
          purpose: s.uri.queryParameters['purpose'] ?? 'registration',
          role: s.uri.queryParameters['role'],
        ),
      ),
      GoRoute(path: '/auth/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/auth/liveness', builder: (c, s) => const LivenessScreen()),
      GoRoute(path: '/auth/forgot-password', builder: (c, s) => const ForgotPasswordScreen()),

      // Main shell avec bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
          GoRoute(path: '/wallet', builder: (c, s) => const WalletScreen()),
          GoRoute(path: '/messages', builder: (c, s) => const ConversationsScreen()),
          GoRoute(
            path: '/messages/chat/:userId',
            builder: (c, s) {
              final extra = s.extra as Map<String, dynamic>?;
              return ChatScreen(
                contactId: s.pathParameters['userId']!,
                applicationId: extra?['applicationId'] as String?,
                applicationData: extra?['applicationData'] as Map<String, dynamic>?,
                quoteData: extra?['quoteData'] as Map<String, dynamic>?,
              );
            },
          ),
          GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
        ],
      ),

      // Modules services
      GoRoute(path: '/education', builder: (c, s) => const EducationHomeScreen()),
      GoRoute(path: '/education/session/:id', builder: (c, s) => SessionActiveScreen(sessionId: s.pathParameters['id']!)),
      GoRoute(path: '/education/requests', builder: (c, s) => const TeacherRequestsScreen()),
      GoRoute(path: '/education/schedule', builder: (c, s) => const WeeklyScheduleScreen()),
      GoRoute(path: '/education/schedule-parent', builder: (c, s) => const WeeklyScheduleScreen(readOnly: true)),
      GoRoute(path: '/education/billing', builder: (c, s) => const MonthlyBillingScreen()),
      GoRoute(path: '/education/groups', builder: (c, s) => const GroupSessionsScreen()),
      GoRoute(
        path: '/education/portfolio/:teacherId',
        builder: (c, s) => TeacherPortfolioScreen(teacherId: s.pathParameters['teacherId']!),
      ),
      GoRoute(
        path: '/education/rate/:sessionId',
        builder: (c, s) => RateSessionScreen(
          sessionId: s.pathParameters['sessionId']!,
          sessionData: s.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/education/notebook/:contractId',
        builder: (c, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return StudentNotebookScreen(
            contractId: s.pathParameters['contractId']!,
            studentName: extra?['studentName'] as String? ?? 'Élève',
          );
        },
      ),
      GoRoute(path: '/artisans', builder: (c, s) => const ArtisansHomeScreen()),
      GoRoute(path: '/artisans/search', builder: (c, s) => const ArtisanSearchScreen()),
      GoRoute(path: '/artisans/request', builder: (c, s) => const ArtisanRequestScreen()),
      GoRoute(
        path: '/artisans/quotes/:requestId',
        builder: (c, s) => ArtisanQuotesScreen(
          requestId: s.pathParameters['requestId']!,
          requestTitle: s.uri.queryParameters['title'] ?? 'Ma demande',
        ),
      ),
      GoRoute(
        path: '/artisans/portfolio/:providerId',
        builder: (c, s) => ArtisanPortfolioScreen(providerId: s.pathParameters['providerId']!),
      ),
      GoRoute(
        path: '/artisans/quote/:requestId/:quoteId',
        builder: (c, s) => ArtisanQuoteDetailScreen(
          requestId: s.pathParameters['requestId']!,
          quoteId: s.pathParameters['quoteId']!,
        ),
      ),
      GoRoute(
        path: '/artisans/rate/:requestId',
        builder: (c, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return RateArtisanScreen(
            requestId: s.pathParameters['requestId']!,
            artisanName: extra?['artisanName'] as String? ?? 'Artisan',
          );
        },
      ),
      GoRoute(
        path: '/artisans/rate-client/:requestId',
        builder: (c, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return RateClientScreen(
            requestId: s.pathParameters['requestId']!,
            clientName: extra?['clientName'] as String? ?? 'Client',
          );
        },
      ),
      GoRoute(path: '/immobilier', builder: (c, s) => const ImmobilierScreen()),
      GoRoute(path: '/moto', builder: (c, s) => const MotoScreen()),
      GoRoute(path: '/marketplace', builder: (c, s) => const MarketplaceScreen()),
      GoRoute(path: '/menagere', builder: (c, s) => const MenagereScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page introuvable: ${state.uri}')),
    ),
  );
});

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _tabs = ['/home', '/wallet', '/messages', '/profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          context.go(_tabs[i]);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
