import 'dart:convert';

class NotificationPayloadModel {
  int? id;
  String? title;
  String? text;
  String? imageUrl;
  String? url;
  String? topic;
  String? entity;
  String? entityData;
  String? createdDate;
  NotificationPayloadModel({
    this.id,
    this.title,
    this.text,
    this.imageUrl,
    this.url,
    this.topic,
    this.entity,
    this.entityData,
    this.createdDate,
  });

  NotificationPayloadModel copyWith({
    int? id,
    String? title,
    String? text,
    String? imageUrl,
    String? url,
    String? topic,
    String? entity,
    String? entityData,
    String? createdDate,
  }) {
    return NotificationPayloadModel(
      id: id ?? this.id,
      title: title ?? this.title,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      url: url ?? this.url,
      topic: topic ?? this.topic,
      entity: entity ?? this.entity,
      entityData: entityData ?? this.entityData,
      createdDate: createdDate ?? this.createdDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'text': text,
      'imageUrl': imageUrl,
      'url': url,
      'topic': topic,
      'entity': entity,
      'entityData': entityData,
      'createdDate': createdDate,
    };
  }

  factory NotificationPayloadModel.fromMap(Map<String, dynamic> map) {
    return NotificationPayloadModel(
      id: map['id']?.toInt(),
      title: map['title'],
      text: map['text'],
      imageUrl: map['imageUrl'],
      url: map['url'],
      topic: map['topic'],
      entity: map['entity'],
      entityData: map['entityData'],
      createdDate: map['createdDate'],
    );
  }

  String toJson() => json.encode(toMap());

  factory NotificationPayloadModel.fromJson(String source) => NotificationPayloadModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'NotificationPayloadModel(id: $id, title: $title, text: $text, imageUrl: $imageUrl, url: $url, topic: $topic, entity: $entity, entityData: $entityData, createdDate: $createdDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NotificationPayloadModel &&
        other.id == id &&
        other.title == title &&
        other.text == text &&
        other.imageUrl == imageUrl &&
        other.url == url &&
        other.topic == topic &&
        other.entity == entity &&
        other.entityData == entityData &&
        other.createdDate == createdDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        text.hashCode ^
        imageUrl.hashCode ^
        url.hashCode ^
        topic.hashCode ^
        entity.hashCode ^
        entityData.hashCode ^
        createdDate.hashCode;
  }
}
