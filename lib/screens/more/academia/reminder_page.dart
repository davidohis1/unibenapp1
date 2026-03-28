import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_constants.dart';
import '../../../models/reminder_model.dart';
import '../../../services/reminder_manager.dart';

class ReminderPage extends StatefulWidget {
  const ReminderPage({Key? key}) : super(key: key);

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final ReminderManager _reminderManager = ReminderManager();
  final List<Reminder> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
    _reminderManager.initialize();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    final reminders = await _reminderManager.getUpcomingReminders();
    setState(() {
      _reminders.clear();
      _reminders.addAll(reminders);
      _isLoading = false;
    });
  }

  void _showAddReminderDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    TimeOfDay selectedTime = TimeOfDay.now();
    bool isDaily = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add New Reminder', 
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Title*',
                      hintText: 'e.g., Math Assignment',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'e.g., Complete chapter 5 exercises',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) {
                              setState(() {
                                selectedDate = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
                                );
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.borderColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Date', style: GoogleFonts.poppins()),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(selectedDate),
                                  style: GoogleFonts.poppins(
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (time != null) {
                              setState(() {
                                selectedTime = time;
                                selectedDate = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.borderColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Time', style: GoogleFonts.poppins()),
                                Text(
                                  selectedTime.format(context),
                                  style: GoogleFonts.poppins(
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isDaily,
                        onChanged: (value) => setState(() => isDaily = value!),
                        activeColor: AppColors.primaryPurple,
                      ),
                      Text('Daily Reminder', style: GoogleFonts.poppins()),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a title')),
                    );
                    return;
                  }

                  final reminder = Reminder(
                    title: titleController.text,
                    description: descriptionController.text.isNotEmpty
                        ? descriptionController.text
                        : 'Reminder',
                    dateTime: selectedDate,
                    isDaily: isDaily,
                  );

                  await _reminderManager.addReminder(reminder);
                  await _loadReminders();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Save Reminder', 
                  style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReminderDetails(Reminder reminder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reminder.title, 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reminder.description, style: GoogleFonts.poppins()),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: AppColors.grey),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(reminder.dateTime),
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ],
            ),
            if (reminder.isDaily) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.repeat, size: 16, color: AppColors.grey),
                  const SizedBox(width: 8),
                  Text('Daily', style: GoogleFonts.poppins(fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              await _reminderManager.deleteReminder(reminder.id);
              await _loadReminders();
              Navigator.pop(context);
            },
          ),
          IconButton(
            icon: Icon(
              reminder.isActive ? Icons.notifications_off : Icons.notifications,
              color: AppColors.primaryPurple,
            ),
            onPressed: () async {
              await _reminderManager.toggleReminder(
                reminder.id, 
                !reminder.isActive
              );
              await _loadReminders();
              setState(() {});
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: Text('Study Reminders', 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alert),
            onPressed: _showAddReminderDialog,
            tooltip: 'Add Reminder',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 80, color: AppColors.grey.withOpacity(0.5)),
                      const SizedBox(height: 20),
                      Text(
                        'No Reminders Yet',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: AppColors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Add your first study reminder',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reminders.length,
                  itemBuilder: (context, index) {
                    final reminder = _reminders[index];
                    return _buildReminderCard(reminder);
                  },
                ),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final timeLeft = reminder.dateTime.difference(DateTime.now());
    String timeLeftText = '';
    
    if (timeLeft.inDays > 0) {
      timeLeftText = '${timeLeft.inDays}d left';
    } else if (timeLeft.inHours > 0) {
      timeLeftText = '${timeLeft.inHours}h left';
    } else if (timeLeft.inMinutes > 0) {
      timeLeftText = '${timeLeft.inMinutes}m left';
    } else {
      timeLeftText = 'Overdue';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: () => _showReminderDetails(reminder),
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            reminder.isDaily ? Icons.repeat : Icons.notifications,
            color: AppColors.primaryPurple,
          ),
        ),
        title: Text(
          reminder.title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              reminder.description,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.grey,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: AppColors.grey),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd • hh:mm a').format(reminder.dateTime),
                  style: GoogleFonts.poppins(fontSize: 10),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: reminder.isActive
                        ? AppColors.successGreen.withOpacity(0.1)
                        : AppColors.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    reminder.isActive ? 'Active' : 'Inactive',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: reminder.isActive
                          ? AppColors.successGreen
                          : AppColors.errorRed,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              timeLeftText,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: timeLeft.isNegative ? Colors.red : AppColors.primaryPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (reminder.isDaily)
              const Icon(Icons.repeat, size: 16, color: Colors.green),
          ],
        ),
      ),
    );
  }
}