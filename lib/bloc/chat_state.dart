import 'package:equatable/equatable.dart';
import '../core/constants.dart';
import '../models/chat_message.dart';

class ActiveJob extends Equatable {
  final String jobId;
  final ChatResponseType type;
  final JobStatus status;
  final String messageId;  
  final String userMessageId;  

  const ActiveJob({
    required this.jobId,
    required this.type,
    required this.status,
    required this.messageId,
    required this.userMessageId,
  });

  ActiveJob copyWith({
    String? jobId,
    ChatResponseType? type,
    JobStatus? status,
    String? messageId,
    String? userMessageId,
  }) {
    return ActiveJob(
      jobId: jobId ?? this.jobId,
      type: type ?? this.type,
      status: status ?? this.status,
      messageId: messageId ?? this.messageId,
      userMessageId: userMessageId ?? this.userMessageId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jobId': jobId,
      'type': type.index,
      'status': status.index,
      'messageId': messageId,
      'userMessageId': userMessageId,
    };
  }

  factory ActiveJob.fromJson(Map<String, dynamic> json) {
    return ActiveJob(
      jobId: json['jobId'] as String,
      type: ChatResponseType.values[json['type'] as int],
      status: JobStatus.values[json['status'] as int],
      messageId: json['messageId'] as String,
      userMessageId: json['userMessageId'] as String? ?? json['messageId'] as String,
    );
  }

  @override
  List<Object?> get props => [jobId, type, status, messageId, userMessageId];
}

class ChatState extends Equatable {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, ActiveJob> activeJobs;
  final String? waitingMessage;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
    this.activeJobs = const {},
    this.waitingMessage,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
    Map<String, ActiveJob>? activeJobs,
    String? waitingMessage,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeJobs: activeJobs ?? this.activeJobs,
      waitingMessage: waitingMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messages': messages.map((m) => m.toJson()).toList(),
      'isLoading': isLoading,
      'errorMessage': errorMessage,
      'activeJobs': activeJobs.map((k, v) => MapEntry(k, v.toJson())),
      'waitingMessage': waitingMessage,
    };
  }

  factory ChatState.fromJson(Map<String, dynamic> json) {
    return ChatState(
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [],
      isLoading: json['isLoading'] as bool? ?? false,
      errorMessage: json['errorMessage'] as String?,
      activeJobs: (json['activeJobs'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, ActiveJob.fromJson(v as Map<String, dynamic>)),
          ) ??
          const {},
      waitingMessage: json['waitingMessage'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        isLoading,
        errorMessage,
        activeJobs,
        waitingMessage,
      ];
}
