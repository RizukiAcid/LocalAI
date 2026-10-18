import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../services/model_service.dart';

/// Main conversation screen providing modern chat UI, real-time streaming,
/// model status visualization, and chain-of-thought controls.
class ChatScreen extends StatefulWidget {
  final ModelService modelService;

  const ChatScreen({
    super.key,
    required this.modelService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final bool _isAutoScrollEnabled = true;

  @override
  void initState() {
    super.initState();
    widget.modelService.addListener(_onModelServiceUpdated);

    // Initial boot of model service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.modelService.initialize();
    });
  }

  @override
  void dispose() {
    widget.modelService.removeListener(_onModelServiceUpdated);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onModelServiceUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients || !_isAutoScrollEnabled) return;

    if (animated) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  Future<void> _handleSubmit(String text) async {
    final query = text.trim();
    if (query.isEmpty || !widget.modelService.isReady || widget.modelService.isGenerating) {
      return;
    }

    _textController.clear();

    final userMessage = ChatMessage.user(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: query,
    );

    final assistantMessageId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
    final assistantMessage = ChatMessage.assistant(
      id: assistantMessageId,
      isGenerating: true,
    );

    setState(() {
      _messages.add(userMessage);
      _messages.add(assistantMessage);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    StringBuffer accumulatedText = StringBuffer();

    await widget.modelService.generateResponse(
      query: query,
      history: _messages.sublist(0, _messages.length - 1),
      onToken: (token) {
        if (!mounted) return;
        accumulatedText.write(token);
        final raw = accumulatedText.toString();

        setState(() {
          final index = _messages.indexWhere((m) => m.id == assistantMessageId);
          if (index != -1) {
            _messages[index] = _messages[index].updateWithRawText(raw, isGenerating: true);
          }
        });

        _scrollToBottom();
      },
      onComplete: () {
        if (!mounted) return;
        setState(() {
          final index = _messages.indexWhere((m) => m.id == assistantMessageId);
          if (index != -1) {
            _messages[index] = _messages[index].updateWithRawText(
              accumulatedText.toString(),
              isGenerating: false,
            );
          }
        });
        _scrollToBottom();
      },
      onError: (errorMessage) {
        if (!mounted) return;
        setState(() {
          final index = _messages.indexWhere((m) => m.id == assistantMessageId);
          if (index != -1) {
            _messages[index] = ChatMessage.system(
              id: assistantMessageId,
              content: 'Error: $errorMessage',
              isError: true,
            );
          }
        });
      },
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Chat History', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to clear all conversation messages?',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
              });
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _toggleThinking(String messageId) {
    setState(() {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          showThinking: !_messages[index].showThinking,
        );
      }
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
        backgroundColor: const Color(0xFF334155),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGenerating = widget.modelService.isGenerating;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.85),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'LocalAI',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  widget.modelService.isWebMode
                      ? 'Qwen3-0.6B • Web Simulation'
                      : 'Qwen3-0.6B • Offline Native',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear Chat',
            icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8)),
            onPressed: _messages.isEmpty ? null : _clearChat,
          ),
          IconButton(
            tooltip: 'Model Info',
            icon: const Icon(Icons.info_outline, color: Color(0xFF94A3B8)),
            onPressed: () => _showInfoDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Visual banner indicating model status
          _buildStatusBanner(),

          // Chat message list or empty placeholder
          Expanded(
            child: _messages.isEmpty ? _buildEmptyState() : _buildMessageList(),
          ),

          // Input area
          _buildInputBar(isGenerating),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final state = widget.modelService.state;
    final progress = widget.modelService.extractionProgress;
    final message = widget.modelService.statusMessage;

    Color bannerColor;
    IconData bannerIcon;
    bool showProgress = false;

    switch (state) {
      case ModelLifecycleState.uninitialized:
        bannerColor = const Color(0xFF64748B);
        bannerIcon = Icons.hourglass_empty;
        break;
      case ModelLifecycleState.extractingAsset:
        bannerColor = const Color(0xFF3B82F6);
        bannerIcon = Icons.downloading;
        showProgress = true;
        break;
      case ModelLifecycleState.loadingModel:
        bannerColor = const Color(0xFFA855F7);
        bannerIcon = Icons.memory;
        showProgress = true;
        break;
      case ModelLifecycleState.ready:
        bannerColor = const Color(0xFF10B981);
        bannerIcon = Icons.check_circle_outline;
        break;
      case ModelLifecycleState.generating:
        bannerColor = const Color(0xFF6366F1);
        bannerIcon = Icons.auto_awesome;
        break;
      case ModelLifecycleState.error:
        bannerColor = const Color(0xFFEF4444);
        bannerIcon = Icons.error_outline;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        border: Border(
          bottom: BorderSide(
            color: bannerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(bannerIcon, size: 16, color: bannerColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: bannerColor,
                  ),
                ),
              ),
              if (state == ModelLifecycleState.error)
                TextButton(
                  onPressed: () => widget.modelService.initialize(),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 4,
                backgroundColor: const Color(0xFF334155),
                valueColor: AlwaysStoppedAnimation<Color>(bannerColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.2),
                    const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.hub,
                color: Color(0xFF818CF8),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'LocalAI On-Device Assistant',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Powered by Qwen3-0.6B (GGUF Q8_0)\nFully offline, private, and running locally.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Try asking:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildPromptChip('Explain quantum computing simply'),
            _buildPromptChip('Write a Python function to check palindromes'),
            _buildPromptChip('What are the advantages of on-device local AI?'),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChip(String prompt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          _textController.text = prompt;
          _handleSubmit(prompt);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155), width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF818CF8)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  prompt,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageItem(message);
      },
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    final isUser = message.role == MessageRole.user;
    final isSystem = message.role == MessageRole.system;

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: message.isError
                ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                : const Color(0xFF334155),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: message.isError
                  ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              fontSize: 12,
              color: message.isError ? const Color(0xFFFCA5A5) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 10, top: 4),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Thinking process accordion (Qwen3 Chain-of-Thought)
                if (!isUser && message.thinking.isNotEmpty) ...[
                  _buildThinkingAccordion(message),
                  const SizedBox(height: 6),
                ],

                // Primary response bubble
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser ? null : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: const Color(0xFF334155), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.content.isEmpty && message.isGenerating) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF818CF8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              message.thinking.isNotEmpty ? 'Thinking...' : 'Generating...',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        SelectableText(
                          message.content,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Message footer actions (timestamp & copy)
                if (!message.isGenerating && message.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _copyToClipboard(message.content),
                          child: const Icon(
                            Icons.copy,
                            size: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) ...[
            Container(
              margin: const EdgeInsets.only(left: 10, top: 4),
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF334155),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThinkingAccordion(ChatMessage message) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131C2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleThinking(message.id),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.psychology_alt, size: 14, color: Color(0xFF60A5FA)),
                  const SizedBox(width: 6),
                  Text(
                    message.isGenerating && message.content.isEmpty
                        ? 'Thinking in progress...'
                        : 'Thought process',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF60A5FA),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    message.showThinking ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 14,
                    color: const Color(0xFF60A5FA),
                  ),
                ],
              ),
            ),
          ),
          if (message.showThinking)
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 8, top: 2),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  message.thinking,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Color(0xFF94A3B8),
                    height: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isGenerating) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          border: Border(
            top: BorderSide(color: Color(0xFF334155), width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF334155), width: 1),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  enabled: !isGenerating,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (val) => _handleSubmit(val),
                  decoration: const InputDecoration(
                    hintText: 'Type a prompt for Qwen3...',
                    hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isGenerating)
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEF4444),
                ),
                child: IconButton(
                  tooltip: 'Stop Generation',
                  icon: const Icon(Icons.stop, color: Colors.white, size: 20),
                  onPressed: () => widget.modelService.abort(),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.modelService.isReady
                      ? const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        )
                      : null,
                  color: widget.modelService.isReady ? null : const Color(0xFF475569),
                ),
                child: IconButton(
                  tooltip: 'Send Prompt',
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  onPressed: widget.modelService.isReady
                      ? () => _handleSubmit(_textController.text)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.memory, color: Color(0xFF818CF8)),
            SizedBox(width: 8),
            Text('LocalAI Model Specs', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSpecRow('Model', 'Qwen3-0.6B (GGUF)'),
            _buildSpecRow('Quantization', 'Q8_0 (High Quality)'),
            _buildSpecRow('Context Window', '2,048 tokens'),
            _buildSpecRow('Prompt Template', 'ChatML'),
            _buildSpecRow('Sampling', 'temp: 0.7, top_p: 0.8, top_k: 20'),
            _buildSpecRow('Presence Penalty', '1.2'),
            _buildSpecRow('Execution', 'Isolated Background Worker (60 FPS)'),
            _buildSpecRow('Platform', widget.modelService.isWebMode ? 'Web Browser' : 'Android / Native'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
