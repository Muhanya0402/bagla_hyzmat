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

  // Level up pending — показываем анимацию
  XpHistory? _pendingLevelUp;

  List<LevelDefinition> get allLevels => _allLevels;
  LevelDefinition? get currentLevel => _currentLevel;
  LevelDefinition? get nextLevel => _nextLevel;
  int get currentXp => _currentXp;
  bool get isLoading => _isLoading;
  XpHistory? get pendingLevelUp => _pendingLevelUp;

  /// XP прогресс от 0.0 до 1.0 в текущем уровне
  double get progressInLevel {
    if (_currentLevel == null) return 0.0;
    if (_nextLevel == null) return 1.0; // максимальный уровень

    final currentLevelXp = _currentLevel!.xpRequired;
    final nextLevelXp = _nextLevel!.xpRequired;
    final range = nextLevelXp - currentLevelXp;
    if (range <= 0) return 1.0;

    final earned = _currentXp - currentLevelXp;
    return (earned / range).clamp(0.0, 1.0);
  }

  /// XP до следующего уровня
  int get xpToNextLevel {
    if (_nextLevel == null) return 0;
    return (_nextLevel!.xpRequired - _currentXp).clamp(0, 999999);
  }

  /// Загрузить всё для пользователя
  Future<void> loadForUser(String customerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Загружаем уровни и данные пользователя параллельно
      final results = await Future.wait([
        _repo.getLevels(),
        _repo.getCustomerLevel(customerId),
      ]);

      _allLevels = results[0] as List<LevelDefinition>;
      final customerData = results[1] as Map<String, dynamic>?;

      if (customerData != null) {
        _currentXp = customerData['experience_points'] ?? 0;

        // Текущий уровень из вложенного объекта
        final levelData = customerData['current_level_id'];
        if (levelData is Map) {
          final levelId = levelData['id'];
          _currentLevel = _allLevels.firstWhere(
            (l) => l.id == levelId,
            orElse: () =>
                _allLevels.isNotEmpty ? _allLevels.first : _dummyLevel(),
          );
        } else if (_allLevels.isNotEmpty) {
          _currentLevel = _allLevels.first;
        }

        // Следующий уровень
        if (_currentLevel != null) {
          final currentIdx = _allLevels.indexWhere(
            (l) => l.id == _currentLevel!.id,
          );
          if (currentIdx >= 0 && currentIdx < _allLevels.length - 1) {
            _nextLevel = _allLevels[currentIdx + 1];
          } else {
            _nextLevel = null; // максимальный уровень
          }
        }
      }

      // Проверяем pending level up
      await checkPendingLevelUp(customerId);
    } catch (e) {
      debugPrint("Ошибка загрузки уровня: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkPendingLevelUp(String customerId) async {
    _pendingLevelUp = await _repo.getPendingLevelUp(customerId);
    if (_pendingLevelUp != null) notifyListeners();
  }

  Future<void> dismissLevelUp(int xpHistoryId) async {
    await _repo.markLevelUpShown(xpHistoryId);
    _pendingLevelUp = null;
    notifyListeners();
  }

  Future<List<XpHistory>> getHistory(String customerId) {
    return _repo.getXpHistory(customerId);
  }

  LevelDefinition _dummyLevel() => LevelDefinition(
    id: 1,
    levelNumber: 1,
    titleRu: 'Новичок',
    titleTk: 'Täze başlan',
    icon: '🌱',
    xpRequired: 0,
    colorHex: '#9AA3AF',
    descriptionRu: '',
    descriptionTk: '',
    bonuses: [],
  );
}
