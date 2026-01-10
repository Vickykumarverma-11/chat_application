import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import 'package:assignment_project/main.dart';

// Mock storage for testing
class MockStorage implements Storage {
  final Map<String, String> _storage = {};

  @override
  String? read(String key) => _storage[key];

  @override
  Future<void> write(String key, dynamic value) async {
    _storage[key] = value.toString();
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() {
    HydratedBloc.storage = MockStorage();
  });

  testWidgets('Chat screen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatApp());
    await tester.pumpAndSettle();

    expect(find.text('Chat Assistant'), findsOneWidget);
    expect(find.text('Start a conversation'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
