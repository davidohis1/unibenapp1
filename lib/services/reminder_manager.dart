import 'package:flutter/foundation.dart';
import '../models/reminder_model.dart';
import 'reminder_database.dart';
import 'notification_service.dart';

class ReminderManager {
  static final ReminderManager _instance = ReminderManager._internal();
  factory ReminderManager() => _instance;
  ReminderManager._internal();

  final ReminderDatabase _database = ReminderDatabase();
  final NotificationService _notificationService = NotificationService();

  // FIX: Return a Future so callers can await initialization before saving.
  Future<void> initialize() async {
    await _notificationService.initialize();
    await _rescheduleAllReminders();
  }

  Future<void> addReminder(Reminder reminder) async {
    reminder.notificationId = reminder.id.hashCode.abs();
    await _database.insertReminder(reminder);

    if (reminder.isActive && reminder.hasNotification) {
      // FIX: Wrap notification scheduling in try/catch so a permissions or
      // plugin error doesn't prevent the reminder from being saved to the DB.
      try {
        await _scheduleReminderNotification(reminder);
      } catch (e) {
        // Reminder is persisted in DB; notification failure is non-fatal.
        debugPrint('ReminderManager: Failed to schedule notification: $e');
        rethrow; // Rethrow so the UI can show a warning if needed.
      }
    }
  }

  Future<void> updateReminder(Reminder reminder) async {
    if (reminder.notificationId != null) {
      try {
        await _notificationService.cancelReminder(reminder.notificationId!);
      } catch (e) {
        debugPrint('ReminderManager: Failed to cancel notification: $e');
      }
    }

    await _database.updateReminder(reminder);

    if (reminder.isActive && reminder.hasNotification) {
      try {
        await _scheduleReminderNotification(reminder);
      } catch (e) {
        debugPrint('ReminderManager: Failed to schedule notification: $e');
      }
    }
  }

  Future<void> deleteReminder(String id) async {
    final reminder = await _database.getReminder(id);
    if (reminder != null && reminder.notificationId != null) {
      try {
        await _notificationService.cancelReminder(reminder.notificationId!);
      } catch (e) {
        debugPrint('ReminderManager: Failed to cancel notification: $e');
      }
    }
    await _database.deleteReminder(id);
  }

  Future<void> toggleReminder(String id, bool isActive) async {
    await _database.toggleReminder(id, isActive);

    final reminder = await _database.getReminder(id);
    if (reminder != null) {
      try {
        if (isActive && reminder.hasNotification) {
          await _scheduleReminderNotification(reminder);
        } else if (!isActive && reminder.notificationId != null) {
          await _notificationService.cancelReminder(reminder.notificationId!);
        }
      } catch (e) {
        debugPrint('ReminderManager: Failed to toggle notification: $e');
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
    try {
      final reminders = await _database.getActiveReminders();
      for (final reminder in reminders) {
        if (reminder.hasNotification) {
          try {
            await _scheduleReminderNotification(reminder);
          } catch (e) {
            debugPrint(
                'ReminderManager: Failed to reschedule ${reminder.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('ReminderManager: _rescheduleAllReminders failed: $e');
    }
  }

  // FIX: New method — returns ALL reminders (active + inactive, past + future).
  // Use this for displaying on the reminders page so nothing is hidden.
  Future<List<Reminder>> getAllReminders() async {
    return await _database.getAllReminders();
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