import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/discovery/discovery_screen.dart';
import 'features/matches/matches_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/pets/pets_screen.dart';
import 'features/pets/pet_edit_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/splash/splash_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Config.supabaseUrl,
    anonKey: Config.supabaseAnonKey,
  );
  runApp(const PawdApp());
}

class PawdApp extends StatefulWidget {
  const PawdApp({super.key});
  @override
  State<PawdApp> createState() => _PawdAppState();
}

class _PawdAppState extends State<PawdApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/',
      refreshListenable:
          GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
      redirect: (context, state) {
        final loggedIn = Supabase.instance.client.auth.currentSession != null;
        final atLogin = state.matchedLocation == '/login';
        if (!loggedIn) return atLogin ? null : '/login';
        if (loggedIn && atLogin) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SplashGate()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/pets/new', builder: (_, __) => const PetEditScreen()),
        GoRoute(
          path: '/pets/:id/edit',
          builder: (_, s) => PetEditScreen(petId: s.pathParameters['id']),
        ),
        GoRoute(
          path: '/chat/:matchId',
          builder: (_, s) => ChatScreen(matchId: s.pathParameters['matchId']!),
        ),
        ShellRoute(
          builder: (_, __, child) => HomeShell(child: child),
          routes: [
            GoRoute(path: '/discover', builder: (_, __) => const DiscoveryScreen()),
            GoRoute(path: '/matches', builder: (_, __) => const MatchesScreen()),
            GoRoute(path: '/pets', builder: (_, __) => const PetsScreen()),
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PAWD',
      debugShowCheckedModeBanner: false,
      theme: buildPawdTheme(),
      routerConfig: _router,
      // Responsive across all phone/tablet sizes: clamp runaway system font
      // scaling, and keep content in a comfortable centred column on wide
      // screens (tablets, foldables) instead of stretching edge to edge.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Bridges a Stream to a Listenable so GoRouter re-evaluates on auth changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
