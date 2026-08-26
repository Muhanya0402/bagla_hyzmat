class District {
  final String id; // Используем String для универсальности с Directus
  final String tk;
  final String ru;

  /// Этрап, к которому относится район.
  ///
  /// Раньше не хранился: создание заказа спрашивало этрап отдельным шагом.
  /// Теперь шага нет — этрап определяется выбранным районом, поэтому едет
  /// вместе с ним. Пустые значения означают, что связь не разворачивали.
  final String etrapId;
  final String etrapRu;
  final String etrapTk;

  District({
    required this.id,
    required this.tk,
    required this.ru,
    this.etrapId = '',
    this.etrapRu = '',
    this.etrapTk = '',
  });

  factory District.fromJson(Map<String, dynamic> json) {
    // `etrap` приходит либо развёрнутым объектом, либо просто идентификатором
    // — зависит от того, какие поля запросили.
    final e = json['etrap'];
    final Map<String, dynamic> etrap = e is Map
        ? Map<String, dynamic>.from(e)
        : const {};
    return District(
      // .toString() защитит от ошибки, если придет число вместо строки
      id: json['id']?.toString() ?? '',
      tk: json['district_tk'] ?? '',
      ru: json['district_ru'] ?? '',
      etrapId: (etrap['id'] ?? (e is Map ? null : e))?.toString() ?? '',
      etrapRu: (etrap['etrap_ru'] ?? '').toString(),
      etrapTk: (etrap['etrap_tk'] ?? '').toString(),
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
