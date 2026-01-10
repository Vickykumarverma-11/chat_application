import 'package:equatable/equatable.dart';

enum MessageType { user, assistant }

enum MessageContentType { text, textLoading, imageLoading, imageResult, multiImageResult, processedData, loading }

enum DeliveryStatus { sending, sent, failed }

class ChatMessage extends Equatable {
  final String id;
  final String content;
  final MessageType type;
  final MessageContentType contentType;
  final DateTime timestamp;
  final String? imageUrl;
  final List<String>? imageUrls; // For multiple images
  final Map<String, dynamic>? processedData;
  final String? jobId;
  final List<String>? jobIds; // For tracking multiple jobs
  final int? totalJobs; // Total number of jobs for this message
  final int? completedJobs; // Number of completed jobs
  final DeliveryStatus? deliveryStatus; // For user message delivery tracking
  final String? errorMessage; // Error message when delivery fails

  const ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.contentType,
    required this.timestamp,
    this.imageUrl,
    this.imageUrls,
    this.processedData,
    this.jobId,
    this.jobIds,
    this.totalJobs,
    this.completedJobs,
    this.deliveryStatus,
    this.errorMessage,
  });

  ChatMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    MessageContentType? contentType,
    DateTime? timestamp,
    String? imageUrl,
    List<String>? imageUrls,
    Map<String, dynamic>? processedData,
    String? jobId,
    List<String>? jobIds,
    int? totalJobs,
    int? completedJobs,
    DeliveryStatus? deliveryStatus,
    String? errorMessage,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      contentType: contentType ?? this.contentType,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      processedData: processedData ?? this.processedData,
      jobId: jobId ?? this.jobId,
      jobIds: jobIds ?? this.jobIds,
      totalJobs: totalJobs ?? this.totalJobs,
      completedJobs: completedJobs ?? this.completedJobs,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      errorMessage: errorMessage ?? this.errorMessage,
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
      'imageUrls': imageUrls,
      'processedData': processedData,
      'jobId': jobId,
      'jobIds': jobIds,
      'totalJobs': totalJobs,
      'completedJobs': completedJobs,
      'deliveryStatus': deliveryStatus?.index,
      'errorMessage': errorMessage,
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
      imageUrls: (json['imageUrls'] as List<dynamic>?)?.cast<String>(),
      processedData: json['processedData'] as Map<String, dynamic>?,
      jobId: json['jobId'] as String?,
      jobIds: (json['jobIds'] as List<dynamic>?)?.cast<String>(),
      totalJobs: json['totalJobs'] as int?,
      completedJobs: json['completedJobs'] as int?,
      deliveryStatus: json['deliveryStatus'] != null
          ? DeliveryStatus.values[json['deliveryStatus'] as int]
          : null,
      errorMessage: json['errorMessage'] as String?,
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
        imageUrls,
        processedData,
        jobId,
        jobIds,
        totalJobs,
        completedJobs,
        deliveryStatus,
        errorMessage,
      ];
}
