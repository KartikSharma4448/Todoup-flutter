import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/src/auth_screens.dart';
import 'package:flutter_mobile/src/legal_support_screens.dart';

void main() {
  testWidgets('login screen renders sign in form', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('login screen validates invalid email', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.enterText(find.byType(TextFormField).first, 'invalid-email');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('sign up screen validates required fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));

    await tester.tap(find.text('Create Account').last);
    await tester.pump();

    expect(find.text('Name is required.'), findsOneWidget);
    expect(find.text('Email is required.'), findsOneWidget);
    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );
  });

  testWidgets('support screen renders contact details', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SupportScreen()));

    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Copy Support Email'), findsOneWidget);
    expect(find.text(SupportScreen.supportEmail), findsOneWidget);
  });
}
