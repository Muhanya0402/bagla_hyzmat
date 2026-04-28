class District {
  final String id; // Используем String для универсальности с Directus
  final String tk;
  final String ru;

  District({required this.id, required this.tk, required this.ru});

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      // .toString() защитит от ошибки, если придет число вместо строки
      id: json['id']?.toString() ?? '',
      tk: json['district_tk'] ?? '',
      ru: json['district_ru'] ?? '',
    );
  }

  String label(bool isRu) => isRu ? ru : tk;

  // Переопределяем сравнение, чтобы DropdownSearch правильно подсвечивал выбранный элемент
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is District && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
