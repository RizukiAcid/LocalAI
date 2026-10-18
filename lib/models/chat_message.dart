/// Represents the role of the message sender in the conversation.
enum MessageRole {
  user,
  assistant,
  system,
}

/// Domain entity representing a single chat message in LocalAI.
class ChatMessage {
  final String id;
  final MessageRole role;
  final String rawContent;
  final String content;
  final String thinking;
  final bool isGenerating;
  final bool isError;
  final DateTime timestamp;
  final bool showThinking;

  const ChatMessage({
    required this.id,
    required this.role,
    this.rawContent = '',
    this.content = '',
    this.thinking = '',
    this.isGenerating = false,
    this.isError = false,
    required this.timestamp,
    this.showThinking = false,
  });

  /// Factory to create a user message.
  factory ChatMessage.user({
    required String id,
    required String content,
  }) {
    return ChatMessage(
      id: id,
      role: MessageRole.user,
      rawContent: content,
      content: content,
      thinking: '',
      isGenerating: false,
      timestamp: DateTime.now(),
    );
  }

  /// Factory to create an initial assistant response placeholder.
  factory ChatMessage.assistant({
    required String id,
    bool isGenerating = true,
  }) {
    return ChatMessage(
      id: id,
      role: MessageRole.assistant,
      rawContent: '',
      content: '',
      thinking: '',
      isGenerating: isGenerating,
      timestamp: DateTime.now(),
    );
  }

  /// Factory to create a system or error notification message.
  factory ChatMessage.system({
    required String id,
    required String content,
    bool isError = false,
  }) {
    return ChatMessage(
      id: id,
      role: MessageRole.system,
      rawContent: content,
      content: content,
      thinking: '',
      isGenerating: false,
      isError: isError,
      timestamp: DateTime.now(),
    );
  }

  /// Parses raw streamed tokens and isolates Qwen3 `<think>` chain-of-thought.
  ChatMessage updateWithRawText(String newRawText, {bool isGenerating = true}) {
    final parsed = parseThinkingAndContent(newRawText);

    return copyWith(
      rawContent: newRawText,
      content: parsed.content,
      thinking: parsed.thinking,
      isGenerating: isGenerating,
    );
  }

  /// Parses raw text to extract thinking tokens (`<think>` ... `</think>`).
  static ({String thinking, String content}) parseThinkingAndContent(String raw) {
    const thinkStart = '<think>';
    const thinkEnd = '</think>';

    final startIndex = raw.indexOf(thinkStart);
    if (startIndex == -1) {
      // No thinking tags found
      return (thinking: '', content: raw);
    }

    final endIndex = raw.indexOf(thinkEnd, startIndex + thinkStart.length);
    if (endIndex != -1) {
      // Both <think> and </think> exist
      final thinking = raw
          .substring(startIndex + thinkStart.length, endIndex)
          .trim();
      final beforeThink = raw.substring(0, startIndex).trim();
      final afterThink = raw.substring(endIndex + thinkEnd.length).trimLeft();

      final fullContent = beforeThink.isEmpty
          ? afterThink
          : (afterThink.isEmpty ? beforeThink : '$beforeThink\n$afterThink');

      return (thinking: thinking, content: fullContent);
    } else {
      // Still in thinking mode
      final thinking = raw.substring(startIndex + thinkStart.length).trim();
      final beforeThink = raw.substring(0, startIndex).trim();

      return (thinking: thinking, content: beforeThink);
    }
  }

  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    String? rawContent,
    String? content,
    String? thinking,
    bool? isGenerating,
    bool? isError,
    DateTime? timestamp,
    bool? showThinking,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      rawContent: rawContent ?? this.rawContent,
      content: content ?? this.content,
      thinking: thinking ?? this.thinking,
      isGenerating: isGenerating ?? this.isGenerating,
      isError: isError ?? this.isError,
      timestamp: timestamp ?? this.timestamp,
      showThinking: showThinking ?? this.showThinking,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          role == other.role &&
          rawContent == other.rawContent &&
          isGenerating == other.isGenerating &&
          isError == other.isError &&
          showThinking == other.showThinking;

  @override
  int get hashCode =>
      id.hashCode ^
      role.hashCode ^
      rawContent.hashCode ^
      isGenerating.hashCode ^
      isError.hashCode ^
      showThinking.hashCode;
}
