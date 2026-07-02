import 'package:go_router/go_router.dart';
import '../bloc/auth/auth_bloc.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/group/create_group_screen.dart';
import '../screens/group/group_details_screen.dart';

class AppRouter {
  static GoRouter router(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final authState = authBloc.state;
        final isAuth = authState is AuthAuthenticated;
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/forgot-password' ||
            state.matchedLocation.startsWith('/reset-password') ||
            state.matchedLocation.startsWith('/verify');

        if (!isAuth && !isAuthRoute) return '/login';
        if (isAuth && isAuthRoute) return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/reset-password/:email',
          builder: (context, state) {
            final email = state.pathParameters['email'] ?? '';
            return ResetPasswordScreen(email: email);
          },
        ),
        GoRoute(
          path: '/verify/:email',
          builder: (context, state) {
            final email = state.pathParameters['email'] ?? '';
            return VerifyEmailScreen(email: email);
          },
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'chat/:conversationId',
              builder: (context, state) {
                final convId = state.pathParameters['conversationId'] ?? '';
                final name = state.uri.queryParameters['name'] ?? 'Chat';
                final type = state.uri.queryParameters['type'] ?? 'direct';
                return ChatScreen(
                  conversationId: convId,
                  name: name,
                  type: type,
                );
              },
            ),
            GoRoute(
              path: 'create-group',
              builder: (context, state) => const CreateGroupScreen(),
            ),
            GoRoute(
              path: 'group/:groupId',
              builder: (context, state) {
                final groupId = state.pathParameters['groupId'] ?? '';
                return GroupDetailsScreen(groupId: groupId);
              },
            ),
          ],
        ),
      ],
    );
  }
}
