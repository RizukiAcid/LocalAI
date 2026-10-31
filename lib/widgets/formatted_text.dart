import 'package:flutter/material.dart';

/// Represents a segmented block of a chat message: plain text or formatted code block.
sealed class MessageBlock {}

class TextBlock extends MessageBlock {
  final String text;
  TextBlock(this.text);
}

class CodeBlock extends MessageBlock {
  final String language;
  final String code;
  CodeBlock(this.language, this.code);
}

/// Splits message content into text blocks and code blocks (``` ... ```).
List<MessageBlock> parseMessageBlocks(String content) {
  final blocks = <MessageBlock>[];
  if (content.isEmpty) return blocks;

  final codeBlockRegex = RegExp(r'```([a-zA-Z0-9_-]*)\n?([\s\S]*?)```', dotAll: true);
  int currentIndex = 0;

  for (final match in codeBlockRegex.allMatches(content)) {
    if (match.start > currentIndex) {
      final textBefore = content.substring(currentIndex, match.start);
      if (textBefore.isNotEmpty) {
        blocks.add(TextBlock(textBefore));
      }
    }

    final language = match.group(1)?.trim() ?? '';
    final code = match.group(2) ?? '';
    blocks.add(CodeBlock(language, code));

    currentIndex = match.end;
  }

  if (currentIndex < content.length) {
    final remaining = content.substring(currentIndex);
    // Handle unclosed code block during active streaming
    final unclosedMatch = RegExp(r'^```([a-zA-Z0-9_-]*)\n?([\s\S]*)$').firstMatch(remaining);
    if (unclosedMatch != null && remaining.startsWith('```')) {
      final language = unclosedMatch.group(1)?.trim() ?? '';
      final code = unclosedMatch.group(2) ?? '';
      blocks.add(CodeBlock(language, code));
    } else {
      blocks.add(TextBlock(remaining));
    }
  }

  return blocks;
}

/// Parses a text segment into [TextSpan]s, replacing `**word/sentence**` with bold text
/// (removing the asterisk markers) and supporting inline code (`...`).
List<TextSpan> parseFormattedSpans(
  String text, {
  required TextStyle regularStyle,
  required TextStyle boldStyle,
  TextStyle? inlineCodeStyle,
}) {
  final spans = <TextSpan>[];
  if (text.isEmpty) return spans;

  final codeStyle = inlineCodeStyle ??
      regularStyle.copyWith(
        fontFamily: 'monospace',
        backgroundColor: const Color(0xFF0F172A),
        color: const Color(0xFF38BDF8),
      );

  // Pattern matches either:
  // 1. `inline code`
  // 2. **bold text or sentence**
  final pattern = RegExp(
    r'(`(?<inline>[^`\n]+)`)'
    r'|'
    r'(\*\*(?<bold>(?:(?!\n\s*\n).)+?)\*\*)',
    dotAll: true,
  );

  int currentIndex = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > currentIndex) {
      spans.add(TextSpan(
        text: text.substring(currentIndex, match.start),
        style: regularStyle,
      ));
    }

    final inlineCode = match.namedGroup('inline');
    final boldText = match.namedGroup('bold');

    if (inlineCode != null) {
      spans.add(TextSpan(
        text: inlineCode,
        style: codeStyle,
      ));
    } else if (boldText != null) {
      // If the content between ** is only whitespace, leave it as regular text
      if (boldText.trim().isEmpty) {
        spans.add(TextSpan(
          text: match.group(0),
          style: regularStyle,
        ));
      } else {
        spans.add(TextSpan(
          text: boldText,
          style: boldStyle,
        ));
      }
    }

    currentIndex = match.end;
  }

  if (currentIndex < text.length) {
    spans.add(TextSpan(
      text: text.substring(currentIndex),
      style: regularStyle,
    ));
  }

  return spans;
}

/// Renders message content with support for bold (`**word/sentence**`),
/// inline code, and formatted code blocks.
class FormattedMessageView extends StatelessWidget {
  final String content;
  final bool isUser;
  final void Function(String code)? onCopyCode;

  const FormattedMessageView({
    super.key,
    required this.content,
    required this.isUser,
    this.onCopyCode,
  });

  @override
  Widget build(BuildContext context) {
    final regularStyle = const TextStyle(
      fontSize: 14,
      color: Colors.white,
      height: 1.45,
    );

    final boldStyle = const TextStyle(
      fontSize: 14,
      color: Colors.white,
      fontWeight: FontWeight.bold,
      height: 1.45,
    );

    final inlineCodeStyle = TextStyle(
      fontSize: 13,
      fontFamily: 'monospace',
      color: isUser ? Colors.white : const Color(0xFF38BDF8),
      backgroundColor: isUser
          ? Colors.black.withValues(alpha: 0.2)
          : const Color(0xFF0F172A),
      height: 1.45,
    );

    // Fast path: if no code block markers, render directly as a single SelectableText.rich
    if (!content.contains('```')) {
      return SelectableText.rich(
        TextSpan(
          children: parseFormattedSpans(
            content,
            regularStyle: regularStyle,
            boldStyle: boldStyle,
            inlineCodeStyle: inlineCodeStyle,
          ),
        ),
        style: regularStyle,
      );
    }

    // Multi-block path for code blocks
    final blocks = parseMessageBlocks(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) {
        if (block is TextBlock) {
          if (block.text.trim().isEmpty) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SelectableText.rich(
              TextSpan(
                children: parseFormattedSpans(
                  block.text,
                  regularStyle: regularStyle,
                  boldStyle: boldStyle,
                  inlineCodeStyle: inlineCodeStyle,
                ),
              ),
              style: regularStyle,
            ),
          );
        } else if (block is CodeBlock) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF161F30),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        block.language.isNotEmpty ? block.language : 'code',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      if (onCopyCode != null)
                        InkWell(
                          onTap: () => onCopyCode!(block.code),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy, size: 12, color: Color(0xFF94A3B8)),
                                SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: SelectableText(
                    block.code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      color: Color(0xFFE2E8F0),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }
}
