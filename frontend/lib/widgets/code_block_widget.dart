import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:google_fonts/google_fonts.dart';

class CodeBlockWidget extends StatelessWidget {
  final String code;
  final String language;

  const CodeBlockWidget({
    super.key,
    required this.code,
    this.language = '',
  });

  @override
  Widget build(BuildContext context) {
    // Always use sleek dark theme for code blocks for premium contrast
    final highlightTheme = Map<String, TextStyle>.from(atomOneDarkTheme);
    highlightTheme['root'] = const TextStyle(
      backgroundColor: Colors.transparent,
      color: Color(0xFFABB2BF),
    );
    final cleanCode = code.trim();

    // Map common language aliases
    final lang = _normalizeLanguage(language);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFF1E1E2E), // Sleek obsidian/mocha dark code background
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: HighlightView(
          cleanCode,
          language: lang.isNotEmpty ? lang : 'plaintext',
          theme: highlightTheme,
          textStyle: GoogleFonts.robotoMono(
            fontSize: 13.5,
            height: 1.45,
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  String _normalizeLanguage(String lang) {
    final lower = lang.toLowerCase().trim();
    const aliases = {
      'js': 'javascript',
      'ts': 'typescript',
      'py': 'python',
      'rb': 'ruby',
      'cs': 'csharp',
      'c++': 'cpp',
      'c#': 'csharp',
      'sh': 'bash',
      'yml': 'yaml',
      'kt': 'kotlin',
      'md': 'markdown',
      'tf': 'terraform',
    };
    return aliases[lower] ?? lower;
  }
}
