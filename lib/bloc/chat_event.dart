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

  const StartPollingEvent({
    required this.jobId,
    required this.jobType,
    required this.messageId,
  });

  @override
  List<Object?> get props => [jobId, jobType, messageId];
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
  final String error;

  const PollingFailedEvent({
    required this.jobId,
    required this.messageId,
    required this.error,
  });

  @override
  List<Object?> get props => [jobId, messageId, error];
}

class ResumeActiveJobsEvent extends ChatEvent {
  const ResumeActiveJobsEvent();
}
