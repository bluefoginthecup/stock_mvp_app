import 'package:flutter_test/flutter_test.dart';
import 'package:stockapp_mvp/src/db/app_database.dart';
import 'package:stockapp_mvp/src/models/quote.dart';
import 'package:stockapp_mvp/src/screens/quotes/quote_print_view.dart';

void main() {
  test('견적서는 유효기간과 견적 문구를 표시한다', () {
    expect(QuoteDocumentType.quote.title, '견적서');
    expect(QuoteDocumentType.quote.dateLabel, '견적일');
    expect(QuoteDocumentType.quote.statement, '아래와 같이 견적합니다.');
    expect(QuoteDocumentType.quote.showsValidity, isTrue);
  });

  test('납품서는 유효기간을 숨기고 납품 문구를 표시한다', () {
    expect(QuoteDocumentType.delivery.title, '납품서');
    expect(QuoteDocumentType.delivery.dateLabel, '납품일');
    expect(QuoteDocumentType.delivery.statement, '아래와 같이 납품합니다.');
    expect(QuoteDocumentType.delivery.showsValidity, isFalse);
  });

  test('거래명세서는 유효기간을 숨기고 계산 문구를 표시한다', () {
    expect(QuoteDocumentType.transactionStatement.title, '거래명세서');
    expect(QuoteDocumentType.transactionStatement.dateLabel, '납품일');
    expect(
      QuoteDocumentType.transactionStatement.statement,
      '아래와 같이 계산합니다.',
    );
    expect(QuoteDocumentType.transactionStatement.showsValidity, isFalse);
  });

  test('납품일은 견적 DB 데이터로 변환된다', () {
    final deliveryDate = DateTime(2026, 7, 31);
    final quote = Quote(
      id: 'quote-1',
      customerName: '거래처',
      quoteDate: DateTime(2026, 7, 22),
      deliveryDate: deliveryDate,
    );

    expect(quote.deliveryDate, deliveryDate);
    expect(
      quote.toCompanion().deliveryDate.value,
      deliveryDate.toIso8601String(),
    );
  });
}
