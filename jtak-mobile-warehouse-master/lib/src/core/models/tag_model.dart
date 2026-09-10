import 'dart:convert';

class TagModel {
  int? id;
  String? name;
  String? photo;
  TagModel({
    this.id,
    this.name,
    this.photo,
  });

  TagModel copyWith({
    int? id,
    String? name,
    String? photo,
  }) {
    return TagModel(
      id: id ?? this.id,
      name: name ?? this.name,
      photo: photo ?? this.photo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'photo': photo,
    };
  }

  factory TagModel.fromMap(Map<String, dynamic> map) {
    return TagModel(
      id: map['id'],
      name: map['name'],
      photo: map['photo'],
    );
  }

  String toJson() => json.encode(toMap());

  factory TagModel.fromJson(String source) => TagModel.fromMap(json.decode(source));

  @override
  String toString() => 'Tag(id: $id, name: $name, photo: $photo)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TagModel && other.id == id && other.name == name && other.photo == photo;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ photo.hashCode;
}
