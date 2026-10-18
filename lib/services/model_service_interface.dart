import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';

/// States of the model lifecycle and extraction service.
enum ModelLifecycleState {
  uninitialized,
  extractingAsset,
  loadingModel,
  ready,
  generating,
  error,
}

/// Abstract contract for LocalAI model inference services.
abstract class ModelService extends ChangeNotifier {
  ModelLifecycleState get state;
  double get extractionProgress;
  String get statusMessage;
  String? get errorMessage;
  bool get isReady;
  bool get isGenerating;
  bool get isWebMode;

  /// Initializes the model, extracting assets and booting inference engine.
  Future<void> initialize();

  /// Formats ChatML prompt from conversation history.
  String formatChatMLPrompt({
    required String query,
    required List<ChatMessage> conversationHistory,
  });

  /// Sends a query and streams generated tokens back to the UI.
  Future<void> generateResponse({
    required String query,
    required List<ChatMessage> history,
    required void Function(String token) onToken,
    required void Function() onComplete,
    required void Function(String error) onError,
  });

  /// Aborts currently in-flight token generation.
  Future<void> abort();
}
