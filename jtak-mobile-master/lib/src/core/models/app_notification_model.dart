import 'dart:convert';

class AppNotificationModel {
  int? id;
  String? title;
  String? text;
  String? viewDate;
  String? createdDate;
  AppNotificationModel({
    this.id,
    this.title,
    this.text,
    this.viewDate,
    this.createdDate,
  });

  AppNotificationModel copyWith({
    int? id,
    String? title,
    String? text,
    String? viewDate,
    String? createdDate,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      text: text ?? this.text,
      viewDate: viewDate ?? this.viewDate,
      createdDate: createdDate ?? this.createdDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'text': text,
      'viewDate': viewDate,
      'createdDate': createdDate,
    };
  }

  factory AppNotificationModel.fromMap(Map<String, dynamic> map) {
    return AppNotificationModel(
      id: map['id']?.toInt(),
      title: map['title'],
      text: map['text'],
      viewDate: map['viewDate'],
      createdDate: map['createdDate'],
    );
  }

  String toJson() => json.encode(toMap());

  factory AppNotificationModel.fromJson(String source) => AppNotificationModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'AppNotificationModel(id: $id, title: $title, text: $text, viewDate: $viewDate, createdDate: $createdDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppNotificationModel &&
        other.id == id &&
        other.title == title &&
        other.text == text &&
        other.viewDate == viewDate &&
        other.createdDate == createdDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^ title.hashCode ^ text.hashCode ^ viewDate.hashCode ^ createdDate.hashCode;
  }
}
