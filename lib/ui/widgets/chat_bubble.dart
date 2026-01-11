import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/chat_message.dart';
import 'full_screen_image.dart';
import 'typing_indicator.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const ChatBubble({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isUser = message.type == MessageType.user;
    final isFailed = message.deliveryStatus == DeliveryStatus.failed;

    final showTimestamp = message.contentType == MessageContentType.text ||
        message.contentType == MessageContentType.imageResult ||
        message.contentType == MessageContentType.multiImageResult ||
        message.contentType == MessageContentType.processedData;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              left: isUser ? 64 : 16,
              right: isUser ? 16 : 64,
              top: 8,
              bottom: (isFailed || showTimestamp) ? 2 : 8,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
            ),
            child: _buildContent(context, isUser),
          ),
          if (showTimestamp && !isFailed) _buildTimestamp(context, isUser),
          if (isFailed) _buildFailedIndicator(context),
        ],
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context, bool isUser) {
    final time = message.timestamp;
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 0 : 16,
        right: isUser ? 16 : 0,
        bottom: 6,
      ),
      child: Text(
        timeStr,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }

  Widget _buildFailedIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 8),
      child: GestureDetector(
        onTap: onRetry,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 14,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 4),
            Text(
              'Failed to send',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              Text(
                'Tap to retry',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isUser) {
    switch (message.contentType) {
      case MessageContentType.text:
        return GestureDetector(
          onLongPress: () => _copyToClipboard(context, message.content),
          child: Text(
            message.content,
            style: TextStyle(
              color: isUser
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );

      case MessageContentType.textLoading:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TypingIndicator(),
            const SizedBox(width: 8),
            Text(
              'Thinking...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );

      case MessageContentType.loading:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              message.content,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );

      case MessageContentType.imageLoading:
        final totalJobs = message.totalJobs ?? 1;
        final completedJobs = message.completedJobs ?? 0;
        final completedUrls = message.imageUrls ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (totalJobs > 1) ...[
            
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  
                  ...completedUrls.map((url) => _buildGridImage(context, url)),
                  
                  ...List.generate(totalJobs - completedJobs, (_) {
                    return Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        width: 120,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ] else ...[
           
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  width: 250,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  message.content,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        );

      case MessageContentType.imageResult:
        final url = message.imageUrl ?? message.imageUrls?.firstOrNull;
        if (url != null) {
          return _buildNetworkImage(context, url, width: 250, height: 180);
        }
        return const SizedBox.shrink();

      case MessageContentType.multiImageResult:
        return _buildMultiImageGrid(context);

      case MessageContentType.processedData:
        final jsonText = message.processedData != null
            ? _formatJson(message.processedData!)
            : '';
        return GestureDetector(
          onLongPress: () => _copyToClipboard(context, jsonText),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.content,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (message.processedData != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    jsonText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }

  Widget _buildMultiImageGrid(BuildContext context) {
    final urls = message.imageUrls ?? [];
    if (urls.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: urls.map((url) => _buildGridImage(context, url)).toList(),
    );
  }

  Widget _buildGridImage(BuildContext context, String url) {
    return _buildNetworkImage(context, url, width: 120, height: 90);
  }

  Widget _buildNetworkImage(
    BuildContext context,
    String url, {
    required double width,
    required double height,
  }) {
   
    final cacheKey = ValueKey(url);

    return GestureDetector(
      onTap: () => _openFullScreenImage(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          key: cacheKey,
          width: width,
          height: height,
          fit: BoxFit.cover,
          cacheWidth: (width * 2).toInt(),
          cacheHeight: (height * 2).toInt(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            final progress = loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null;
            return Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: width > 150 ? 3 : 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: width > 150 ? 40 : 24,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Failed to load',
                    style: TextStyle(
                      fontSize: width > 150 ? 12 : 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImage(imageUrl: url),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }

  String _formatJson(Map<String, dynamic> data) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }
}

