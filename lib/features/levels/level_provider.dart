import 'package:bagla/features/levels/level_definition.dart';
import 'package:bagla/features/levels/level_repository.dart';
import 'package:flutter/material.dart';

class LevelProvider extends ChangeNotifier {
  final LevelRepository _repo = LevelRepository();

  List<LevelDefinition> _allLevels = [];
  LevelDefinition? _currentLevel;
  LevelDefinition? _nextLevel;
  int _currentXp = 0;
  bool _isLoading = false;
  XpHistory? _pendingLevelUp;

  List<LevelDefinition> get allLevels => _allLevels;
  LevelDefinition? get currentLevel => _currentLevel;
  LevelDefinition? get nextLevel => _nextLevel;
  int get currentXp => _currentXp;
  bool get isLoading => _isLoading;
  XpHistory? get pendingLevelUp => _pendingLevelUp;

  // ─── Прогресс ──────────────────────────────────────────────────────────────

  double get progressInLevel {
    if (_currentLevel == null) return 0.0;
    if (_nextLevel == null) return 1.0;
    final range = _nextLevel!.xpRequired - _currentLevel!.xpRequired;
    if (range <= 0) return 1.0;
    final earned = _currentXp - _currentLevel!.xpRequired;
    return (earned / range).clamp(0.0, 1.0);
  }

  int get xpToNextLevel {
    if (_nextLevel == null) return 0;
    return (_nextLevel!.xpRequired - _currentXp).clamp(0, 999999);
  }

  // ─── Загрузка ──────────────────────────────────────────────────────────────

  Future<void> loadForUser(String customerId) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Загружаем уровни и данные курьера параллельно
      final results = await Future.wait([
        _repo.getLevels(),
        _repo.getCustomerLevel(customerId),
      ]);

      _allLevels = results[0] as List<LevelDefinition>;
      final customerData = results[1] as Map<String, dynamic>?;

      debugPrint('📊 LevelProvider: загружено ${_allLevels.length} уровней');
      debugPrint('📊 LevelProvider: данные курьера: $customerData');

      if (customerData != null) {
        _currentXp = customerData['experience_points'] ?? 0;
        debugPrint('📊 LevelProvider: currentXp = $_currentXp');

        // Парсим current_level_id — может прийти как Map (вложенный) или как ID
        final levelData = customerData['current_level_id'];

        if (levelData is Map) {
          // Directus вернул вложенный объект: { "id": 1, "level_number": 1, ... }
          final levelId = levelData['id'];
          _currentLevel = _allLevels.cast<LevelDefinition?>().firstWhere(
            (l) => l!.id == levelId,
            orElse: () => null,
          );
          debugPrint('📊 LevelProvider: уровень из объекта, id=$levelId');
        } else if (levelData != null) {
          // Пришёл просто ID
          final levelId = int.tryParse(levelData.toString());
          _currentLevel = _allLevels.cast<LevelDefinition?>().firstWhere(
            (l) => l!.id == levelId,
            orElse: () => null,
          );
          debugPrint('📊 LevelProvider: уровень из ID, id=$levelId');
        }

        // Если current_level_id не заполнен — берём первый уровень
        if (_currentLevel == null && _allLevels.isNotEmpty) {
          _currentLevel = _allLevels.first;
          debugPrint('📊 LevelProvider: уровень не найден → берём первый');
        }

        debugPrint(
          '📊 LevelProvider: currentLevel = ${_currentLevel?.titleRu}',
        );

        // Следующий уровень
        if (_currentLevel != null) {
          final idx = _allLevels.indexWhere((l) => l.id == _currentLevel!.id);
          _nextLevel = (idx >= 0 && idx < _allLevels.length - 1)
              ? _allLevels[idx + 1]
              : null;
        }
      } else {
        // Нет данных от сервера — берём первый уровень как дефолт
        _currentLevel = _allLevels.isNotEmpty ? _allLevels.first : null;
        _nextLevel = _allLevels.length > 1 ? _allLevels[1] : null;
        _currentXp = 0;
        debugPrint(
          '⚠️ LevelProvider: данные курьера не найдены, уровней: ${_allLevels.length}',
        );
      }

      // Проверяем pending level up
      await _checkPendingLevelUp(customerId);
    } catch (e, stack) {
      debugPrint('❌ LevelProvider ошибка: $e');
      debugPrint('❌ Stack: $stack');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _checkPendingLevelUp(String customerId) async {
    try {
      _pendingLevelUp = await _repo.getPendingLevelUp(customerId);
      debugPrint('📊 LevelProvider: pendingLevelUp = ${_pendingLevelUp?.id}');
    } catch (e) {
      debugPrint('⚠️ LevelProvider: ошибка проверки level up: $e');
      _pendingLevelUp = null;
    }
  }

  Future<void> dismissLevelUp(int xpHistoryId) async {
    await _repo.markLevelUpShown(xpHistoryId);
    _pendingLevelUp = null;
    notifyListeners();
  }

  Future<List<XpHistory>> getHistory(String customerId) {
    return _repo.getXpHistory(customerId);
  }

  /// Вызывается после завершения заказа курьером.
  /// Ждёт 2 сек чтобы Directus Flow успел отработать, затем обновляет данные.
  Future<void> refreshAfterOrderComplete(String customerId) async {
    debugPrint('🔄 LevelProvider: ждём Flow Directus (2 сек)...');
    await Future.delayed(const Duration(seconds: 2));
    _isLoading = false; // сбрасываем флаг чтобы loadForUser не пропустил
    await loadForUser(customerId);
  }
}
