import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ===== Professional Color Palette =====

  // Primary: Deep Indigo Blue
  static const Color primaryLight = Color(0xFF1E3A5F);
  static const Color primaryDark = Color(0xFF4DA8DA);

  // Secondary: Warm Teal
  static const Color secondaryLight = Color(0xFF0D7377);
  static const Color secondaryDark = Color(0xFF14FFEC);

  // Accent: Coral/Orange for CTAs
  static const Color accentLight = Color(0xFFE85D3A);
  static const Color accentDark = Color(0xFFFF8A65);

  // Success/Online
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);

  // Light theme surfaces
  static const Color _lightBg = Color(0xFFF7F8FC);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color _lightDivider = Color(0xFFE8ECF2);
  static const Color _lightTextPrimary = Color(0xFF1A1D26);
  static const Color _lightTextSecondary = Color(0xFF6B7280);
  static const Color _lightChatBubbleSelf = Color(0xFF1E3A5F);
  static const Color _lightChatBubbleOther = Color(0xFFF0F2F5);

  // Dark theme surfaces
  static const Color _darkBg = Color(0xFF0D1117);
  static const Color _darkSurface = Color(0xFF161B22);
  static const Color _darkCard = Color(0xFF1C2333);
  static const Color _darkDivider = Color(0xFF30363D);
  static const Color _darkTextPrimary = Color(0xFFF0F6FC);
  static const Color _darkTextSecondary = Color(0xFF8B949E);
  static const Color _darkChatBubbleSelf = Color(0xFF1E3A5F);
  static const Color _darkChatBubbleOther = Color(0xFF1C2333);

  // Custom colors accessible from theme extensions
  static const Color codeBlockBgLight = Color(0xFFF6F8FA);
  static const Color codeBlockBgDark = Color(0xFF0D1117);

  // ===== Light Theme =====
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryLight,
        secondary: secondaryLight,
        tertiary: accentLight,
        surface: _lightSurface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _lightTextPrimary,
        outline: _lightDivider,
      ),
      scaffoldBackgroundColor: _lightBg,
      cardColor: _lightCard,
      dividerColor: _lightDivider,
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: _lightSurface,
        foregroundColor: _lightTextPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: _lightCard,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: _lightTextSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: primaryLight.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      extensions: [
        ChatThemeExtension(
          chatBubbleSelf: _lightChatBubbleSelf,
          chatBubbleOther: _lightChatBubbleOther,
          chatTextSelf: Colors.white,
          chatTextOther: _lightTextPrimary,
          codeBlockBg: codeBlockBgLight,
          onlineDot: success,
          textSecondary: _lightTextSecondary,
        ),
      ],
    );
  }

  // ===== Dark Theme =====
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryDark,
        secondary: secondaryDark,
        tertiary: accentDark,
        surface: _darkSurface,
        error: error,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: _darkTextPrimary,
        outline: _darkDivider,
      ),
      scaffoldBackgroundColor: _darkBg,
      cardColor: _darkCard,
      dividerColor: _darkDivider,
      textTheme: _buildTextTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: _darkSurface,
        foregroundColor: _darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _darkTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: _darkCard,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: _darkTextSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.black,
          elevation: 4,
          shadowColor: primaryDark.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryDark,
        foregroundColor: Colors.black,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 12,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _darkSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      extensions: [
        ChatThemeExtension(
          chatBubbleSelf: _darkChatBubbleSelf,
          chatBubbleOther: _darkChatBubbleOther,
          chatTextSelf: Colors.white,
          chatTextOther: _darkTextPrimary,
          codeBlockBg: codeBlockBgDark,
          onlineDot: success,
          textSecondary: _darkTextSecondary,
        ),
      ],
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final color = brightness == Brightness.light
        ? _lightTextPrimary
        : _darkTextPrimary;
    final secondaryColor = brightness == Brightness.light
        ? _lightTextSecondary
        : _darkTextSecondary;

    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -1.0,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Custom theme extension for chat-specific colors.
class ChatThemeExtension extends ThemeExtension<ChatThemeExtension> {
  final Color chatBubbleSelf;
  final Color chatBubbleOther;
  final Color chatTextSelf;
  final Color chatTextOther;
  final Color codeBlockBg;
  final Color onlineDot;
  final Color textSecondary;

  const ChatThemeExtension({
    required this.chatBubbleSelf,
    required this.chatBubbleOther,
    required this.chatTextSelf,
    required this.chatTextOther,
    required this.codeBlockBg,
    required this.onlineDot,
    required this.textSecondary,
  });

  @override
  ChatThemeExtension copyWith({
    Color? chatBubbleSelf,
    Color? chatBubbleOther,
    Color? chatTextSelf,
    Color? chatTextOther,
    Color? codeBlockBg,
    Color? onlineDot,
    Color? textSecondary,
  }) {
    return ChatThemeExtension(
      chatBubbleSelf: chatBubbleSelf ?? this.chatBubbleSelf,
      chatBubbleOther: chatBubbleOther ?? this.chatBubbleOther,
      chatTextSelf: chatTextSelf ?? this.chatTextSelf,
      chatTextOther: chatTextOther ?? this.chatTextOther,
      codeBlockBg: codeBlockBg ?? this.codeBlockBg,
      onlineDot: onlineDot ?? this.onlineDot,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  ChatThemeExtension lerp(ThemeExtension<ChatThemeExtension>? other, double t) {
    if (other is! ChatThemeExtension) return this;
    return ChatThemeExtension(
      chatBubbleSelf: Color.lerp(chatBubbleSelf, other.chatBubbleSelf, t)!,
      chatBubbleOther: Color.lerp(chatBubbleOther, other.chatBubbleOther, t)!,
      chatTextSelf: Color.lerp(chatTextSelf, other.chatTextSelf, t)!,
      chatTextOther: Color.lerp(chatTextOther, other.chatTextOther, t)!,
      codeBlockBg: Color.lerp(codeBlockBg, other.codeBlockBg, t)!,
      onlineDot: Color.lerp(onlineDot, other.onlineDot, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}
