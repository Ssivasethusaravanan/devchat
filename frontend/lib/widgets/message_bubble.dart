import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:dio/dio.dart';
import '../config/theme.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import 'code_block_widget.dart';
import 'json_viewer_widget.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final bool showSender;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showSender = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatExt = theme.extension<ChatThemeExtension>()!;

    return Padding(
      padding: EdgeInsets.only(
        left: isMine ? 60 : 0,
        right: isMine ? 0 : 60,
        bottom: 6,
      ),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sender name (for group chats)
          if (showSender && message.sender != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                message.sender!.username,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Message bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width > 900
                  ? 650
                  : MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              color: (message.contentType == 'code' || message.contentType == 'json')
                  ? const Color(0xFF1E1E2E)
                  : (isMine ? chatExt.chatBubbleSelf : chatExt.chatBubbleOther),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
              child: IntrinsicWidth(
                child: _buildContent(context, theme, chatExt),
              ),
            ),
          ),

          // Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(
              _formatTime(message.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, ChatThemeExtension chatExt) {
    switch (message.contentType) {
      case 'code':
        return _buildCodeContent(context, theme, chatExt);
      case 'json':
        return _buildJsonContent(context, theme, chatExt);
      case 'image':
        return _buildImageContent(context, theme, chatExt);
      case 'file':
        return _buildFileContent(context, theme, chatExt);
      default:
        return _buildTextContent(context, theme, chatExt);
    }
  }

  Widget _buildTextContent(BuildContext context, ThemeData theme, ChatThemeExtension chatExt) {
    // Check if the text content might be JSON
    final content = message.content.trim();
    if ((content.startsWith('{') || content.startsWith('[')) && content.length > 2) {
      try {
        jsonDecode(content);
        return _buildJsonContent(context, theme, chatExt);
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: SelectableText(
        message.content,
        style: TextStyle(
          color: isMine ? chatExt.chatTextSelf : chatExt.chatTextOther,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildCodeContent(BuildContext context, ThemeData theme, ChatThemeExtension chatExt) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Language header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: chatExt.codeBlockBg.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Icon(Icons.code, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                message.language.isNotEmpty ? message.language.toUpperCase() : 'CODE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied!'), duration: Duration(seconds: 1)),
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 14, color: chatExt.textSecondary),
                    const SizedBox(width: 4),
                    Text('Copy', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Code block
        CodeBlockWidget(
          code: message.content,
          language: message.language,
        ),
      ],
    );
  }

  Widget _buildJsonContent(BuildContext context, ThemeData theme, ChatThemeExtension chatExt) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // JSON header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: chatExt.codeBlockBg.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Icon(Icons.data_object, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Text(
                'JSON',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  try {
                    final formatted = const JsonEncoder.withIndent('  ').convert(jsonDecode(message.content));
                    Clipboard.setData(ClipboardData(text: formatted));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('JSON copied (formatted)!'), duration: Duration(seconds: 1)),
                    );
                  } catch (_) {
                    Clipboard.setData(ClipboardData(text: message.content));
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 14, color: chatExt.textSecondary),
                    const SizedBox(width: 4),
                    Text('Copy', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        // JSON viewer
        JsonViewerWidget(jsonString: message.content),
      ],
    );
  }
  // ===== Image Preview (WhatsApp-style) =====
  Widget _buildImageContent(BuildContext context, ThemeData theme, ChatThemeExtension chatExt) {
    final attachment = message.attachments.isNotEmpty ? message.attachments.first : null;
    final r2Key = attachment?.r2Key ?? '';
    final fileName = (attachment?.fileName != null && attachment!.fileName.isNotEmpty)
        ? attachment.fileName
        : (message.content.isNotEmpty ? message.content : 'Image');

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview — load from R2
          if (r2Key.isNotEmpty)
            _ImagePreviewWidget(r2Key: r2Key, fileName: fileName)
          else
            // Fallback: no R2 key, show placeholder card
            Container(
              width: 220,
              height: 160,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_rounded, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                    const SizedBox(height: 8),
                    Text(
                      fileName,
                      style: TextStyle(
                        color: isMine ? chatExt.chatTextSelf : chatExt.chatTextOther,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

          // File name below image
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_rounded, size: 14,
                    color: isMine ? chatExt.chatTextSelf.withValues(alpha: 0.7) : chatExt.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    fileName,
                    style: TextStyle(
                      color: isMine ? chatExt.chatTextSelf.withValues(alpha: 0.8) : chatExt.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (r2Key.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _downloadFile(context, r2Key, fileName),
                    child: Icon(Icons.download_rounded, size: 16,
                        color: isMine ? chatExt.chatTextSelf : theme.colorScheme.primary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== File Card (WhatsApp-style) =====
  Widget _buildFileContent(BuildContext context, ThemeData theme, ChatThemeExtension chatExt) {
    final attachment = message.attachments.isNotEmpty ? message.attachments.first : null;
    final fileName = (attachment?.fileName != null && attachment!.fileName.isNotEmpty)
        ? attachment.fileName
        : (message.content.isNotEmpty ? message.content : 'Shared File');
    final r2Key = attachment?.r2Key ?? '';

    final ext = fileName.contains('.') ? fileName.split('.').last.toUpperCase() : 'FILE';
    final lowerExt = ext.toLowerCase();

    List<Color> iconColors;
    IconData fileIcon;
    if (['pdf'].contains(lowerExt)) {
      iconColors = [const Color(0xFFE53935), const Color(0xFFE35D5B)];
      fileIcon = Icons.picture_as_pdf_rounded;
    } else if (['zip', 'rar', '7z', 'tar'].contains(lowerExt)) {
      iconColors = [const Color(0xFFF39C12), const Color(0xFFF1C40F)];
      fileIcon = Icons.folder_zip_rounded;
    } else if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'].contains(lowerExt)) {
      iconColors = [const Color(0xFF8E44AD), const Color(0xFF9B59B6)];
      fileIcon = Icons.image_rounded;
    } else if (['doc', 'docx', 'txt', 'md'].contains(lowerExt)) {
      iconColors = [const Color(0xFF2980B9), const Color(0xFF3498DB)];
      fileIcon = Icons.description_rounded;
    } else if (['xls', 'xlsx', 'csv'].contains(lowerExt)) {
      iconColors = [const Color(0xFF27AE60), const Color(0xFF2ECC71)];
      fileIcon = Icons.table_chart_rounded;
    } else if (['dart', 'py', 'js', 'ts', 'go', 'html', 'css'].contains(lowerExt)) {
      iconColors = [const Color(0xFF16A085), const Color(0xFF1ABC9C)];
      fileIcon = Icons.code_rounded;
    } else {
      iconColors = [theme.colorScheme.primary, theme.colorScheme.secondary];
      fileIcon = Icons.insert_drive_file_rounded;
    }

    final sizeText = attachment != null && attachment.fileSize > 0
        ? attachment.fileSizeFormatted
        : '$ext File';

    return InkWell(
      onTap: () => _handleFileTap(context, r2Key, fileName),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // File type icon with gradient
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: iconColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: iconColors.first.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(fileIcon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            // File name & metadata
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      color: isMine ? chatExt.chatTextSelf : chatExt.chatTextOther,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isMine
                              ? chatExt.chatTextSelf.withValues(alpha: 0.15)
                              : iconColors.first.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ext,
                          style: TextStyle(
                            color: isMine ? chatExt.chatTextSelf : iconColors.first,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sizeText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isMine ? chatExt.chatTextSelf.withValues(alpha: 0.75) : chatExt.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Open / Download button
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isMine ? Colors.white.withValues(alpha: 0.15) : theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                lowerExt == 'pdf' ? Icons.visibility_rounded : (r2Key.isNotEmpty ? Icons.download_rounded : Icons.insert_drive_file_rounded),
                color: isMine ? chatExt.chatTextSelf : theme.colorScheme.primary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleFileTap(BuildContext context, String r2Key, String fileName) {
    if (fileName.toLowerCase().endsWith('.pdf')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _InAppPdfViewerScreen(r2Key: r2Key, fileName: fileName),
        ),
      );
    } else {
      _downloadFile(context, r2Key, fileName);
    }
  }

  // ===== Download helper =====
  Future<void> _downloadFile(BuildContext context, String r2Key, String fileName) async {
    if (r2Key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('File not uploaded to cloud storage.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Preparing $fileName...')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final response = await ApiService().getPresignedDownloadUrl(r2Key);
      if (response['success'] == true && response['data'] != null) {
        final downloadUrl = response['data']['download_url'] as String;
        final uri = Uri.parse(downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Could not open the file.'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      } else {
        throw Exception(response['error'] ?? 'Download failed');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ===== Stateful image preview widget with R2 download URL loading =====
class _ImagePreviewWidget extends StatefulWidget {
  final String r2Key;
  final String fileName;

  const _ImagePreviewWidget({required this.r2Key, required this.fileName});

  @override
  State<_ImagePreviewWidget> createState() => _ImagePreviewWidgetState();
}

class _ImagePreviewWidgetState extends State<_ImagePreviewWidget> {
  String? _imageUrl;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImageUrl();
  }

  Future<void> _loadImageUrl() async {
    try {
      final response = await ApiService().getPresignedDownloadUrl(widget.r2Key);
      if (response['success'] == true && response['data'] != null) {
        if (mounted) {
          setState(() {
            _imageUrl = response['data']['download_url'] as String;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() { _loading = false; _error = true; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Shimmer.fromColors(
        baseColor: theme.brightness == Brightness.dark ? const Color(0xFF1C2333) : const Color(0xFFE8ECF2),
        highlightColor: theme.brightness == Brightness.dark ? const Color(0xFF2C3548) : const Color(0xFFF7F8FC),
        child: Container(
          width: 220,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    if (_error || _imageUrl == null) {
      return Container(
        width: 220,
        height: 120,
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_rounded, size: 36, color: theme.colorScheme.error.withValues(alpha: 0.5)),
              const SizedBox(height: 6),
              Text('Image unavailable', style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280, maxHeight: 300),
        child: CachedNetworkImage(
          imageUrl: _imageUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: theme.brightness == Brightness.dark ? const Color(0xFF1C2333) : const Color(0xFFE8ECF2),
            highlightColor: theme.brightness == Brightness.dark ? const Color(0xFF2C3548) : const Color(0xFFF7F8FC),
            child: Container(
              width: 220,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 220,
            height: 120,
            color: theme.colorScheme.error.withValues(alpha: 0.1),
            child: Center(child: Icon(Icons.broken_image_rounded, size: 36, color: theme.colorScheme.error)),
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _FullscreenImageViewer(imageUrl: _imageUrl!, fileName: widget.fileName),
          );
        },
      ),
    );
  }
}

// ===== Fullscreen image viewer with pinch-to-zoom =====
class _FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String fileName;

  const _FullscreenImageViewer({required this.imageUrl, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: () async {
              final uri = Uri.parse(imageUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
            errorWidget: (context, url, error) => const Icon(Icons.broken_image_rounded, size: 64, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}

// ===== Fullscreen In-App PDF Viewer =====
class _InAppPdfViewerScreen extends StatefulWidget {
  final String r2Key;
  final String fileName;

  const _InAppPdfViewerScreen({required this.r2Key, required this.fileName});

  @override
  State<_InAppPdfViewerScreen> createState() => _InAppPdfViewerScreenState();
}

class _InAppPdfViewerScreenState extends State<_InAppPdfViewerScreen> {
  Uint8List? _pdfBytes;
  String? _pdfUrl;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    if (widget.r2Key.isEmpty) {
      setState(() {
        _error = 'PDF not available on cloud storage.';
        _isLoading = false;
      });
      return;
    }
    try {
      final res = await ApiService().getPresignedDownloadUrl(widget.r2Key);
      if (res['success'] == true && res['data'] != null) {
        final url = res['data']['download_url'] as String;
        _pdfUrl = url;
        final response = await Dio().get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.data != null && response.data!.isNotEmpty) {
          setState(() {
            _pdfBytes = Uint8List.fromList(response.data!);
            _isLoading = false;
          });
        } else {
          throw Exception('Received empty file data');
        }
      } else {
        throw Exception(res['error'] ?? 'Could not fetch PDF URL');
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load PDF: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF232731),
        elevation: 1,
        title: Text(widget.fileName, style: const TextStyle(color: Colors.white, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_pdfUrl != null)
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              tooltip: 'Open externally / Download',
              onPressed: () async {
                final uri = Uri.parse(_pdfUrl!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                    ],
                  ),
                )
              : SfPdfViewer.memory(_pdfBytes!),
    );
  }
}
