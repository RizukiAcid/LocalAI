import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/chat_screen.dart';
import 'services/model_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style for immersive edge-to-edge dark appearance
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1E293B),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final modelService = createModelService();

  runApp(LocalAIApp(modelService: modelService));
}

class LocalAIApp extends StatelessWidget {
  final ModelService modelService;

  const LocalAIApp({
    super.key,
    required this.modelService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LocalAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          onPrimary: Colors.white,
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF1E293B),
          error: Color(0xFFEF4444),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: ChatScreen(modelService: modelService),
    );
  }
}
