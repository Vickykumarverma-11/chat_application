import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/message_input.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  bool _hasScrolledOnInit = false;

  @override
  void initState() {
    super.initState();
  }

  void _scrollToBottomOnInit() {
    if (_hasScrolledOnInit) return;
    _hasScrolledOnInit = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Assistant'),
        centerTitle: true,
        elevation: 1,
      ),
      body: BlocConsumer<ChatBloc, ChatState>(
        listenWhen: (previous, current) {
          if (previous.errorMessage != current.errorMessage) return true;

          if (previous.messages.length != current.messages.length) return true;

          if (previous.activeJobs.length != current.activeJobs.length)
            return true;

          if (previous.messages.isNotEmpty && current.messages.isNotEmpty) {
            final prevLast = previous.messages.last;
            final currLast = current.messages.last;
            if (prevLast.contentType != currLast.contentType) return true;
          }
          return false;
        },
        listener: (context, state) {
          _scrollToBottom();

          if (state.errorMessage != null) {
            // Clear any existing snackbars first
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
                margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                action: SnackBarAction(
                  label: 'Dismiss',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          // Scroll to bottom on first build with restored messages
          if (state.messages.isNotEmpty && !_hasScrolledOnInit) {
            _scrollToBottomOnInit();
          }

          return Column(
            children: [
              if (state.waitingMessage != null)
                _buildStatusBanner(context, state.waitingMessage!),
              Expanded(
                child: state.messages.isEmpty
                    ? _buildEmptyState(context)
                    : _buildMessageList(state),
              ),
              MessageInput(
                isLoading: state.isLoading,
                onSend: (message) {
                  context.read<ChatBloc>().add(SendMessageEvent(message));
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 50),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        return ChatBubble(message: state.messages[index]);
      },
    );
  }
}
