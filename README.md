# Chat Assistant App

A Flutter application (Android + Web) that simulates an AI chat assistant with support for text responses, image generation, and data processing - all using a mock API with polling mechanisms.

**Supported Platforms:** Android, Web (same codebase)

## Setup Instructions

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Android Studio / VS Code with Flutter extensions
- Chrome browser (for web)
- Android emulator or physical device (for mobile)

### Installation

```bash
# Clone or navigate to the project directory
cd assignment_project

# Install dependencies
flutter pub get
```

### Running on Android
```bash
flutter run -d android
```

### Running on Web
```bash
# Development
flutter run -d chrome

# Build for production
flutter build web --release

# The build output is in build/web/
# Serve it with any static file server:
cd build/web && python3 -m http.server 8080
```

### Build Both Platforms
```bash
# Android APK
flutter build apk --release

# Web
flutter build web --release
```

## Project Architecture

```
lib/
├── main.dart                 # App entry point, MaterialApp setup
├── core/
│   ├── constants.dart        # App constants, enums (ChatResponseType, JobStatus)
│   └── dio_client.dart       # Dio instance with mock API interceptor
├── models/
│   ├── chat_message.dart     # ChatMessage model with Equatable
│   └── api_response.dart     # ApiResponse, PollResponse models
├── services/
│   └── chat_api_service.dart # API service layer for chat and polling
├── bloc/
│   ├── chat_bloc.dart        # Main BLoC with polling logic
│   ├── chat_event.dart       # Events: SendMessage, StartPolling, etc.
│   └── chat_state.dart       # State: messages, activeJobs, loading states
└── ui/
    ├── chat_screen.dart      # Main chat UI
    └── widgets/
        ├── chat_bubble.dart  # Message bubble widget
        └── message_input.dart # Text input with send button
```

## Why BLoC?

BLoC (Business Logic Component) was chosen for this project for several reasons:

### 1. Separation of Concerns
BLoC enforces a clear separation between UI and business logic. The UI simply dispatches events and reacts to state changes, while all complex logic (API calls, polling, state management) lives in the BLoC.

### 2. Testability
With events and states as plain Dart classes extending Equatable, unit testing becomes straightforward. You can test the BLoC in isolation by dispatching events and verifying the emitted states.

### 3. Predictable State Management
BLoC provides unidirectional data flow:
- User action → Event → BLoC → State → UI update

This makes debugging easier because you can trace any state back to its triggering event.

### 4. Handling Complex Async Operations
The polling mechanism benefits from BLoC's event-driven architecture. Internal events (`_PollTickEvent`) handle the polling loop while keeping the code organized and cancellation safe.

### 5. Scalability
Adding new features (like new response types or job types) only requires adding new events and handlers without touching existing code.

## Key Implementation Details

### Mock API
The app uses Dio interceptors to simulate API responses without a real backend:
- `POST /chat` - Returns random response types (text, image job, data job)
- `GET /poll/{jobId}` - Returns job status (pending/completed/failed)

Network failures and job failures are randomly simulated to test error handling.

### Polling Mechanism
- Polls every 2 seconds using `Timer`
- Maximum 15 attempts before timeout
- Automatically cancels when BLoC is closed
- Multiple jobs can run concurrently
- **Poll Recovery**: If the app restarts while jobs are pending, polling resumes automatically

### Error Handling
- Network failures display snackbar errors
- Job failures update the message with error details
- Users can continue sending messages while polling is active

## Features

- Text message responses
- Image generation with shimmer skeleton loading (ChatGPT-like UX)
- Data processing with formatted JSON display
- Real-time status banner for active jobs
- Multiple concurrent polling jobs supported
- **State persistence** - Chat history and pending jobs survive app restarts
- **Poll recovery** - Pending jobs automatically resume polling after app restart
- Light/Dark theme support
- Error handling with user feedback
- Cross-platform (Android + Web from same codebase)

## Known Limitations

1. **Mock API Only**: The app uses simulated responses. For production, replace the mock interceptor with actual API endpoints.

2. **Single Chat Session**: No support for multiple chat threads or conversation history.

3. **No Authentication**: The app doesn't implement user authentication.

4. **Network Images**: Generated images use placeholder URLs (picsum.photos). Real implementation would need actual image generation service integration.

5. **No Retry Mechanism**: Failed jobs don't automatically retry. User must send a new message.

6. **Mock Job State**: Since the mock API stores jobs in memory, restarted polls will fail with "Job not found" (expected with mock - real API would retain job state).

## Dependencies

- `flutter_bloc: ^8.1.6` - State management
- `hydrated_bloc: ^9.1.5` - Persistent state with automatic hydration
- `equatable: ^2.0.5` - Value equality for states and events
- `dio: ^5.4.0` - HTTP client with interceptor support
- `uuid: ^4.3.3` - Unique ID generation for messages
- `shimmer: ^3.0.0` - Skeleton loading animation for image generation
- `path_provider: ^2.1.2` - Platform-specific storage directories
