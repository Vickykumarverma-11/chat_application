# Chat Assistant App

This is a Flutter chat application that simulates an AI-style assistant.
The purpose of this project is to demonstrate how a modern chat app can handle
different response types such as text, image generation, and data processing,
including polling for long-running operations.

The backend is fully mocked so the focus remains on frontend architecture,
state management, and async behavior.

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run on Android
flutter run

# Run on Web
flutter run -d chrome

# Build for production
flutter build apk --release
flutter build web --release
```

## Architecture

The app follows a clean architecture pattern with BLoC for state management.

```
lib/
├── main.dart
├── core/
│   ├── constants.dart
│   └── dio_client.dart
├── models/
│   ├── chat_message.dart
│   └── api_response.dart
├── services/
│   └── chat_api_service.dart
├── bloc/
│   ├── chat_bloc.dart
│   ├── chat_event.dart
│   └── chat_state.dart
└── ui/
    ├── chat_screen.dart
    └── widgets/
        ├── chat_bubble.dart
        ├── message_input.dart
        ├── full_screen_image.dart
        └── typing_indicator.dart

```

## Design Decisions

**Why BLoC?**

I chose BLoC because it enforces a clear separation between UI and business logic. The polling mechanism especially benefits from the event-driven architecture - I can dispatch internal events for poll ticks while keeping everything organized. It also makes the app highly testable since all state changes flow through events.

**Mock API Approach**

Instead of setting up a separate backend, I used Dio interceptors to simulate API responses. This keeps everything self-contained and makes it easy to test different scenarios (network failures, job timeouts, etc.).

**State Persistence**

Used HydratedBloc to persist chat history and active jobs. If the app restarts while jobs are running, it automatically resumes polling - this handles the edge case of users leaving and returning to the app.

## Features

- Three response types: text, image generation, data processing
- Concurrent polling for multiple image jobs
- State persistence across app restarts
- Retry mechanism for failed messages
- Cancel ongoing operations
- Full-screen image viewer with zoom
- Copy text to clipboard (long press)
- Offline indicator
- Message timestamps

## Mock API Details

The mock API simulates realistic behavior:

- `POST /chat` - Returns response based on message intent (keywords like "image", "data" trigger respective types)
- `GET /poll/{jobId}` - Returns pending/completed/failed status

Jobs complete after 4-8 seconds with a 15% failure rate and 10% network error simulation.

## Known Limitations

1. Mock API only - replace interceptor with real endpoints for production
2. Image URLs use picsum.photos placeholders
3. Single chat session (no conversation threads)
4. Mock jobs are in-memory, so restarted polls will get "job not found" (expected behavior with mock)

## Dependencies

- flutter_bloc / hydrated_bloc - State management
- dio - HTTP client
- equatable - Value equality
- shimmer - Loading animations
- connectivity_plus - Network status
- uuid - Message IDs
