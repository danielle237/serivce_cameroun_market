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
import '../../features/marketplace/screens/marketplace_home_screen.dart';
import '../../features/marketplace/screens/cart_screen.dart';
import '../../features/marketplace/screens/checkout_screen.dart';
import '../../features/marketplace/screens/my_orders_screen.dart';
import '../../features/marketplace/screens/order_detail_screen.dart';
import '../../features/marketplace/screens/boss_dashboard_screen.dart';
import '../../features/marketplace/screens/vendor_dashboard_screen.dart';
import '../../features/marketplace/screens/reseller_dashboard_screen.dart';
import '../../features/marketplace/screens/tiktok_screen.dart';
import '../../features/marketplace/screens/product_detail_screen.dart';
import '../../features/marketplace/screens/vendor_products_screen.dart';
import '../../features/marketplace/screens/vendor_product_form_screen.dart';
import '../../features/marketplace/models/shop_product.dart';
import '../../features/marketplace/screens/invoice_screen.dart';
import '../../features/marketplace/screens/loyalty_screen.dart';
import '../../features/marketplace/screens/loyalty_config_screen.dart';
import '../../features/marketplace/screens/notification_prefs_screen.dart';
import '../../features/menagere/screens/menagere_screen.dart';
import '../providers/auth_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Auth encore en cours de chargement → rester sur le splash '/'
      if (authState.isLoading) {
        return state.matchedLocation == '/' ? null : '/';
      }

      final isLoggedIn = authState.value?.accessToken != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isRoot = state.matchedLocation == '/';

      if (isRoot) return isLoggedIn ? '/home' : '/auth/welcome';
      if (!isLoggedIn && !isAuthRoute) return '/auth/welcome';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      // Splash — affiché pendant le chargement du token (évite le flash login)
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(
          backgroundColor: Color(0xFF1A237E),
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ),
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
          GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
        ],
      ),

      // Chat — hors ShellRoute pour être accessible depuis tous les modules
      GoRoute(
        path: '/messages/chat/:userId',
        builder: (c, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return ChatScreen(
            contactId: s.pathParameters['userId']!,
            applicationId: extra?['applicationId'] as String?,
            applicationData: extra?['applicationData'] as Map<String, dynamic>?,
            quoteData: extra?['quoteData'] as Map<String, dynamic>?,
            marketplaceData: extra?['marketplaceData'] as Map<String, dynamic>?,
          );
        },
      ),

      // ── Marketplace — hors shell pour avoir le bouton retour propre ──────────
      GoRoute(
        path: '/marketplace',
        builder: (c, s) => MarketplaceHomeScreen(
          source: s.uri.queryParameters['source'],
          highlightProductId: s.uri.queryParameters['product'],
        ),
        routes: [
          GoRoute(
            path: 'products/:productId',
            builder: (c, s) => ProductDetailScreen(productId: s.pathParameters['productId']!),
          ),
          GoRoute(path: 'cart',     builder: (c, s) => const CartScreen()),
          GoRoute(path: 'checkout', builder: (c, s) => const CheckoutScreen()),
          GoRoute(path: 'orders',   builder: (c, s) => const MyOrdersScreen()),
          GoRoute(
            path: 'orders/:orderId',
            builder: (c, s) => OrderDetailScreen(orderId: s.pathParameters['orderId']!),
            routes: [
              GoRoute(
                path: 'invoice',
                builder: (c, s) => InvoiceScreen(orderId: s.pathParameters['orderId']!),
              ),
            ],
          ),
          GoRoute(path: 'boss',     builder: (c, s) => const BossDashboardScreen()),
          GoRoute(path: 'tiktok',   builder: (c, s) => const TikTokScreen()),
          GoRoute(path: 'reseller', builder: (c, s) => const ResellerDashboardScreen()),
          GoRoute(path: 'loyalty',  builder: (c, s) => const LoyaltyScreen()),
          GoRoute(path: 'loyalty/config', builder: (c, s) => const LoyaltyConfigScreen()),
          GoRoute(path: 'notifications/prefs', builder: (c, s) => const NotificationPrefsScreen()),
          GoRoute(
            path: 'vendor',
            builder: (c, s) => const VendorDashboardScreen(),
            routes: [
              GoRoute(path: 'products', builder: (c, s) => const VendorProductsScreen()),
              GoRoute(path: 'products/new', builder: (c, s) => const VendorProductFormScreen()),
              GoRoute(
                path: 'products/edit/:productId',
                builder: (c, s) => VendorProductFormScreen(product: s.extra as ShopProduct?),
              ),
            ],
          ),
        ],
      ),

      // ── Modules services ──────────────────────────────────────────────────────
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
