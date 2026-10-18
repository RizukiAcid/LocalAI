import 'dart:async';
import 'dart:math';
import '../models/chat_message.dart';
import 'model_service_interface.dart';

/// Web implementation of ModelService for browser environments.
/// Since browser sandboxes restrict raw C++ Dart FFI and physical file mmap,
/// this service provides an offline client-side simulated engine adhering to
/// Qwen3 ChatML token streaming and Chain-of-Thought parsing.
class ModelServiceImplementation extends ModelService {
  ModelLifecycleState _state = ModelLifecycleState.uninitialized;
  double _extractionProgress = 0.0;
  String _statusMessage = 'Uninitialized';
  String? _errorMessage;
  bool _isAborted = false;
  bool _isDisposed = false;

  @override
  ModelLifecycleState get state => _state;

  @override
  double get extractionProgress => _extractionProgress;

  @override
  String get statusMessage => _statusMessage;

  @override
  String? get errorMessage => _errorMessage;

  @override
  bool get isReady => _state == ModelLifecycleState.ready || _state == ModelLifecycleState.generating;

  @override
  bool get isGenerating => _state == ModelLifecycleState.generating;

  @override
  bool get isWebMode => true;

  @override
  Future<void> initialize() async {
    if (isReady) return;

    _updateState(
      ModelLifecycleState.loadingModel,
      progress: 0.5,
      message: 'Initializing LocalAI Web Environment...',
    );

    await Future.delayed(const Duration(milliseconds: 500));

    _updateState(
      ModelLifecycleState.ready,
      progress: 1.0,
      message: 'Qwen3-0.6B Ready (Web Browser Mode)',
    );
  }

  @override
  String formatChatMLPrompt({
    required String query,
    required List<ChatMessage> conversationHistory,
  }) {
    final buffer = StringBuffer();
    buffer.write('<|im_start|>system\nYou are a helpful assistant.<|im_end|>\n');

    for (final message in conversationHistory) {
      if (message.role == MessageRole.user) {
        buffer.write('<|im_start|>user\n${message.content}<|im_end|>\n');
      } else if (message.role == MessageRole.assistant && message.rawContent.isNotEmpty) {
        buffer.write('<|im_start|>assistant\n${message.rawContent}<|im_end|>\n');
      }
    }

    buffer.write('<|im_start|>user\n$query<|im_end|>\n<|im_start|>assistant\n');
    return buffer.toString();
  }

  @override
  Future<void> generateResponse({
    required String query,
    required List<ChatMessage> history,
    required void Function(String token) onToken,
    required void Function() onComplete,
    required void Function(String error) onError,
  }) async {
    if (!isReady) {
      onError('Model is not ready.');
      return;
    }

    _isAborted = false;
    _updateState(ModelLifecycleState.generating, message: 'Generating response...');

    final lower = query.toLowerCase();
    String thinkingText;
    String responseText;

    if (lower.contains('quantum')) {
      thinkingText = 'Analyzing user inquiry regarding quantum computing. Breaking down superposition, entanglement, and real-world qubit gates.';
      responseText = 'Quantum computing leverages quantum mechanical phenomena—specifically **superposition** and **entanglement**—to perform complex computations exponentially faster than classical computers for certain problem spaces.';
    } else if (lower.contains('python') || lower.contains('code') || lower.contains('palindrome')) {
      thinkingText = 'User requested Python code for checking palindromes. Writing clean, idiomatic Python code.';
      responseText = 'Here is a clean Python function to check for palindromes:\n\n```python\ndef is_palindrome(text: str) -> bool:\n    # Clean text to alphanumeric only\n    clean = "".join(ch.lower() for ch in text if ch.isalnum())\n    return clean == clean[::-1]\n\n# Test examples:\nprint(is_palindrome("Racecar"))  # True\nprint(is_palindrome("Hello"))    # False\n```';
    } else if (lower.contains('advantage') || lower.contains('offline') || lower.contains('local')) {
      thinkingText = 'Formulating key benefits of on-device offline models: privacy, latency, zero subscription costs, no internet dependency.';
      responseText = 'The key advantages of **on-device local AI** are:\n\n1. **Zero Data Telemetry:** Your prompts never leave your device.\n2. **Offline Reliability:** Works without internet or remote server downtime.\n3. **Predictable Latency:** No network round-trips or API rate limits.\n4. **No Recurring Costs:** Free inference powered by your local hardware.';
    } else {
      thinkingText = 'Processing query with Qwen3 ChatML formatting. Formulating helpful and concise reply.';
      responseText = 'Hello! I am **LocalAI**, powered by the offline Qwen3-0.6B model architecture. I operate entirely on your hardware without transmitting data to external cloud servers.\n\nHow can I assist you with your task today?';
    }

    final fullRaw = '<think>\n$thinkingText\n</think>\n$responseText';
    final random = Random();

    // Stream token by token with realistic latency
    for (int i = 0; i < fullRaw.length; i += random.nextInt(3) + 1) {
      if (_isAborted) break;
      final end = min(i + random.nextInt(3) + 1, fullRaw.length);
      onToken(fullRaw.substring(i, end));
      await Future.delayed(Duration(milliseconds: random.nextInt(15) + 8));
    }

    if (!_isAborted) {
      onComplete();
    }
    _updateState(ModelLifecycleState.ready, message: 'Qwen3-0.6B Ready (Web Browser Mode)');
  }

  @override
  Future<void> abort() async {
    _isAborted = true;
    _updateState(ModelLifecycleState.ready, message: 'Generation stopped.');
  }

  void _updateState(
    ModelLifecycleState newState, {
    double? progress,
    String? message,
  }) {
    if (_isDisposed) return;
    _state = newState;
    if (progress != null) _extractionProgress = progress;
    if (message != null) _statusMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

ModelService getPlatformModelService() => ModelServiceImplementation();
