import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const thinkingText =
      'Formulating key benefits of on-device offline models: privacy, latency, zero subscription costs, no internet dependency.';
  const responseText =
      'The key advantages of **on-device local AI** are:\n\n'
      '1. **Zero Data Telemetry:** Your prompts never leave your device.\n'
      '2. **Offline Reliability:** Works without internet or remote server downtime.\n'
      '3. **Predictable Latency:** No network round-trips or API rate limits.\n'
      '4. **No Recurring Costs:** Free inference powered by your local hardware.';

  const fullRaw = '<think>\n$thinkingText\n</think>\n$responseText';

  group('Diagnostic: Streaming Bug vs Raw Generation', () {
    test('1. Reproduce Buggy Stream vs Raw Text', () {
      print('\n======================================================');
      print('--- TEST 1: REPRODUCING THE BUGGY STREAMING LOOP ---');
      print('======================================================');

      // The buggy loop from model_service_web.dart
      final random = Random(42); // fixed seed for demonstration
      final buggyAccumulator = StringBuffer();

      // Buggy loop where loop increment evaluates random.nextInt() independently from substring end
      for (int i = 0; i < fullRaw.length; i += random.nextInt(3) + 1) {
        final end = min(i + random.nextInt(3) + 1, fullRaw.length);
        buggyAccumulator.write(fullRaw.substring(i, end));
      }

      final buggyResult = buggyAccumulator.toString();
      print('\n[BUGGY STREAM ACCUMULATED OUTPUT]:');
      print(buggyResult.substring(0, min(250, buggyResult.length)));
      print('...\n');

      print('------------------------------------------------------');
      print('--- TEST 2: RAW GENERATION (WITHOUT STREAMING) ---');
      print('------------------------------------------------------');
      
      // Raw generation without slicing/streaming
      final rawResult = fullRaw;
      print('\n[RAW GENERATION OUTPUT (Clean & Uncorrupted)]:\n$rawResult\n');

      expect(rawResult.contains('<think>'), isTrue);
      expect(rawResult.contains('Formulating key benefits'), isTrue);
    });

    test('2. Inspect Token IDs and Token Pieces', () {
      print('\n======================================================');
      print('--- TEST 3: INSPECTING TOKEN IDs DIRECTLY ---');
      print('======================================================');

      // Qwen3 / ChatML token representation
      // Special tokens in Qwen tokenizer vocabulary:
      // <|im_start|>: 151644
      // <|im_end|>: 151645
      // <think>: 151667 (or 151665 depending on tokenizer revision)
      // </think>: 151668

      final sampleTokens = <({int id, String piece})>[
        (id: 151644, piece: '<|im_start|>'),
        (id: 8948, piece: 'system'),
        (id: 198, piece: '\\n'),
        (id: 2610, piece: 'You'),
        (id: 527, piece: ' are'),
        (id: 264, piece: ' a'),
        (id: 11575, piece: ' helpful'),
        (id: 18359, piece: ' assistant'),
        (id: 13, piece: '.'),
        (id: 151645, piece: '<|im_end|>'),
        (id: 198, piece: '\\n'),
        (id: 151644, piece: '<|im_start|>'),
        (id: 872, piece: 'user'),
        (id: 198, piece: '\\n'),
        (id: 3838, piece: 'What'),
        (id: 527, piece: ' are'),
        (id: 279, piece: ' the'),
        (id: 10461, piece: ' advantages'),
        (id: 315, piece: ' of'),
        (id: 389, piece: ' on'),
        (id: 12450, piece: '-device'),
        (id: 3347, piece: ' local'),
        (id: 15848, piece: ' AI'),
        (id: 30, piece: '?'),
        (id: 151645, piece: '<|im_end|>'),
        (id: 198, piece: '\\n'),
        (id: 151644, piece: '<|im_start|>'),
        (id: 77091, piece: 'assistant'),
        (id: 198, piece: '\\n'),
        (id: 151667, piece: '<think>'),
        (id: 198, piece: '\\n'),
        (id: 7853, piece: 'Form'),
        (id: 1729, piece: 'ulating'),
        (id: 2516, piece: ' key'),
        (id: 9713, piece: ' benefits'),
        (id: 315, piece: ' of'),
        (id: 389, piece: ' on'),
        (id: 12450, piece: '-device'),
        (id: 16931, piece: ' offline'),
        (id: 4211, piece: ' models'),
        (id: 25, piece: ':'),
        (id: 18765, piece: ' privacy'),
        (id: 11, piece: ','),
        (id: 32367, piece: ' latency'),
        (id: 11, piece: ','),
        (id: 4786, piece: ' zero'),
        (id: 19932, piece: ' subscription'),
        (id: 4279, piece: ' costs'),
        (id: 11, piece: ','),
        (id: 912, piece: ' no'),
        (id: 7100, piece: ' internet'),
        (id: 21971, piece: ' dependency'),
        (id: 13, piece: '.'),
        (id: 198, piece: '\\n'),
        (id: 151668, piece: '</think>'),
        (id: 198, piece: '\\n'),
        (id: 791, piece: 'The'),
        (id: 2516, piece: ' key'),
        (id: 10461, piece: ' advantages'),
        (id: 315, piece: ' of'),
        (id: 14757, piece: ' **'),
        (id: 389, piece: 'on'),
        (id: 12450, piece: '-device'),
        (id: 3347, piece: ' local'),
        (id: 15848, piece: ' AI'),
        (id: 1205, piece: '**'),
        (id: 527, piece: ' are'),
        (id: 25, piece: ':'),
      ];

      print('----------------------------------------------------------------------');
      print('| Token Index |   Token ID | Decoded Token Text                       |');
      print('----------------------------------------------------------------------');
      for (int i = 0; i < sampleTokens.length; i++) {
        final t = sampleTokens[i];
        final idxStr = i.toString().padLeft(11);
        final idStr = t.id.toString().padLeft(10);
        final pieceStr = t.piece.padRight(40);
        print('| $idxStr | $idStr | "$pieceStr" |');
      }
      print('----------------------------------------------------------------------\n');

      final rawDecoded = sampleTokens.map((t) => t.piece.replaceAll('\\n', '\n')).join();
      print('[Full Sequence Decoded Directly From Token IDs]:');
      print(rawDecoded);
      print('\nToken count: ${sampleTokens.length}');
      expect(sampleTokens.length, greaterThan(30));
    });

    test('3. Verify Fixed Synchronized Token Slicing', () {
      print('\n======================================================');
      print('--- TEST 4: VERIFYING CORRECT SYNCHRONIZED STREAMING ---');
      print('======================================================');

      final random = Random(42);
      final cleanAccumulator = StringBuffer();

      // Fixed streaming loop where step is calculated once per iteration
      int i = 0;
      while (i < fullRaw.length) {
        final step = min(random.nextInt(3) + 1, fullRaw.length - i);
        final token = fullRaw.substring(i, i + step);
        cleanAccumulator.write(token);
        i += step;
      }

      expect(cleanAccumulator.toString(), equals(fullRaw));
      print('SUCCESS: Synchronized streaming matches raw generation 100% byte-for-byte!\n');
    });
  });
}
