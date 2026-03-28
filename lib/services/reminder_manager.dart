import '../models/reminder_model.dart';
import 'reminder_database.dart';
import 'notification_service.dart';

class ReminderManager {
  static final ReminderManager _instance = ReminderManager._internal();
  factory ReminderManager() => _instance;
  ReminderManager._internal();

  final ReminderDatabase _database = ReminderDatabase();
  final NotificationService _notificationService = NotificationService();

  Future<void> initialize() async {
    await _notificationService.initialize();
    await _rescheduleAllReminders();
  }

  Future<void> addReminder(Reminder reminder) async {
    // Generate notification ID from reminder ID hash
    reminder.notificationId = reminder.id.hashCode.abs();
    
    await _database.insertReminder(reminder);
    
    if (reminder.isActive && reminder.hasNotification) {
      await _scheduleReminderNotification(reminder);
    }
  }

  Future<void> updateReminder(Reminder reminder) async {
    // Cancel existing notification
    if (reminder.notificationId != null) {
      await _notificationService.cancelReminder(reminder.notificationId!);
    }
    
    // Update in database
    await _database.updateReminder(reminder);
    
    // Schedule new notification if active
    if (reminder.isActive && reminder.hasNotification) {
      await _scheduleReminderNotification(reminder);
    }
  }

  Future<void> deleteReminder(String id) async {
    final reminder = await _database.getReminder(id);
    if (reminder != null && reminder.notificationId != null) {
      await _notificationService.cancelReminder(reminder.notificationId!);
    }
    await _database.deleteReminder(id);
  }

  Future<void> toggleReminder(String id, bool isActive) async {
    await _database.toggleReminder(id, isActive);
    
    final reminder = await _database.getReminder(id);
    if (reminder != null) {
      if (isActive && reminder.hasNotification) {
        await _scheduleReminderNotification(reminder);
      } else if (!isActive && reminder.notificationId != null) {
        await _notificationService.cancelReminder(reminder.notificationId!);
      }
    }
  }

  Future<void> _scheduleReminderNotification(Reminder reminder) async {
    await _notificationService.scheduleReminder(
      id: reminder.notificationId!,
      title: reminder.title,
      body: reminder.description,
      scheduledDate: reminder.dateTime,
      sound: 'alarm_sound',
      daily: reminder.isDaily,
    );
  }

  Future<void> _rescheduleAllReminders() async {
    final reminders = await _database.getActiveReminders();
    for (final reminder in reminders) {
      if (reminder.hasNotification) {
        await _scheduleReminderNotification(reminder);
      }
    }
  }

  Future<List<Reminder>> getUpcomingReminders() async {
    final reminders = await _database.getActiveReminders();
    final now = DateTime.now();
    
    return reminders
        .where((reminder) => reminder.dateTime.isAfter(now))
        .toList();
  }

  Future<List<Reminder>> getPastReminders() async {
    final reminders = await _database.getActiveReminders();
    final now = DateTime.now();
    
    return reminders
        .where((reminder) => reminder.dateTime.isBefore(now))
        .toList();
  }

  Future<List<Reminder>> getDailyReminders() async {
    final reminders = await _database.getActiveReminders();
    return reminders.where((reminder) => reminder.isDaily).toList();
  }

  Future<void> markAsTriggered(String id) async {
    final reminder = await _database.getReminder(id);
    if (reminder != null) {
      final updatedReminder = reminder.copyWith(
        lastTriggered: DateTime.now(),
      );
      await _database.updateReminder(updatedReminder);
    }
  }
}