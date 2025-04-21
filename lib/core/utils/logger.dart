// lib/core/utils/logger.dart
import 'package:logger/logger.dart';

// Configure and create a global logger instance
final logger = Logger(
  printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
  ),
  // level: Level.debug,
);