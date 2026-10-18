import 'dart:convert';

import 'package:djym/domain/ai_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storageKey = 'ai_settings';

/// Kept in the Android Keystore or iOS Keychain rather than the database, so
/// API keys never end up in backups or move to another device.
class AiSettingsNotifier extends AsyncNotifier<AiSettings?> {
  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  @override
  Future<AiSettings?> build() async {
    final stored = await _storage.read(key: _storageKey);
    if (stored == null) return null;
    return AiSettings.fromJson(jsonDecode(stored) as Map<String, dynamic>);
  }

  Future<void> save(AiSettings settings) async {
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(settings.toJson()),
    );
    state = AsyncData(settings);
  }

  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
    state = const AsyncData(null);
  }
}

final aiSettingsProvider =
    AsyncNotifierProvider<AiSettingsNotifier, AiSettings?>(
      AiSettingsNotifier.new,
    );
