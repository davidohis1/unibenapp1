import 'package:uuid/uuid.dart';

class Reminder {
  String id;
  String title;
  String description;
  DateTime dateTime;
  bool isDaily;
  bool isActive;
  bool hasNotification;
  DateTime? lastTriggered;
  String? soundPath;
  int? notificationId;

  Reminder({
    String? id,
    required this.title,
    required this.description,
    required this.dateTime,
    this.isDaily = false,
    this.isActive = true,
    this.hasNotification = true,
    this.lastTriggered,
    this.soundPath,
    this.notificationId,
  }) : id = id ?? const Uuid().v4();

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      dateTime: DateTime.parse(json['dateTime']),
      isDaily: json['isDaily'] ?? false,
      isActive: json['isActive'] ?? true,
      hasNotification: json['hasNotification'] ?? true,
      lastTriggered: json['lastTriggered'] != null 
          ? DateTime.parse(json['lastTriggered']) 
          : null,
      soundPath: json['soundPath'],
      notificationId: json['notificationId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'isDaily': isDaily,
      'isActive': isActive,
      'hasNotification': hasNotification,
      'lastTriggered': lastTriggered?.toIso8601String(),
      'soundPath': soundPath,
      'notificationId': notificationId,
    };
  }

  Reminder copyWith({
    String? title,
    String? description,
    DateTime? dateTime,
    bool? isDaily,
    bool? isActive,
    bool? hasNotification,
    DateTime? lastTriggered,
    String? soundPath,
    int? notificationId,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      isDaily: isDaily ?? this.isDaily,
      isActive: isActive ?? this.isActive,
      hasNotification: hasNotification ?? this.hasNotification,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      soundPath: soundPath ?? this.soundPath,
      notificationId: notificationId ?? this.notificationId,
    );
  }
}