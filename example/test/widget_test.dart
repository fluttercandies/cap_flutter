import 'package:cap_flutter/cap_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CapWidget renders checkbox and label in idle state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CapWidget(
            apiEndpoint: 'https://cap.example.com/abc123/',
            i18n: CapI18n(initialState: '验证你是人类'),
          ),
        ),
      ),
    );

    expect(find.text('验证你是人类'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('CapWidget applies theme dimensions and colors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CapWidget(
            apiEndpoint: 'https://cap.example.com/abc123/',
            theme: CapTheme(
              widgetWidth: 300,
              widgetHeight: 64,
              backgroundColor: Color(0xFF123456),
            ),
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(CapWidget),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(container.constraints?.maxWidth, 300);
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF123456));
  });
}
