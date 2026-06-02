import 'package:flutter/material.dart';
import 'package:flutter_app/models/user.dart';
import 'package:flutter_app/services/authentication.dart';
import 'package:flutter_app/services/push_messaging.dart';
import 'package:flutter_app/view_models/all_messages_vm.dart';
import 'package:flutter_app/view_models/me_vm.dart';
import 'package:flutter_app/views/auth_page.dart';
import 'package:flutter_app/views/chat_page.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

final routerConfig = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/auth',
      pageBuilder: (context, state) =>
          const NoTransitionPage<void>(child: AuthPage()),
    ),
    ShellRoute(
      builder: (context, state, child) {
        final myId = Provider.of<AuthenticationService>(context, listen: false)
            .checkAndGetLoggedInUserId();
        if (myId == null) {
          debugPrint('Warning: ShellRoute should not be built without a user');
          return const SizedBox.shrink();
        }
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<MeViewModel>(
              create: (_) => MeViewModel(myId),
            ),
            ChangeNotifierProvider<AllMessagesViewModel>(
              create: (_) => AllMessagesViewModel(),
            ),
          ],
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/chat',
          pageBuilder: (context, state) {
            final meViewModel = Provider.of<MeViewModel>(context, listen: true);

            // Log out and ask user to log in again for the custom claim to take effect
            if (meViewModel.isModeratorStatusChanged) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Provider.of<PushMessagingService>(context, listen: false)
                    .unsubscribeFromAllTopics();
                Provider.of<AuthenticationService>(context, listen: false)
                    .logOut();
              });
            }

            return NoTransitionPage<void>(
                child: StreamBuilder<User>(
              // Listen to the me state changes
              stream: meViewModel.meStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.active ||
                    snapshot.data == null) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  debugPrint('Error loading user data: ${snapshot.error}');
                  return const Center(
                    child: Text('Error loading user data'),
                  );
                }

                return ChatPage();
              },
            ));
          },
        ),
      ],
    ),
  ],
  initialLocation: '/chat',
  debugLogDiagnostics: true,
  redirect: (context, state) {
    final currentPath = state.uri.path;
    final isLoggedIn =
        Provider.of<AuthenticationService>(context, listen: false)
                .checkAndGetLoggedInUserId() !=
            null;
    if (isLoggedIn && currentPath == '/auth') {
      return '/chat';
    }
    if (!isLoggedIn && currentPath != '/auth') {
      // Redirect to auth page if the user is not logged in
      return '/auth';
    }
    if (currentPath == '/') {
      return '/chat';
    }
    // No redirection needed for other routes
    return null;
  },
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri.path}'),
    ),
  ),
);

class NavigationService {
  late final GoRouter _router;

  NavigationService() {
    _router = routerConfig;
  }

  void goToChatPage() {
    _router.go('/chat');
  }

  void goToAuthPage() {
    _router.go('/auth');
  }

  void pop(BuildContext context) {
    _router.pop(context);
  }
}
