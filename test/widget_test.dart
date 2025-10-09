import 'package:flutter_test/flutter_test.dart';
import 'package:stockapp_mvp/src/app.dart';

void main() {
  testWidgets('앱이 대시보드를 렌더링한다', (WidgetTester tester) async {
    await tester.pumpWidget(const StockApp());
    // 대시보드 AppBar 타이틀 확인
    expect(find.text('대시보드'), findsOneWidget);
  });
}
