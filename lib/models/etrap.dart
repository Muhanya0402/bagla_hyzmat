class Etrap {
  final String id;
  final String ru;
  final String tk;
  final String provinceId;

  Etrap({
    required this.id,
    required this.ru,
    required this.tk,
    required this.provinceId,
  });

  factory Etrap.fromJson(Map<String, dynamic> json) => Etrap(
    id: json['id']?.toString() ?? '',
    ru: json['etrap_ru'] ?? '',
    tk: json['etrap_tk'] ?? '',
    provinceId: json['province']?.toString() ?? '',
  );

  String label(bool isRu) => isRu ? ru : tk;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Etrap && id == other.id;
  @override
  int get hashCode => id.hashCode;
}
