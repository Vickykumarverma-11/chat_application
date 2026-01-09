class AppConstants {
  AppConstants._();

  static const String baseUrl = 'https://mock-api.local';

  static const Duration pollingInterval = Duration(seconds: 2);
  static const int maxPollingAttempts = 15;

  static const List<String> placeholderImages = [
    'https://picsum.photos/seed/ai1/400/300',
    'https://picsum.photos/seed/ai2/400/300',
    'https://picsum.photos/seed/ai3/400/300',
    'https://picsum.photos/seed/ai4/400/300',
  ];
}

enum ChatResponseType { text, imageGeneration, dataProcessing }

enum JobStatus { pending, completed, failed }
