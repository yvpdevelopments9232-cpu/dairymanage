import "package:flutter_test/flutter_test.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:dairy_management/services/account_status_service.dart";
import "package:dairy_management/screens/account_pending_screen.dart";

void main() {
  testWidgets("AccountPendingScreen displays correct messages and contact details", (tester) async {
    bool reactivatedCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AccountPendingScreen(
            onReactivated: () {
              reactivatedCalled = true;
            },
          ),
        ),
      ),
    );

    // Verify key titles and messages
    expect(find.text("ACCOUNT PENDING"), findsOneWidget);
    expect(find.text("Your application account is currently pending."), findsOneWidget);
    expect(find.text("Please contact Yu_Vi Development to activate your account."), findsOneWidget);
    expect(find.text("Yu_Vi Development"), findsOneWidget);
    expect(find.text("Mobile: 6361782144"), findsOneWidget);

    // Verify Action Buttons
    expect(find.text("Contact Yu_Vi Development"), findsOneWidget);
    expect(find.text("Check Again / Retry"), findsOneWidget);
    expect(find.text("Log Out"), findsOneWidget);
  });
}
