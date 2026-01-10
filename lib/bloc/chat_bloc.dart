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
    on<RetryMessageEvent>(_onRetryMessage);
    on<StartPollingEvent>(_onStartPolling);
    on<_PollTickEvent>(_onPollTick);
    on<PollingCompletedEvent>(_onPollingCompleted);
    on<PollingFailedEvent>(_onPollingFailed);
    on<ResumeActiveJobsEvent>(_onResumeActiveJobs);
    on<CancelActiveJobsEvent>(_onCancelActiveJobs);

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
        _startPollingTimer(job.jobId, job.messageId, job.userMessageId);
      }
    }
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (event.message.trim().isEmpty) return;

    final userMessageId = _uuid.v4();
    final userMessage = ChatMessage(
      id: userMessageId,
      content: event.message,
      type: MessageType.user,
      contentType: MessageContentType.text,
      timestamp: DateTime.now(),
      deliveryStatus: DeliveryStatus.sending,
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

      // Update user message to sent
      final userMsgIndex = state.messages.indexWhere((m) => m.id == userMessageId);
      if (userMsgIndex != -1) {
        final updatedMessages = List<ChatMessage>.from(state.messages);
        updatedMessages[userMsgIndex] = updatedMessages[userMsgIndex].copyWith(
          deliveryStatus: DeliveryStatus.sent,
        );
        emit(state.copyWith(messages: updatedMessages));
      }

      _handleApiResponse(response, emit, placeholderId, userMessageId);
    } on ChatApiException catch (e) {
      // Remove placeholder and mark user message as failed
      final updatedMessages = state.messages
          .where((m) => m.id != placeholderId)
          .toList();

      final userMsgIndex = updatedMessages.indexWhere((m) => m.id == userMessageId);
      if (userMsgIndex != -1) {
        updatedMessages[userMsgIndex] = updatedMessages[userMsgIndex].copyWith(
          deliveryStatus: DeliveryStatus.failed,
          errorMessage: e.message,
        );
      }

      emit(
        state.copyWith(
          messages: updatedMessages,
          isLoading: false,
        ),
      );
    }
  }

  Future<void> _onRetryMessage(
    RetryMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    final messageIndex = state.messages.indexWhere((m) => m.id == event.messageId);
    if (messageIndex == -1) return;

    final failedMessage = state.messages[messageIndex];
    if (failedMessage.type != MessageType.user ||
        failedMessage.deliveryStatus != DeliveryStatus.failed) {
      return;
    }

    // Update to sending status
    final updatedMessages = List<ChatMessage>.from(state.messages);
    updatedMessages[messageIndex] = failedMessage.copyWith(
      deliveryStatus: DeliveryStatus.sending,
      errorMessage: null,
    );

    // Add placeholder for assistant response
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
        messages: [...updatedMessages, placeholderMessage],
        isLoading: true,
        errorMessage: null,
      ),
    );

    try {
      final response = await _apiService.sendMessage(failedMessage.content);

      // Update user message to sent
      final userMsgIndex = state.messages.indexWhere((m) => m.id == event.messageId);
      if (userMsgIndex != -1) {
        final msgs = List<ChatMessage>.from(state.messages);
        msgs[userMsgIndex] = msgs[userMsgIndex].copyWith(
          deliveryStatus: DeliveryStatus.sent,
        );
        emit(state.copyWith(messages: msgs));
      }

      _handleApiResponse(response, emit, placeholderId, event.messageId);
    } on ChatApiException catch (e) {
      // Remove placeholder and mark user message as failed again
      final msgs = state.messages.where((m) => m.id != placeholderId).toList();

      final userMsgIndex = msgs.indexWhere((m) => m.id == event.messageId);
      if (userMsgIndex != -1) {
        msgs[userMsgIndex] = msgs[userMsgIndex].copyWith(
          deliveryStatus: DeliveryStatus.failed,
          errorMessage: e.message,
        );
      }

      emit(
        state.copyWith(
          messages: msgs,
          isLoading: false,
        ),
      );
    }
  }

  void _handleApiResponse(
    ApiResponse response,
    Emitter<ChatState> emit,
    String placeholderId,
    String userMessageId,
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
        final jobIds = response.jobIds;
        if (jobIds == null || jobIds.isEmpty) {
          final updatedMessages = state.messages
              .where((m) => m.id != placeholderId)
              .toList();
          emit(
            state.copyWith(
              messages: updatedMessages,
              isLoading: false,
              errorMessage: 'Invalid response: missing job IDs',
            ),
          );
          return;
        }

        final imageCount = jobIds.length;
        final updatedMessage = state.messages[messageIndex].copyWith(
          content: 'Generating $imageCount image${imageCount > 1 ? 's' : ''}...',
          contentType: MessageContentType.imageLoading,
          jobIds: jobIds,
          totalJobs: imageCount,
          completedJobs: 0,
          imageUrls: [],
        );

        final updatedMessages = List<ChatMessage>.from(state.messages);
        updatedMessages[messageIndex] = updatedMessage;

        final newActiveJobs = Map<String, ActiveJob>.from(state.activeJobs);
        for (final jobId in jobIds) {
          newActiveJobs[jobId] = ActiveJob(
            jobId: jobId,
            type: ChatResponseType.imageGeneration,
            status: JobStatus.pending,
            messageId: placeholderId,
            userMessageId: userMessageId,
          );
        }

        emit(
          state.copyWith(
            messages: updatedMessages,
            isLoading: false,
            activeJobs: newActiveJobs,
            waitingMessage: 'Generating $imageCount image${imageCount > 1 ? 's' : ''}...',
          ),
        );

        // Start polling for all jobs
        for (final jobId in jobIds) {
          add(
            StartPollingEvent(
              jobId: jobId,
              jobType: ChatResponseType.imageGeneration,
              messageId: placeholderId,
              userMessageId: userMessageId,
            ),
          );
        }

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
          userMessageId: userMessageId,
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
            userMessageId: userMessageId,
          ),
        );
    }
  }

  void _onStartPolling(StartPollingEvent event, Emitter<ChatState> emit) {
    _pollingAttempts[event.jobId] = 0;
    _startPollingTimer(event.jobId, event.messageId, event.userMessageId);
  }

  void _startPollingTimer(String jobId, String messageId, String userMessageId) {
    _pollingTimers[jobId]?.cancel();
    _pollingTimers[jobId] = Timer(
      AppConstants.pollingInterval,
      () => add(_PollTickEvent(jobId: jobId, messageId: messageId, userMessageId: userMessageId)),
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
          userMessageId: event.userMessageId,
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
          _startPollingTimer(event.jobId, event.messageId, event.userMessageId);

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
                userMessageId: event.userMessageId,
                error: 'Job completed but no result received',
              ),
            );
          }

        case JobStatus.failed:
          add(
            PollingFailedEvent(
              jobId: event.jobId,
              messageId: event.messageId,
              userMessageId: event.userMessageId,
              error: response.error ?? 'Job failed',
            ),
          );
      }
    } on ChatApiException catch (e) {
      add(
        PollingFailedEvent(
          jobId: event.jobId,
          messageId: event.messageId,
          userMessageId: event.userMessageId,
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

    final currentMessage = state.messages[messageIndex];
    ChatMessage updatedMessage;

    if (activeJob.type == ChatResponseType.imageGeneration) {
      final imageUrl = event.result['imageUrl'] as String?;
      final currentUrls = List<String>.from(currentMessage.imageUrls ?? []);
      if (imageUrl != null) {
        currentUrls.add(imageUrl);
      }

      final completedCount = (currentMessage.completedJobs ?? 0) + 1;
      final totalCount = currentMessage.totalJobs ?? 1;
      final allComplete = completedCount >= totalCount;

      updatedMessage = currentMessage.copyWith(
        content: allComplete
            ? ''
            : 'Generating images... ($completedCount/$totalCount)',
        contentType: allComplete
            ? (totalCount > 1
                ? MessageContentType.multiImageResult
                : MessageContentType.imageResult)
            : MessageContentType.imageLoading,
        imageUrls: currentUrls,
        imageUrl: totalCount == 1 ? imageUrl : null,
        completedJobs: completedCount,
      );
    } else {
      final processedData =
          event.result['processedData'] as Map<String, dynamic>?;
      updatedMessage = currentMessage.copyWith(
        content: 'Data processing complete',
        contentType: MessageContentType.processedData,
        processedData: processedData,
      );
    }

    final updatedMessages = List<ChatMessage>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;

    final newActiveJobs = Map<String, ActiveJob>.from(state.activeJobs);
    newActiveJobs.remove(event.jobId);

    // Update waiting message based on remaining jobs for this message
    String? newWaitingMessage;
    if (newActiveJobs.isNotEmpty) {
      final remainingForMessage = newActiveJobs.values
          .where((job) => job.messageId == event.messageId)
          .length;
      if (remainingForMessage > 0) {
        final total = currentMessage.totalJobs ?? 1;
        final completed = (currentMessage.completedJobs ?? 0) + 1;
        newWaitingMessage = 'Generating images... ($completed/$total)';
      } else {
        // Check if there are other active jobs
        newWaitingMessage = newActiveJobs.isNotEmpty ? state.waitingMessage : null;
      }
    }

    emit(
      state.copyWith(
        messages: updatedMessages,
        activeJobs: newActiveJobs,
        waitingMessage: newWaitingMessage,
      ),
    );
  }

  void _onPollingFailed(PollingFailedEvent event, Emitter<ChatState> emit) {
    // Find all jobs associated with this message and cancel them all
    final jobsForMessage = state.activeJobs.entries
        .where((e) => e.value.messageId == event.messageId)
        .map((e) => e.key)
        .toList();

    // Cleanup polling for all related jobs
    for (final jobId in jobsForMessage) {
      _cleanupPolling(jobId);
    }

    // Remove the assistant placeholder message
    final updatedMessages = state.messages
        .where((m) => m.id != event.messageId)
        .toList();

    // Find and update the user message to failed status
    final userMsgIndex = updatedMessages.indexWhere(
      (m) => m.id == event.userMessageId,
    );
    if (userMsgIndex != -1) {
      updatedMessages[userMsgIndex] = updatedMessages[userMsgIndex].copyWith(
        deliveryStatus: DeliveryStatus.failed,
        errorMessage: event.error,
      );
    }

    // Remove all jobs for this message from activeJobs
    final newActiveJobs = Map<String, ActiveJob>.from(state.activeJobs);
    for (final jobId in jobsForMessage) {
      newActiveJobs.remove(jobId);
    }

    emit(
      state.copyWith(
        messages: updatedMessages,
        activeJobs: newActiveJobs,
      ),
    );
  }

  void _onCancelActiveJobs(
    CancelActiveJobsEvent event,
    Emitter<ChatState> emit,
  ) {
    if (state.activeJobs.isEmpty) return;

    // Get all active job info before cleanup
    final jobsToCancel = Map<String, ActiveJob>.from(state.activeJobs);

    // Cancel all polling timers
    for (final jobId in jobsToCancel.keys) {
      _cleanupPolling(jobId);
    }

    // Group jobs by messageId to remove placeholders
    final messageIds = jobsToCancel.values.map((j) => j.messageId).toSet();
    final userMessageIds = jobsToCancel.values.map((j) => j.userMessageId).toSet();

    // Remove placeholder messages and update user messages
    final updatedMessages = state.messages
        .where((m) => !messageIds.contains(m.id))
        .toList();

    // Mark user messages as cancelled (not failed, just cancelled)
    for (var i = 0; i < updatedMessages.length; i++) {
      if (userMessageIds.contains(updatedMessages[i].id)) {
        updatedMessages[i] = updatedMessages[i].copyWith(
          deliveryStatus: DeliveryStatus.sent, // Mark as sent since user cancelled
        );
      }
    }

    emit(
      state.copyWith(
        messages: updatedMessages,
        activeJobs: const {},
        isLoading: false,
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
  final String userMessageId;

  const _PollTickEvent({
    required this.jobId,
    required this.messageId,
    required this.userMessageId,
  });

  @override
  List<Object?> get props => [jobId, messageId, userMessageId];
}
