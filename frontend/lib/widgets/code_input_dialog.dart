import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/constants.dart';

class CodeInputDialog extends StatefulWidget {
  final Function(String code, String language) onSubmit;

  const CodeInputDialog({super.key, required this.onSubmit});

  @override
  State<CodeInputDialog> createState() => _CodeInputDialogState();
}

class _CodeInputDialogState extends State<CodeInputDialog> {
  final _codeController = TextEditingController();
  String _selectedLanguage = 'dart';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.code_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Share Code Snippet', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),

            // Language selector
            DropdownButtonFormField<String>(
              initialValue: _selectedLanguage,
              decoration: const InputDecoration(
                labelText: 'Language',
                prefixIcon: Icon(Icons.language),
              ),
              items: AppConstants.supportedCodeLanguages
                  .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedLanguage = val ?? 'dart'),
            ),
            const SizedBox(height: 12),

            // Code input
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: TextField(
                  controller: _codeController,
                  maxLines: null,
                  minLines: 8,
                  style: GoogleFonts.robotoMono(fontSize: 13, color: const Color(0xFFE2E8F0)),
                  cursorColor: const Color(0xFF4DA8DA),
                  decoration: InputDecoration(
                    hintText: '// Paste or type your code here...',
                    hintStyle: GoogleFonts.robotoMono(fontSize: 13, color: const Color(0xFF64748B)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    final code = _codeController.text.trim();
                    if (code.isNotEmpty) {
                      widget.onSubmit(code, _selectedLanguage);
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send Code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
