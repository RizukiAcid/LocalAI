import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localai/widgets/formatted_text.dart';

void main() {
  const regular = TextStyle(color: Colors.white, fontWeight: FontWeight.normal);
  const bold = TextStyle(color: Colors.white, fontWeight: FontWeight.bold);

  group('Asterisk Bold (**word/sentence**) tests', () {
    test('Single bold word between double asterisks', () {
      const input = 'Hello **LocalAI** world';
      final spans = parseFormattedSpans(input, regularStyle: regular, boldStyle: bold);

      expect(spans.length, 3);
      expect(spans[0].text, 'Hello ');
      expect(spans[0].style!.fontWeight, FontWeight.normal);
      expect(spans[1].text, 'LocalAI');
      expect(spans[1].style!.fontWeight, FontWeight.bold);
      expect(spans[2].text, ' world');
      expect(spans[2].style!.fontWeight, FontWeight.normal);
    });

    test('Bold sentence between double asterisks at beginning and end', () {
      const input = '**This entire sentence is bold.** And this is normal.';
      final spans = parseFormattedSpans(input, regularStyle: regular, boldStyle: bold);

      expect(spans.length, 2);
      expect(spans[0].text, 'This entire sentence is bold.');
      expect(spans[0].style!.fontWeight, FontWeight.bold);
      expect(spans[1].text, ' And this is normal.');
      expect(spans[1].style!.fontWeight, FontWeight.normal);
    });

    test('Multiple bold sections in one text', () {
      const input = 'Specifically **superposition** and **entanglement** gates.';
      final spans = parseFormattedSpans(input, regularStyle: regular, boldStyle: bold);

      expect(spans.length, 5);
      expect(spans[0].text, 'Specifically ');
      expect(spans[1].text, 'superposition');
      expect(spans[1].style!.fontWeight, FontWeight.bold);
      expect(spans[2].text, ' and ');
      expect(spans[3].text, 'entanglement');
      expect(spans[3].style!.fontWeight, FontWeight.bold);
      expect(spans[4].text, ' gates.');
    });

    test('Incomplete double asterisks during streaming', () {
      const input = 'Analyzing **super';
      final spans = parseFormattedSpans(input, regularStyle: regular, boldStyle: bold);

      expect(spans.length, 1);
      expect(spans[0].text, 'Analyzing **super');
      expect(spans[0].style!.fontWeight, FontWeight.normal);
    });

    test('Single asterisks are not bolded', () {
      const input = '2 * 3 = 6';
      final spans = parseFormattedSpans(input, regularStyle: regular, boldStyle: bold);

      expect(spans.length, 1);
      expect(spans[0].text, '2 * 3 = 6');
      expect(spans[0].style!.fontWeight, FontWeight.normal);
    });

    test('Consecutive asterisks with no words are not bolded', () {
      const input = 'Empty **** asterisks';
      final spans = parseFormattedSpans(input, regularStyle: regular, boldStyle: bold);

      expect(spans.any((s) => s.style?.fontWeight == FontWeight.bold), isFalse);
    });

    test('Separates code blocks from text and parses bold outside code block', () {
      const input = 'Code example:\n```python\nprint(2 ** 3)\n```\nAnd **important note** here.';
      final blocks = parseMessageBlocks(input);

      expect(blocks.length, 3);
      expect(blocks[0], isA<TextBlock>());
      expect((blocks[0] as TextBlock).text, 'Code example:\n');

      expect(blocks[1], isA<CodeBlock>());
      expect((blocks[1] as CodeBlock).language, 'python');
      expect((blocks[1] as CodeBlock).code, 'print(2 ** 3)\n');

      expect(blocks[2], isA<TextBlock>());
      final text = (blocks[2] as TextBlock).text;
      final spans = parseFormattedSpans(text, regularStyle: regular, boldStyle: bold);
      expect(spans.any((s) => s.text == 'important note' && s.style!.fontWeight == FontWeight.bold), isTrue);
    });
  });

  group('FormattedMessageView Widget Tests', () {
    testWidgets('Renders bold text without displaying asterisks', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormattedMessageView(
              content: 'Hello **LocalAI** world',
              isUser: false,
            ),
          ),
        ),
      );

      // Verify the raw asterisks are not shown
      expect(find.text('Hello **LocalAI** world'), findsNothing);

      // Find the SelectableText.rich widget
      final selectableTextFinder = find.byType(SelectableText);
      expect(selectableTextFinder, findsOneWidget);

      final SelectableText selectableText = tester.widget(selectableTextFinder);
      final TextSpan textSpan = selectableText.textSpan!;
      final children = textSpan.children!;

      expect(children.length, 3);
      expect((children[0] as TextSpan).text, 'Hello ');
      expect((children[0] as TextSpan).style?.fontWeight, isNot(FontWeight.bold));

      expect((children[1] as TextSpan).text, 'LocalAI');
      expect((children[1] as TextSpan).style?.fontWeight, FontWeight.bold);

      expect((children[2] as TextSpan).text, ' world');
      expect((children[2] as TextSpan).style?.fontWeight, isNot(FontWeight.bold));
    });
  });
}
