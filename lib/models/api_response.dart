import '../core/constants.dart';

class ApiResponse {
  final String content;
  final ChatResponseType type;
  final List<String>? jobIds;

  ApiResponse({
    required this.content,
    required this.type,
    this.jobIds,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      content: json['content'] ?? '',
      type: _parseResponseType(json['type']),
      jobIds: json['jobIds'] != null ? List<String>.from(json['jobIds']) : null,
    );
  }

  static ChatResponseType _parseResponseType(String? type) {
    switch (type) {
      case 'imageGeneration':
        return ChatResponseType.imageGeneration;
      case 'dataProcessing':
        return ChatResponseType.dataProcessing;
      default:
        return ChatResponseType.text;
    }
  }
}

class PollResponse {
  final JobStatus status;
  final String? error;
  final Map<String, dynamic>? result;

  PollResponse({
    required this.status,
    this.error,
    this.result,
  });

  factory PollResponse.fromJson(Map<String, dynamic> json) {
    return PollResponse(
      status: _parseStatus(json['status']),
      error: json['error'],
      result: json['result'],
    );
  }

  static JobStatus _parseStatus(String? status) {
    switch (status) {
      case 'completed':
        return JobStatus.completed;
      case 'failed':
        return JobStatus.failed;
      default:
        return JobStatus.pending;
    }
  }
}
