import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../storage/token_storage_service.dart';

// Provider for FlutterSecureStorage instance
final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  // 可以添加 Android/iOS 的特定选项，如果需要
  // AndroidOptions _getAndroidOptions() => const AndroidOptions(encryptedSharedPreferences: true);
  // IOSOptions _getIOSOptions() => const IOSOptions(accountName: ...);
  return const FlutterSecureStorage(/*aOptions: _getAndroidOptions()*/);
});

// Provider for TokenStorageService
final tokenStorageProvider = Provider<TokenStorageService>((ref) {
  final storage = ref.watch(flutterSecureStorageProvider);
  return TokenStorageService(storage);
});