import 'dart:math';
import 'package:dio/dio.dart';
import 'constants.dart';

class DioClient {
  static Dio? _instance;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    dio.interceptors.add(MockApiInterceptor());
    return dio;
  }
}

class MockApiInterceptor extends Interceptor {
  final Random _random = Random();
  final Map<String, _MockJob> _jobs = {};

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await Future.delayed(Duration(milliseconds: 500 + _random.nextInt(1000)));

    if (_random.nextDouble() < 0.1) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Network connection failed',
        ),
      );
      return;
    }

    if (options.path == '/chat' && options.method == 'POST') {
      _handleChatRequest(options, handler);
    } else if (options.path.startsWith('/poll/') && options.method == 'GET') {
      _handlePollRequest(options, handler);
    } else {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          message: 'Unknown endpoint',
        ),
      );
    }
  }

  void _handleChatRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // Extract user message from request body
    final message = (options.data as Map<String, dynamic>?)?['message'] as String? ?? '';
    final responseType = _getResponseTypeFromIntent(message);
    late Map<String, dynamic> responseData;

    switch (responseType) {
      case ChatResponseType.text:
        responseData = {
          'type': 'text',
          'content': _getRandomTextResponse(),
          'jobIds': null,
        };

      case ChatResponseType.imageGeneration:
        // Generate 1 or 2 images randomly based on timestamp
        final imageCount = DateTime.now().millisecond % 2 == 0 ? 2 : 1;
        final jobIds = <String>[];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        for (var i = 0; i < imageCount; i++) {
          final jobId = 'img_${timestamp}_$i';
          _jobs[jobId] = _MockJob(
            type: ChatResponseType.imageGeneration,
            createdAt: DateTime.now(),
          );
          jobIds.add(jobId);
        }
        responseData = {
          'type': 'imageGeneration',
          'content': 'Generating $imageCount images...',
          'jobIds': jobIds,
        };

      case ChatResponseType.dataProcessing:
        final jobId = 'data_${DateTime.now().millisecondsSinceEpoch}';
        _jobs[jobId] = _MockJob(
          type: ChatResponseType.dataProcessing,
          createdAt: DateTime.now(),
        );
        responseData = {
          'type': 'dataProcessing',
          'content': 'Processing your request...',
          'jobIds': [jobId],
        };
    }

    handler.resolve(
      Response(requestOptions: options, statusCode: 200, data: responseData),
    );
  }

  void _handlePollRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final jobId = options.path.replaceFirst('/poll/', '');
    final job = _jobs[jobId];

    if (job == null) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 404,
          data: {'status': 'failed', 'error': 'Job not found'},
        ),
      );
      return;
    }

    final elapsed = DateTime.now().difference(job.createdAt).inSeconds;

    // Job completes after 4-8 seconds, with 15% failure chance
    if (elapsed >= 4 + _random.nextInt(5)) {
      if (_random.nextDouble() < 0.15) {
        _jobs.remove(jobId);
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'status': 'failed', 'error': 'Job processing failed'},
          ),
        );
      } else {
        _jobs.remove(jobId);
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'status': 'completed', 'result': _getJobResult(job.type)},
          ),
        );
      }
    } else {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {'status': 'pending'},
        ),
      );
    }
  }

  /// Determines response type based on simple keyword matching.
  /// This simulates realistic AI behavior where:
  /// - Image-related keywords trigger image generation
  /// - Data/analysis keywords trigger data processing
  /// - Everything else returns a text response
  ChatResponseType _getResponseTypeFromIntent(String message) {
    final lowerMessage = message.toLowerCase();

    // Image generation keywords
    const imageKeywords = ['image', 'generate', 'picture', 'photo', 'draw', 'create image'];
    for (final keyword in imageKeywords) {
      if (lowerMessage.contains(keyword)) {
        return ChatResponseType.imageGeneration;
      }
    }

    // Data processing keywords
    const dataKeywords = ['data', 'process', 'analyze', 'analysis', 'model', 'report', 'statistics'];
    for (final keyword in dataKeywords) {
      if (lowerMessage.contains(keyword)) {
        return ChatResponseType.dataProcessing;
      }
    }

    // Default to text for greetings, questions, and general messages
    return ChatResponseType.text;
  }

  String _getRandomTextResponse() {
    final responses = [
      'That\'s a great question! Let me help you with that.',
      'I understand what you\'re looking for. Here\'s my suggestion.',
      'Based on my analysis, I would recommend the following approach.',
      'Interesting point! Here\'s what I think about it.',
      'I\'ve processed your request. Here are my thoughts on the matter.',
    ];
    return responses[_random.nextInt(responses.length)];
  }

  Map<String, dynamic> _getJobResult(ChatResponseType type) {
    if (type == ChatResponseType.imageGeneration) {
      return {
        'imageUrl':
            AppConstants.placeholderImages[_random.nextInt(
              AppConstants.placeholderImages.length,
            )],
      };
    } else {
      return {
        'processedData': {
          'summary': 'Analysis complete',
          'itemsProcessed': 50 + _random.nextInt(150),
          'confidence': (0.75 + _random.nextDouble() * 0.24).toStringAsFixed(2),
          'categories': ['Technology', 'Innovation', 'Research'],
          'timestamp': DateTime.now().toIso8601String(),
        },
      };
    }
  }
}

class _MockJob {
  final ChatResponseType type;
  final DateTime createdAt;

  _MockJob({required this.type, required this.createdAt});
}
