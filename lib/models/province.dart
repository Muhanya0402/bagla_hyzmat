class Province {
  final String id;
  final String ru;
  final String tk;

  Province({required this.id, required this.ru, required this.tk});

  factory Province.fromJson(Map<String, dynamic> json) => Province(
    id: json['id']?.toString() ?? '',
    ru: json['province_ru'] ?? '',
    tk: json['province_tk'] ?? '',
  );

  String label(bool isRu) => isRu ? ru : tk;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Province && id == other.id;
  @override
  int get hashCode => id.hashCode;
}
