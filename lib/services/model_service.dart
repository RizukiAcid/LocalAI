export 'model_service_interface.dart';
import 'model_service_interface.dart';

import 'model_service_stub.dart'
    if (dart.library.io) 'model_service_native.dart'
    if (dart.library.html) 'model_service_web.dart';

/// Factory returning the platform-appropriate ModelService instance:
/// - Native (Android, Windows, macOS, Linux, iOS): Native llama_cpp_dart FFI engine
/// - Web: Sandboxed offline simulation engine
ModelService createModelService() => getPlatformModelService();
