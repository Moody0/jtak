class CategoryModel {
  final int id;
  final String title;
  final String? icon;
  final int? parentId;
  final bool active;
  final int order;

  const CategoryModel({
    required this.id,
    required this.title,
    this.icon,
    this.parentId,
    this.active = true,
    this.order = 0,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id']?.toInt() ?? 0,
      title: map['title'] ?? '',
      icon: map['icon'],
      parentId: map['parentId']?.toInt(),
      active: map['active'] ?? true,
      order: map['order']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'icon': icon,
      'parentId': parentId,
      'active': active,
      'order': order,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
