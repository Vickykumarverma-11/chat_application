import 'package:equatable/equatable.dart';
import '../core/constants.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class SendMessageEvent extends ChatEvent {
  final String message;

  const SendMessageEvent(this.message);

  @override
  List<Object?> get props => [message];
}

class ReceiveResponseEvent extends ChatEvent {
  final String content;
  final ChatResponseType responseType;
  final List<String>? jobIds;

  const ReceiveResponseEvent({
    required this.content,
    required this.responseType,
    this.jobIds,
  });

  @override
  List<Object?> get props => [content, responseType, jobIds];
}

class StartPollingEvent extends ChatEvent {
  final String jobId;
  final ChatResponseType jobType;
  final String messageId;
  final String userMessageId;

  const StartPollingEvent({
    required this.jobId,
    required this.jobType,
    required this.messageId,
    required this.userMessageId,
  });

  @override
  List<Object?> get props => [jobId, jobType, messageId, userMessageId];
}

class PollingCompletedEvent extends ChatEvent {
  final String jobId;
  final String messageId;
  final Map<String, dynamic> result;

  const PollingCompletedEvent({
    required this.jobId,
    required this.messageId,
    required this.result,
  });

  @override
  List<Object?> get props => [jobId, messageId, result];
}

class PollingFailedEvent extends ChatEvent {
  final String jobId;
  final String messageId;
  final String userMessageId;
  final String error;

  const PollingFailedEvent({
    required this.jobId,
    required this.messageId,
    required this.userMessageId,
    required this.error,
  });

  @override
  List<Object?> get props => [jobId, messageId, userMessageId, error];
}

class ResumeActiveJobsEvent extends ChatEvent {
  const ResumeActiveJobsEvent();
}

class RetryMessageEvent extends ChatEvent {
  final String messageId;

  const RetryMessageEvent(this.messageId);

  @override
  List<Object?> get props => [messageId];
}

class CancelActiveJobsEvent extends ChatEvent {
  const CancelActiveJobsEvent();
}
