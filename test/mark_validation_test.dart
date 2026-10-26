import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rk_classes_app/screens/marks/marks_entry_screen.dart';

void main() {
  group('markProblem', () {
    test('empty is fine (not entered yet)', () => expect(markProblem('', 30), isNull));
    test('within range is fine', () {
      expect(markProblem('0', 30), isNull);
      expect(markProblem('17.5', 30), isNull);
      expect(markProblem('30', 30), isNull);
    });
    test('500 out of 30 is rejected', () => expect(markProblem('500', 30), 'Max 30'));
    test('just above the total is rejected', () => expect(markProblem('30.5', 30), 'Max 30'));
    test('not a number is rejected', () => expect(markProblem('.', 30), 'Not a number'));
  });

  group('marks input filter (digits, one dot, 2 decimals, max 3 digits)', () {
    final f = FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,2})?$'));
    String type(String old, String next) =>
        f.formatEditUpdate(TextEditingValue(text: old), TextEditingValue(text: next)).text;

    test('accepts normal marks', () {
      expect(type('', '2'), '2');
      expect(type('2', '28'), '28');
      expect(type('28', '28.'), '28.');
      expect(type('28.', '28.5'), '28.5');
      expect(type('28.5', '28.55'), '28.55');
    });
    test('blocks a 4th digit, a 3rd decimal, letters and minus', () {
      expect(type('500', '5000'), '500');
      expect(type('12.34', '12.345'), '12.34');
      expect(type('12', '12a'), '12');
      expect(type('', '-5'), '5');   // the minus sign is dropped, so a negative mark cannot be typed
    });
  });
}
