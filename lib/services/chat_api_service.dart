import 'package:dio/dio.dart';
import '../core/dio_client.dart';
import '../models/api_response.dart';

class ChatApiService {
  final Dio _dio;

  ChatApiService() : _dio = DioClient.instance;

  Future<ApiResponse> sendMessage(String message) async {
    try {
      final response = await _dio.post(
        '/chat',
        data: {'message': message},
      );
      return ApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ChatApiException(
        message: e.message ?? 'Failed to send message',
        type: ChatApiExceptionType.network,
      );
    } catch (e) {
      throw ChatApiException(
        message: 'Unexpected error occurred',
        type: ChatApiExceptionType.unknown,
      );
    }
  }

  Future<PollResponse> pollJob(String jobId) async {
    try {
      final response = await _dio.get('/poll/$jobId');
      return PollResponse.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw ChatApiException(
          message: 'Job not found',
          type: ChatApiExceptionType.notFound,
        );
      }
      throw ChatApiException(
        message: e.message ?? 'Failed to poll job status',
        type: ChatApiExceptionType.network,
      );
    } catch (e) {
      if (e is ChatApiException) rethrow;
      throw ChatApiException(
        message: 'Unexpected error during polling',
        type: ChatApiExceptionType.unknown,
      );
    }
  }
}

enum ChatApiExceptionType { network, notFound, unknown }

class ChatApiException implements Exception {
  final String message;
  final ChatApiExceptionType type;

  ChatApiException({required this.message, required this.type});

  @override
  String toString() => message;
}
