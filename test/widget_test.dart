import 'package:flutter_test/flutter_test.dart';
import 'package:localai/models/chat_message.dart';

void main() {
  test('ChatMessage correctly isolates Qwen3 thinking tokens', () {
    const raw = '<think>\nAnalyzing the question carefully.\n</think>\nHere is the final answer.';
    final parsed = ChatMessage.parseThinkingAndContent(raw);

    expect(parsed.thinking, 'Analyzing the question carefully.');
    expect(parsed.content, 'Here is the final answer.');
  });

  test('ChatMessage handles incomplete thinking tokens during streaming', () {
    const raw = '<think>\nStill reasoning through steps...';
    final parsed = ChatMessage.parseThinkingAndContent(raw);

    expect(parsed.thinking, 'Still reasoning through steps...');
    expect(parsed.content, '');
  });

  test('ChatMessage handles response without thinking tokens', () {
    const raw = 'Direct answer to the user query.';
    final parsed = ChatMessage.parseThinkingAndContent(raw);

    expect(parsed.thinking, '');
    expect(parsed.content, 'Direct answer to the user query.');
  });
}
