import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JsonViewerWidget extends StatefulWidget {
  final String jsonString;

  const JsonViewerWidget({super.key, required this.jsonString});

  @override
  State<JsonViewerWidget> createState() => _JsonViewerWidgetState();
}

class _JsonViewerWidgetState extends State<JsonViewerWidget> {
  late dynamic _parsedJson;
  bool _parseError = false;

  @override
  void initState() {
    super.initState();
    try {
      _parsedJson = jsonDecode(widget.jsonString);
    } catch (e) {
      _parseError = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_parseError) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          widget.jsonString,
          style: GoogleFonts.robotoMono(fontSize: 13, color: Colors.red),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFF1E1E2E),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _buildJsonTree(_parsedJson, 0, true),
      ),
    );
  }

  Widget _buildJsonTree(dynamic value, int depth, bool isDark) {
    if (value == null) {
      return _coloredText('null', _nullColor(isDark));
    }
    if (value is bool) {
      return _coloredText(value.toString(), _boolColor(isDark));
    }
    if (value is num) {
      return _coloredText(value.toString(), _numberColor(isDark));
    }
    if (value is String) {
      return _coloredText('"$value"', _stringColor(isDark));
    }
    if (value is List) {
      return _buildArray(value, depth, isDark);
    }
    if (value is Map) {
      return _buildObject(value as Map<String, dynamic>, depth, isDark);
    }
    return _coloredText(value.toString(), _textColor(isDark));
  }

  Widget _buildObject(Map<String, dynamic> map, int depth, bool isDark) {
    if (map.isEmpty) return _coloredText('{}', _bracketColor(isDark));

    final indent = '  ' * (depth + 1);
    final closingIndent = '  ' * depth;
    final entries = map.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _coloredText('{', _bracketColor(isDark)),
        ...entries.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final isLast = i == entries.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _coloredText(indent, Colors.transparent),
              _coloredText('"${e.key}"', _keyColor(isDark)),
              _coloredText(': ', _textColor(isDark)),
              Flexible(child: _buildJsonTree(e.value, depth + 1, isDark)),
              if (!isLast) _coloredText(',', _textColor(isDark)),
            ],
          );
        }),
        _coloredText('$closingIndent}', _bracketColor(isDark)),
      ],
    );
  }

  Widget _buildArray(List list, int depth, bool isDark) {
    if (list.isEmpty) return _coloredText('[]', _bracketColor(isDark));

    final indent = '  ' * (depth + 1);
    final closingIndent = '  ' * depth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _coloredText('[', _bracketColor(isDark)),
        ...list.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isLast = i == list.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _coloredText(indent, Colors.transparent),
              Flexible(child: _buildJsonTree(item, depth + 1, isDark)),
              if (!isLast) _coloredText(',', _textColor(isDark)),
            ],
          );
        }),
        _coloredText('$closingIndent]', _bracketColor(isDark)),
      ],
    );
  }

  Widget _coloredText(String text, Color color) {
    return Text(
      text,
      style: GoogleFonts.robotoMono(
        fontSize: 13,
        height: 1.5,
        color: color,
      ),
    );
  }

  // Color scheme inspired by VS Code JSON highlighting
  Color _keyColor(bool isDark) => isDark ? const Color(0xFF9CDCFE) : const Color(0xFF0451A5);
  Color _stringColor(bool isDark) => isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515);
  Color _numberColor(bool isDark) => isDark ? const Color(0xFFB5CEA8) : const Color(0xFF098658);
  Color _boolColor(bool isDark) => isDark ? const Color(0xFF569CD6) : const Color(0xFF0000FF);
  Color _nullColor(bool isDark) => isDark ? const Color(0xFF569CD6) : const Color(0xFF0000FF);
  Color _bracketColor(bool isDark) => isDark ? const Color(0xFFD4D4D4) : const Color(0xFF333333);
  Color _textColor(bool isDark) => isDark ? const Color(0xFFD4D4D4) : const Color(0xFF333333);
}
