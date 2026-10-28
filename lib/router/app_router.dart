import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/products/screens/products_screen.dart';
import '../features/products/screens/product_detail_screen.dart';
import '../features/cart/screens/cart_screen.dart';
import '../features/checkout/screens/checkout_screen.dart';
import '../features/orders/screens/orders_screen.dart';
import '../features/orders/screens/order_detail_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/delete_account_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/search/search_screen.dart';
import '../features/gift/gift_host.dart';
import '../features/gift/gift_claim_screen.dart';
import '../features/gift/my_gifts_screen.dart';

// A global navigator key so _BackGuard can always find the GoRouter context
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Bridges Riverpod auth-state changes into a Listenable for GoRouter.
//
// Why this exists: routerProvider used to do `ref.watch(authProvider)`
// directly, which meant every auth change (login, logout, register, and now
// profile/avatar edits) rebuilt the ENTIRE GoRouter object. A freshly built
// GoRouter re-applies `initialLocation: '/splash'`, which is why the splash
// screen (and its ~2.5s animation) was reappearing after every login and
// every profile edit. Using `refreshListenable` instead lets GoRouter just
// re-run its `redirect` callback in place, without rebuilding the router or
// resetting to the initial location.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      // Don't redirect away from splash — it handles its own navigation
      if (state.matchedLocation == '/splash') return null;

      final authState = ref.read(authProvider);
      if (!authState.initialized) return null;

      final protectedRoutes = ['/cart', '/checkout', '/orders', '/profile', '/gift-claim'];
      final isProtected =
          protectedRoutes.any((r) => state.matchedLocation.startsWith(r));

      if (isProtected && !authState.isLoggedIn) {
        return '/login?redirect=${state.matchedLocation}';
      }
      return null;
    },
    routes: [
      // ── Splash ───────────────────────────────────────────────────────
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),

      // ── Shell: Home + Profile (bottom nav) ───────────────────────────
      ShellRoute(
        builder: (context, state, child) => _Shell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // ── Auth ─────────────────────────────────────────────────────────
      GoRoute(path: '/login',           builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register',         builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password',  builder: (_, __) => const ForgotPasswordScreen()),

      // ── Products ─────────────────────────────────────────────────────
      GoRoute(
        path: '/products',
        builder: (context, state) => ProductsScreen(
          category: state.uri.queryParameters['category'],
          brand:    state.uri.queryParameters['brand'],
          sort:     state.uri.queryParameters['sort'],
          featured: state.uri.queryParameters['featured'] == '1',
        ),
      ),
      GoRoute(
        path: '/products/:slug',
        builder: (context, state) =>
            ProductDetailScreen(slug: state.pathParameters['slug']!),
      ),

      // ── Cart ─────────────────────────────────────────────────────────
      GoRoute(path: '/cart',     builder: (_, __) => const CartScreen()),

      // ── Checkout ─────────────────────────────────────────────────────
      GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),

      // ── Orders ───────────────────────────────────────────────────────
      GoRoute(path: '/orders',   builder: (_, __) => const OrdersScreen()),
      GoRoute(
        path: '/orders/:number',
        builder: (context, state) => OrderDetailScreen(
            orderNumber: state.pathParameters['number']!),
      ),

      // ── Profile sub-screens ──────────────────────────────────────────
      GoRoute(path: '/profile/edit',            builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/profile/gifts',           builder: (_, __) => const MyGiftsScreen()),
      GoRoute(path: '/gift-claim',              builder: (_, __) => const GiftClaimScreen()),
      GoRoute(path: '/profile/delete-account',  builder: (_, __) => const DeleteAccountScreen()),

      // ── Search ───────────────────────────────────────────────────────
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
    ],
  );
});

// ── Bottom-nav Shell ─────────────────────────────────────────────────────────
// This is the ONLY place where the exit dialog appears — when the user is on
// the home tab and presses back. Every other screen uses context.go('/') to
// navigate back, never allowing the app to exit silently.
class _Shell extends ConsumerWidget {
  final Widget child;
  const _Shell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location == '/') currentIndex = 0;
    else if (location.startsWith('/profile')) currentIndex = 1;

    final isHome = location == '/';

    return PopScope(
      canPop: false,
      onPopInvoked: (_) async {
        if (!isHome) {
          // On any shell tab that isn't home (e.g. profile) → go to home
          context.go('/');
          return;
        }
        // On home tab → show exit confirmation
        if (!context.mounted) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            title: const Row(children: [
              Text('👋', style: TextStyle(fontSize: 24)),
              SizedBox(width: 10),
              Text('Exit App?',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 20)),
            ]),
            content: const Text(
              'Are you sure you want to exit Harahori Telecom?',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Stay',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Exit',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        );
        if (shouldExit == true && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: GiftHost(child: child),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (i) {
            switch (i) {
              case 0: context.go('/'); break;
              case 1: context.go('/profile'); break;
            }
          },
          backgroundColor: Colors.white,
          elevation: 8,
          indicatorColor: const Color(0xFFEDE9FE),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon:
                  Icon(Icons.home_rounded, color: Color(0xFF7C3AED)),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon:
                  Icon(Icons.person_rounded, color: Color(0xFF7C3AED)),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
