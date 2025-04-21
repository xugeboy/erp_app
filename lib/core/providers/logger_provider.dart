import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final loggerProvider = Provider<Logger>((ref) {
  // 在这里配置你的 Logger 实例
  return Logger(
    printer: PrettyPrinter( /* ... 选项 ... */),
    // level: Level.info, // 例如，生产环境可以设置为 info
  );
});