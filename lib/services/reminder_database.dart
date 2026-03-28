import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/reminder_model.dart';

class ReminderDatabase {
  static final ReminderDatabase _instance = ReminderDatabase._internal();
  factory ReminderDatabase() => _instance;
  ReminderDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'reminders.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reminders(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        isDaily INTEGER DEFAULT 0,
        isActive INTEGER DEFAULT 1,
        hasNotification INTEGER DEFAULT 1,
        lastTriggered TEXT,
        soundPath TEXT,
        notificationId INTEGER
      )
    ''');
  }

  // CRUD Operations
  Future<int> insertReminder(Reminder reminder) async {
    final db = await database;
    return await db.insert('reminders', reminder.toJson());
  }

  Future<List<Reminder>> getAllReminders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      orderBy: 'dateTime ASC',
    );
    return List.generate(maps.length, (i) => Reminder.fromJson(maps[i]));
  }

  Future<List<Reminder>> getActiveReminders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'dateTime ASC',
    );
    return List.generate(maps.length, (i) => Reminder.fromJson(maps[i]));
  }

  Future<Reminder?> getReminder(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Reminder.fromJson(maps.first);
    }
    return null;
  }

  Future<int> updateReminder(Reminder reminder) async {
    final db = await database;
    return await db.update(
      'reminders',
      reminder.toJson(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<int> deleteReminder(String id) async {
    final db = await database;
    return await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> toggleReminder(String id, bool isActive) async {
    final db = await database;
    return await db.update(
      'reminders',
      {'isActive': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}