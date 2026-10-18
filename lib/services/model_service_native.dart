import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message.dart';
import 'model_service_interface.dart';

/// Native implementation of ModelService using llama_cpp_dart and background isolates.
class ModelServiceImplementation extends ModelService {
  static const String modelFileName = 'Qwen3-0.6B-Q8_0.gguf';
  static const String assetModelPath = 'assets/models/$modelFileName';

  ModelLifecycleState _state = ModelLifecycleState.uninitialized;
  double _extractionProgress = 0.0;
  String _statusMessage = 'Uninitialized';
  String? _errorMessage;

  LlamaParent? _llamaParent;
  StreamSubscription<String>? _streamSub;
  StreamSubscription<CompletionEvent>? _completionSub;

  bool _isDisposed = false;
  bool _isAborted = false;

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
  bool get isWebMode => false;

  @override
  Future<void> initialize() async {
    if (_state == ModelLifecycleState.ready || _state == ModelLifecycleState.loadingModel) {
      return;
    }

    _errorMessage = null;

    try {
      _updateState(
        ModelLifecycleState.extractingAsset,
        progress: 0.0,
        message: 'Locating model storage...',
      );

      final modelPath = await _ensureModelFileExtracted();

      _updateState(
        ModelLifecycleState.loadingModel,
        progress: 0.9,
        message: 'Loading Qwen3-0.6B into memory...',
      );

      await _bootLlamaIsolate(modelPath);

      _updateState(
        ModelLifecycleState.ready,
        progress: 1.0,
        message: 'Qwen3-0.6B Ready (Offline Native)',
      );
    } catch (e, stackTrace) {
      debugPrint('LocalAI Initialization Error: $e\n$stackTrace');
      _errorMessage = e.toString();
      _updateState(
        ModelLifecycleState.error,
        progress: 0.0,
        message: 'Failed to load model: $e',
      );
    }
  }

  /// Verifies if model exists in application documents directory, or streams/extracts it.
  Future<String> _ensureModelFileExtracted() async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    final targetPath = '${appDocsDir.path}/$modelFileName';
    final targetFile = File(targetPath);

    // Check if target file already exists and is non-empty (>10MB sanity check)
    if (await targetFile.exists()) {
      final length = await targetFile.length();
      if (length > 10 * 1024 * 1024) {
        debugPrint('Found existing model at $targetPath (Size: $length bytes)');
        return targetPath;
      }
    }

    // Check if direct local asset file exists on disk (desktop/local dev)
    final localAssetFile = File(assetModelPath);
    if (await localAssetFile.exists()) {
      final totalBytes = await localAssetFile.length();
      if (totalBytes > 10 * 1024 * 1024) {
        debugPrint('Extracting from local file path: $assetModelPath ($totalBytes bytes)');
        await _copyFileWithProgress(localAssetFile, targetFile, totalBytes);
        return targetPath;
      }
    }

    // Extract from Flutter asset bundle (Android/iOS packaged asset)
    debugPrint('Extracting from rootBundle: $assetModelPath');
    await _extractFromRootBundle(assetModelPath, targetFile);
    return targetPath;
  }

  /// Copies a local file with non-blocking progress updates.
  Future<void> _copyFileWithProgress(File source, File target, int totalBytes) async {
    final reader = source.openRead();
    final sink = target.openWrite();
    int transferred = 0;

    await for (final chunk in reader) {
      sink.add(chunk);
      transferred += chunk.length;
      final progress = (transferred / totalBytes).clamp(0.0, 1.0);
      final mbCopied = (transferred / (1024 * 1024)).toStringAsFixed(1);
      final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

      _updateState(
        ModelLifecycleState.extractingAsset,
        progress: progress,
        message: 'Extracting weights: ${(progress * 100).toStringAsFixed(0)}% ($mbCopied / $mbTotal MB)',
      );
      // Yield to event loop to keep UI rendering smoothly at 60/120 FPS
      await Future.delayed(Duration.zero);
    }

    await sink.flush();
    await sink.close();
  }

  /// Streams large asset from rootBundle into local app storage in chunks.
  Future<void> _extractFromRootBundle(String assetPath, File targetFile) async {
    final byteData = await rootBundle.load(assetPath);
    final totalBytes = byteData.lengthInBytes;
    final sink = targetFile.openWrite();

    const chunkSize = 256 * 1024; // 256 KB per slice
    int offset = 0;

    try {
      while (offset < totalBytes) {
        final length = (offset + chunkSize > totalBytes) ? (totalBytes - offset) : chunkSize;
        final chunk = byteData.buffer.asUint8List(byteData.offsetInBytes + offset, length);
        sink.add(chunk);
        offset += length;

        final progress = (offset / totalBytes).clamp(0.0, 1.0);
        final mbCopied = (offset / (1024 * 1024)).toStringAsFixed(1);
        final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

        _updateState(
          ModelLifecycleState.extractingAsset,
          progress: progress,
          message: 'Extracting weights: ${(progress * 100).toStringAsFixed(0)}% ($mbCopied / $mbTotal MB)',
        );

        // Yield to event loop
        await Future.delayed(Duration.zero);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  /// Boots the background isolate and loads the GGUF model via llama_cpp_dart.
  Future<void> _bootLlamaIsolate(String modelPath) async {
    final modelParams = ModelParams()
      ..nGpuLayers = 0 // CPU-safe inference across all devices
      ..useMemorymap = true;

    final cpuCores = Platform.numberOfProcessors;
    final threads = cpuCores > 2 ? (cpuCores - 1).clamp(2, 6) : 2;

    final contextParams = ContextParams()
      ..nCtx = 2048
      ..nBatch = 512
      ..nThreads = threads
      ..flashAttention = LlamaFlashAttnType.disabled;

    // Optimal sampling parameters for Qwen3
    final samplingParams = SamplerParams()
      ..temp = 0.7
      ..topP = 0.8
      ..topK = 20
      ..penaltyPresent = 1.2;

    final loadCommand = LlamaLoad(
      path: modelPath,
      modelParams: modelParams,
      contextParams: contextParams,
      samplingParams: samplingParams,
    );

    _llamaParent = LlamaParent(loadCommand);
    await _llamaParent!.init();
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

    if (_llamaParent == null) {
      onError('Llama engine is not initialized.');
      _updateState(ModelLifecycleState.ready, message: 'Model Ready');
      return;
    }

    final prompt = formatChatMLPrompt(query: query, conversationHistory: history);

    await _streamSub?.cancel();
    await _completionSub?.cancel();

    final completer = Completer<void>();

    _streamSub = _llamaParent!.stream.listen(
      (token) {
        if (!_isAborted) {
          onToken(token);
        }
      },
      onError: (err) {
        if (!completer.isCompleted) {
          onError(err.toString());
          completer.complete();
        }
      },
    );

    _completionSub = _llamaParent!.completions.listen((event) {
      if (!completer.isCompleted) {
        if (event.success) {
          onComplete();
        } else {
          onError(event.errorDetails ?? 'Inference error');
        }
        completer.complete();
      }
    });

    try {
      await _llamaParent!.sendPrompt(prompt);
      await completer.future;
    } catch (e) {
      if (!_isAborted) {
        onError(e.toString());
      }
    } finally {
      await _streamSub?.cancel();
      await _completionSub?.cancel();
      _streamSub = null;
      _completionSub = null;
      _updateState(ModelLifecycleState.ready, message: 'Qwen3-0.6B Ready (Offline Native)');
    }
  }

  @override
  Future<void> abort() async {
    _isAborted = true;
    try {
      if (_llamaParent != null && _llamaParent!.isGenerating) {
        await _llamaParent!.stop();
      }
    } catch (e) {
      debugPrint('Error stopping generation: $e');
    } finally {
      _updateState(ModelLifecycleState.ready, message: 'Qwen3-0.6B Ready');
    }
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
    _streamSub?.cancel();
    _completionSub?.cancel();
    _llamaParent?.dispose();
    super.dispose();
  }
}

ModelService getPlatformModelService() => ModelServiceImplementation();
