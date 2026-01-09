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
    final responseType = _getRandomResponseType();
    late Map<String, dynamic> responseData;

    switch (responseType) {
      case ChatResponseType.text:
        responseData = {
          'type': 'text',
          'content': _getRandomTextResponse(),
          'jobIds': null,
        };

      case ChatResponseType.imageGeneration:
        final jobId = 'img_${DateTime.now().millisecondsSinceEpoch}';
        _jobs[jobId] = _MockJob(
          type: ChatResponseType.imageGeneration,
          createdAt: DateTime.now(),
        );
        responseData = {
          'type': 'imageGeneration',
          'content': 'Starting image generation...',
          'jobIds': [jobId],
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

  ChatResponseType _getRandomResponseType() {
    final roll = _random.nextDouble();
    if (roll < 0.4) return ChatResponseType.text;
    if (roll < 0.7) return ChatResponseType.imageGeneration;
    return ChatResponseType.dataProcessing;
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
