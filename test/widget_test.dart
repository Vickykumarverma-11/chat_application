import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assignment_project/main.dart';

void main() {
  testWidgets('Chat screen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatApp());

    expect(find.text('Chat Assistant'), findsOneWidget);
    expect(find.text('Start a conversation'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
