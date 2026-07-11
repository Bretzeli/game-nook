import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app.dart';

void main() {
  testWidgets('Home page shows game cards', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GameNookApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Pick a game'), findsOneWidget);
    expect(find.text('Wordle'), findsOneWidget);
    expect(find.text('Sudoku'), findsOneWidget);
  });
}
