import 'dart:async';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/api_response.dart';
import '../models/chat_message.dart';
import '../services/chat_api_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends HydratedBloc<ChatEvent, ChatState> {
  final ChatApiService _apiService;
  final Uuid _uuid = const Uuid();
  final Map<String, Timer> _pollingTimers = {};
  final Map<String, int> _pollingAttempts = {};

  ChatBloc({ChatApiService? apiService})
    : _apiService = apiService ?? ChatApiService(),
      super(const ChatState()) {
    on<SendMessageEvent>(_onSendMessage);
    on<StartPollingEvent>(_onStartPolling);
    on<_PollTickEvent>(_onPollTick);
    on<PollingCompletedEvent>(_onPollingCompleted);
    on<PollingFailedEvent>(_onPollingFailed);
    on<ResumeActiveJobsEvent>(_onResumeActiveJobs);

    _scheduleJobRecovery();
  }

  void _scheduleJobRecovery() {
    Future.microtask(() {
      if (state.activeJobs.isNotEmpty) {
        add(const ResumeActiveJobsEvent());
      }
    });
  }

  void _onResumeActiveJobs(
    ResumeActiveJobsEvent event,
    Emitter<ChatState> emit,
  ) {
    for (final entry in state.activeJobs.entries) {
      final job = entry.value;
      if (job.status == JobStatus.pending) {
        _pollingAttempts[job.jobId] = 0;
        _startPollingTimer(job.jobId, job.messageId);
      }
    }
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (event.message.trim().isEmpty) return;

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      content: event.message,
      type: MessageType.user,
      contentType: MessageContentType.text,
      timestamp: DateTime.now(),
    );

    final placeholderId = _uuid.v4();
    final placeholderMessage = ChatMessage(
      id: placeholderId,
      content: 'Thinking...',
      type: MessageType.assistant,
      contentType: MessageContentType.textLoading,
      timestamp: DateTime.now(),
    );

    emit(
      state.copyWith(
        messages: [...state.messages, userMessage, placeholderMessage],
        isLoading: true,
        errorMessage: null,
      ),
    );

    try {
      final response = await _apiService.sendMessage(event.message);
      _handleApiResponse(response, emit, placeholderId);
    } on ChatApiException catch (e) {
      final updatedMessages = state.messages
          .where((m) => m.id != placeholderId)
          .toList();
      emit(
        state.copyWith(
          messages: updatedMessages,
          isLoading: false,
          errorMessage: e.message,
        ),
      );
    }
  }

  void _handleApiResponse(
    ApiResponse response,
    Emitter<ChatState> emit,
    String placeholderId,
  ) {
    final messageIndex = state.messages.indexWhere(
      (m) => m.id == placeholderId,
    );
    if (messageIndex == -1) return;

    switch (response.type) {
      case ChatResponseType.text:
        final updatedMessage = state.messages[messageIndex].copyWith(
          content: response.content,
          contentType: MessageContentType.text,
        );

        final updatedMessages = List<ChatMessage>.from(state.messages);
        updatedMessages[messageIndex] = updatedMessage;

        emit(state.copyWith(messages: updatedMessages, isLoading: false));

      case ChatResponseType.imageGeneration:
        final jobId = response.jobIds?.first;
        if (jobId == null) {
          final updatedMessages = state.messages
              .where((m) => m.id != placeholderId)
              .toList();
          emit(
            state.copyWith(
              messages: updatedMessages,
              isLoading: false,
              errorMessage: 'Invalid response: missing job ID',
            ),
          );
          return;
        }

        final updatedMessage = state.messages[messageIndex].copyWith(
          content: 'Generating image...',
          contentType: MessageContentType.imageLoading,
          jobId: jobId,
        );

        final updatedMessages = List<ChatMessage>.from(state.messages);
        updatedMessages[messageIndex] = updatedMessage;

        final newActiveJobs = Map<String, ActiveJob>.from(state.activeJobs);
        newActiveJobs[jobId] = ActiveJob(
          jobId: jobId,
          type: ChatResponseType.imageGeneration,
          status: JobStatus.pending,
          messageId: placeholderId,
        );

        emit(
          state.copyWith(
            messages: updatedMessages,
            isLoading: false,
            activeJobs: newActiveJobs,
            waitingMessage: 'Generating image...',
          ),
        );

        add(
          StartPollingEvent(
            jobId: jobId,
            jobType: ChatResponseType.imageGeneration,
            messageId: placeholderId,
          ),
        );

      case ChatResponseType.dataProcessing:
        final jobId = response.jobIds?.first;
        if (jobId == null) {
          final updatedMessages = state.messages
              .where((m) => m.id != placeholderId)
              .toList();
          emit(
            state.copyWith(
              messages: updatedMessages,
              isLoading: false,
              errorMessage: 'Invalid response: missing job ID',
            ),
          );
          return;
        }

        final updatedMessage = state.messages[messageIndex].copyWith(
          content: 'Processing data...',
          contentType: MessageContentType.loading,
          jobId: jobId,
        );

        final updatedMessages = List<ChatMessage>.from(state.messages);
        updatedMessages[messageIndex] = updatedMessage;

        final newActiveJobs = Map<String, ActiveJob>.from(state.activeJobs);
        newActiveJobs[jobId] = ActiveJob(
          jobId: jobId,
          type: ChatResponseType.dataProcessing,
          status: JobStatus.pending,
          messageId: placeholderId,
        );

        emit(
          state.copyWith(
            messages: updatedMessages,
            isLoading: false,
            activeJobs: newActiveJobs,
            waitingMessage: 'Processing data...',
          ),
        );

        add(
          StartPollingEvent(
            jobId: jobId,
            jobType: ChatResponseType.dataProcessing,
            messageId: placeholderId,
          ),
        );
    }
  }

  void _onStartPolling(StartPollingEvent event, Emitter<ChatState> emit) {
    _pollingAttempts[event.jobId] = 0;
    _startPollingTimer(event.jobId, event.messageId);
  }

  void _startPollingTimer(String jobId, String messageId) {
    _pollingTimers[jobId]?.cancel();
    _pollingTimers[jobId] = Timer(
      AppConstants.pollingInterval,
      () => add(_PollTickEvent(jobId: jobId, messageId: messageId)),
    );
  }

  Future<void> _onPollTick(
    _PollTickEvent event,
    Emitter<ChatState> emit,
  ) async {
    final attempts = _pollingAttempts[event.jobId] ?? 0;
    if (attempts >= AppConstants.maxPollingAttempts) {
      add(
        PollingFailedEvent(
          jobId: event.jobId,
          messageId: event.messageId,
          error: 'Polling timeout - please try again',
        ),
      );
      return;
    }

    _pollingAttempts[event.jobId] = attempts + 1;

    try {
      final response = await _apiService.pollJob(event.jobId);

      switch (response.status) {
        case JobStatus.pending:
          _startPollingTimer(event.jobId, event.messageId);

        case JobStatus.completed:
          if (response.result != null) {
            add(
              PollingCompletedEvent(
                jobId: event.jobId,
                messageId: event.messageId,
                result: response.result!,
              ),
            );
          } else {
            add(
              PollingFailedEvent(
                jobId: event.jobId,
                messageId: event.messageId,
                error: 'Job completed but no result received',
              ),
            );
          }

        case JobStatus.failed:
          add(
            PollingFailedEvent(
              jobId: event.jobId,
              messageId: event.messageId,
              error: response.error ?? 'Job failed',
            ),
          );
      }
    } on ChatApiException catch (e) {
      add(
        PollingFailedEvent(
          jobId: event.jobId,
          messageId: event.messageId,
          error: e.message,
        ),
      );
    }
  }

  void _onPollingCompleted(
    PollingCompletedEvent event,
    Emitter<ChatState> emit,
  ) {
    _cleanupPolling(event.jobId);

    final activeJob = state.activeJobs[event.jobId];
    if (activeJob == null) return;

    final messageIndex = state.messages.indexWhere(
      (m) => m.id == event.messageId,
    );
    if (messageIndex == -1) return;

    ChatMessage updatedMessage;
    if (activeJob.type == ChatResponseType.imageGeneration) {
      final imageUrl = event.result['imageUrl'] as String?;
      updatedMessage = state.messages[messageIndex].copyWith(
        content: 'Image generated successfully',
        contentType: MessageContentType.imageResult,
        imageUrl: imageUrl,
      );
    } else {
      final processedData =
          event.result['processedData'] as Map<String, dynamic>?;
      updatedMessage = state.messages[messageIndex].copyWith(
        content: 'Data processing complete',
        contentType: MessageContentType.processedData,
        processedData: processedData,
      );
    }

    final updatedMessages = List<ChatMessage>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;

    final newActiveJobs = Map<String, ActiveJob>.from(state.activeJobs);
    newActiveJobs.remove(event.jobId);

    emit(
      state.copyWith(
        messages: updatedMessages,
        activeJobs: newActiveJobs,
        waitingMessage: newActiveJobs.isEmpty ? null : state.waitingMessage,
      ),
    );
  }

  void _onPollingFailed(PollingFailedEvent event, Emitter<ChatState> emit) {
    _cleanupPolling(event.jobId);

    final messageIndex = state.messages.indexWhere(
      (m) => m.id == event.messageId,
    );
    if (messageIndex == -1) return;

    final updatedMessage = state.messages[messageIndex].copyWith(
      content: 'Failed: ${event.error}',
      contentType: MessageContentType.text,
    );

    final updatedMessages = List<ChatMessage>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;

    final newActiveJobs = Map<String, ActiveJob>.from(state.activeJobs);
    newActiveJobs.remove(event.jobId);

    emit(
      state.copyWith(
        messages: updatedMessages,
        activeJobs: newActiveJobs,
        waitingMessage: newActiveJobs.isEmpty ? null : state.waitingMessage,
        errorMessage: event.error,
      ),
    );
  }

  void _cleanupPolling(String jobId) {
    _pollingTimers[jobId]?.cancel();
    _pollingTimers.remove(jobId);
    _pollingAttempts.remove(jobId);
  }

  @override
  ChatState? fromJson(Map<String, dynamic> json) {
    try {
      return ChatState.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(ChatState state) {
    return state.toJson();
  }

  @override
  Future<void> close() {
    for (final timer in _pollingTimers.values) {
      timer.cancel();
    }
    _pollingTimers.clear();
    _pollingAttempts.clear();
    return super.close();
  }
}

class _PollTickEvent extends ChatEvent {
  final String jobId;
  final String messageId;

  const _PollTickEvent({required this.jobId, required this.messageId});

  @override
  List<Object?> get props => [jobId, messageId];
}
