
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/utils/multi_size_parser.dart';

void main() {
  group('MultiSizeParser Unit Tests', () {
    test('Detects multi-size in parentheses', () {
      final res = MultiSizeParser.parseMultiSizeTokens('BODY- OLLYPOP COLLECTION LABLE(M,L,XL,XXL)');
      expect(res.isMultiSize, isTrue);
      expect(res.sizes, ['M', 'L', 'XL', 'XXL']);
      expect(res.cleanName, 'BODY- OLLYPOP COLLECTION LABLE');
    });

    test('Detects XS,S in parentheses', () {
      final res = MultiSizeParser.parseMultiSizeTokens('BODY- OLLYPOP COLLECTION LABLE(XS,S)');
      expect(res.isMultiSize, isTrue);
      expect(res.sizes, ['XS', 'S']);
    });

    test('Detects numeric comma separated sizes at end', () {
      final res = MultiSizeParser.parseMultiSizeTokens('BODY- OLLYOP COLLECTION LABLE 22,24,26');
      expect(res.isMultiSize, isTrue);
      expect(res.sizes, ['22', '24', '26']);
      expect(res.cleanName, 'BODY- OLLYOP COLLECTION LABLE');
    });

    test('Expands numeric range with step 2', () {
      final res = MultiSizeParser.parseMultiSizeTokens('PANT ELASTIC (28-34)');
      expect(res.isMultiSize, isTrue);
      expect(res.sizes, ['28', '30', '32', '34']);
    });

    test('Enterprise MES scenario: 2,350 inward with 2,232 target yields 118 buffer', () {
      final calc = MultiSizeParser.calculateSizeBreakdown(2350, ['S', 'M', 'L', 'XL'], 2232);
      expect(calc.baseQty, 2232);
      expect(calc.bufferQty, 118);
      expect(calc.sizeBreakdown.length, 4);
      expect(calc.sizeBreakdown[0].qty, 558);
    });

    test('Uneven quantity without target retains remainder in buffer', () {
      final calc = MultiSizeParser.calculateSizeBreakdown(1003, ['22', '24', '26', '28']);
      expect(calc.baseQty, 1000);
      expect(calc.bufferQty, 3);
      expect(calc.sizeBreakdown[0].qty, 250);
    });

    test('Single type standard item returns isMultiSize false', () {
      final res = MultiSizeParser.parseMultiSizeTokens('NAVY BLUE SEWING THREAD CONE', 'CONE');
      expect(res.isMultiSize, isFalse);
      expect(res.cleanName, 'NAVY BLUE SEWING THREAD CONE');
    });
  });
}
