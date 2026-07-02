import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ===== Cubit =====
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.dark);

  void toggleTheme() {
    emit(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  void setLight() => emit(ThemeMode.light);
  void setDark() => emit(ThemeMode.dark);

  bool get isDark => state == ThemeMode.dark;
}
