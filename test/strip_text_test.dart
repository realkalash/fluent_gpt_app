import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stripText functionality', () {
    test('should strip all markdown syntax', () {
      String text =
          'Next will be markdown: *italic* [link](http://example.com) *giggles*';
      bool stripText = true;

      if (stripText) {
        text = text
            .replaceAll(RegExp(r'\*giggles\*'), ', hehe,')
            .replaceAll(RegExp(r'\*(.*?)\*'), '')
            .replaceAll(RegExp(r'\[(.*?)\]\((.*?)\)'), '.Link.')
            .replaceAll('  ', ' ');
      }

      expect(text, 'Next will be markdown: .Link. hehe');
    });
  });
}
