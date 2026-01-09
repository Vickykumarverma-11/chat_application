import 'package:equatable/equatable.dart';

enum MessageType { user, assistant }

enum MessageContentType { text, textLoading, imageLoading, imageResult, processedData, loading }

class ChatMessage extends Equatable {
  final String id;
  final String content;
  final MessageType type;
  final MessageContentType contentType;
  final DateTime timestamp;
  final String? imageUrl;
  final Map<String, dynamic>? processedData;
  final String? jobId;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.contentType,
    required this.timestamp,
    this.imageUrl,
    this.processedData,
    this.jobId,
  });

  ChatMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    MessageContentType? contentType,
    DateTime? timestamp,
    String? imageUrl,
    Map<String, dynamic>? processedData,
    String? jobId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      contentType: contentType ?? this.contentType,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      processedData: processedData ?? this.processedData,
      jobId: jobId ?? this.jobId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.index,
      'contentType': contentType.index,
      'timestamp': timestamp.toIso8601String(),
      'imageUrl': imageUrl,
      'processedData': processedData,
      'jobId': jobId,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      type: MessageType.values[json['type'] as int],
      contentType: MessageContentType.values[json['contentType'] as int],
      timestamp: DateTime.parse(json['timestamp'] as String),
      imageUrl: json['imageUrl'] as String?,
      processedData: json['processedData'] as Map<String, dynamic>?,
      jobId: json['jobId'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        content,
        type,
        contentType,
        timestamp,
        imageUrl,
        processedData,
        jobId,
      ];
}
