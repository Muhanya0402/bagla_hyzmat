class LevelBonus {
  final String bonusType;
  final double valueNumber;
  final String valueText;
  final String labelRu;
  final String labelTk;
  final String icon;

  LevelBonus({
    required this.bonusType,
    required this.valueNumber,
    required this.valueText,
    required this.labelRu,
    required this.labelTk,
    required this.icon,
  });

  factory LevelBonus.fromJson(Map<String, dynamic> json) => LevelBonus(
    bonusType: json['bonus_type'] ?? '',
    valueNumber: (json['value_number'] ?? 0).toDouble(),
    valueText: json['value_text'] ?? '',
    labelRu: json['label_ru'] ?? '',
    labelTk: json['label_tk'] ?? '',
    icon: json['icon'] ?? '',
  );

  String label(bool isRu) => isRu ? labelRu : labelTk;
}

class LevelDefinition {
  final int id;
  final int levelNumber;
  final String titleRu;
  final String titleTk;
  final String icon;
  final int xpRequired;
  final String colorHex;
  final String descriptionRu;
  final String descriptionTk;
  final List<LevelBonus> bonuses;

  LevelDefinition({
    required this.id,
    required this.levelNumber,
    required this.titleRu,
    required this.titleTk,
    required this.icon,
    required this.xpRequired,
    required this.colorHex,
    required this.descriptionRu,
    required this.descriptionTk,
    required this.bonuses,
  });

  factory LevelDefinition.fromJson(Map<String, dynamic> json) {
    final rawBonuses = json['bonuses'] as List? ?? [];
    return LevelDefinition(
      id: json['id'] ?? 0,
      levelNumber: json['level_number'] ?? 0,
      titleRu: json['title_ru'] ?? '',
      titleTk: json['title_tk'] ?? '',
      icon: json['icon'] ?? '🌱',
      xpRequired: json['xp_required'] ?? 0,
      colorHex: json['color_hex'] ?? '#9AA3AF',
      descriptionRu: json['description_ru'] ?? '',
      descriptionTk: json['description_tk'] ?? '',
      bonuses: rawBonuses.map((b) => LevelBonus.fromJson(b)).toList(),
    );
  }

  String title(bool isRu) => isRu ? titleRu : titleTk;
  String description(bool isRu) => isRu ? descriptionRu : descriptionTk;
}

class XpHistory {
  final int id;
  final int xpAmount;
  final int xpBefore;
  final int xpAfter;
  final String sourceType;
  final int levelBefore;
  final int levelAfter;
  final bool didLevelUp;
  final String descriptionRu;
  final String descriptionTk;
  final DateTime dateCreated;

  XpHistory({
    required this.id,
    required this.xpAmount,
    required this.xpBefore,
    required this.xpAfter,
    required this.sourceType,
    required this.levelBefore,
    required this.levelAfter,
    required this.didLevelUp,
    required this.descriptionRu,
    required this.descriptionTk,
    required this.dateCreated,
  });

  factory XpHistory.fromJson(Map<String, dynamic> json) => XpHistory(
    id: json['id'] ?? 0,
    xpAmount: json['xp_amount'] ?? 0,
    xpBefore: json['xp_before'] ?? 0,
    xpAfter: json['xp_after'] ?? 0,
    sourceType: json['source_type'] ?? '',
    levelBefore: json['level_before'] ?? 0,
    levelAfter: json['level_after'] ?? 0,
    didLevelUp: json['did_level_up'] ?? false,
    descriptionRu: json['description_ru'] ?? '',
    descriptionTk: json['description_tk'] ?? '',
    dateCreated: json['date_created'] != null
        ? DateTime.tryParse(json['date_created']) ?? DateTime.now()
        : DateTime.now(),
  );

  String description(bool isRu) => isRu ? descriptionRu : descriptionTk;
}
