import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'bloc/auth/auth_bloc.dart';
import 'bloc/chat/chat_bloc.dart';
import 'bloc/theme/theme_cubit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CoderTalkApp());
}

class CoderTalkApp extends StatelessWidget {
  const CoderTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc()..add(AuthCheckRequested())),
        BlocProvider(create: (_) => ChatBloc()),
        BlocProvider(create: (_) => ThemeCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          final authBloc = context.read<AuthBloc>();
          return MaterialApp.router(
            title: 'CoderTalk',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            routerConfig: AppRouter.router(authBloc),
          );
        },
      ),
    );
  }
}
