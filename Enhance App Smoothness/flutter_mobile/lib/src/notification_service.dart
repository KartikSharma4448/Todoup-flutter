import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const String _channelId = 'todoup_task_reminders';
  static const String _channelName = 'Task reminders';
  static const String _channelDescription =
      'Scheduled reminders for upcoming tasks.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _notificationPermissionRequested = false;
  bool _exactAlarmPermissionRequested = false;
  bool _canUseExactAlarms = false;

  Future<void> initialize() async {
    if (_initialized || !_supportsNotifications) {
      return;
    }

    tz.initializeTimeZones();
    await _configureLocalTimeZone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.max,
          ),
        );

    _initialized = true;
  }

  Future<void> syncTaskReminders(
    List<TaskItem> tasks, {
    required bool enabled,
  }) async {
    if (!_supportsNotifications) {
      return;
    }

    await initialize();

    if (!enabled) {
      await _plugin.cancelAll();
      return;
    }

    final tasksToSchedule = tasks
        .where(_shouldScheduleReminder)
        .toList(growable: false);
    await _requestPermissionsIfNeeded(
      requestExactAlarm: tasksToSchedule.isNotEmpty,
    );

    final activeIds = <int>{};
    for (final task in tasksToSchedule) {
      activeIds.add(_notificationId(task.id));
      await _scheduleTaskReminder(task);
    }

    for (final task in tasks.where(
      (task) => !activeIds.contains(_notificationId(task.id)),
    )) {
      await cancelTaskReminder(task.id);
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (!_supportsNotifications) {
      return;
    }

    await initialize();
    await _plugin.cancel(id: _notificationId(taskId));
  }

  Future<void> _requestPermissionsIfNeeded({
    required bool requestExactAlarm,
  }) async {
    if (!_supportsNotifications) {
      return;
    }

    if (Platform.isAndroid && !_notificationPermissionRequested) {
      _notificationPermissionRequested = true;
      try {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } catch (_) {
        // Best-effort request. Scheduling still proceeds where allowed.
      }
    }

    if (Platform.isIOS && !_notificationPermissionRequested) {
      _notificationPermissionRequested = true;
      try {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } catch (_) {
        // Best-effort request. The OS will enforce the final state.
      }
    }

    if (Platform.isAndroid &&
        requestExactAlarm &&
        !_exactAlarmPermissionRequested) {
      _exactAlarmPermissionRequested = true;
      try {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestExactAlarmsPermission();
        _canUseExactAlarms = granted == true;
      } catch (_) {
        // If exact alarms are unavailable, the app falls back to inexact mode.
        _canUseExactAlarms = false;
      }
    }
  }

  Future<void> _scheduleTaskReminder(TaskItem task) async {
    final scheduledDate = _nextScheduledDate(task);
    if (scheduledDate == null) {
      await cancelTaskReminder(task.id);
      return;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
      ),
      iOS: const DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.timeSensitive,
        threadIdentifier: 'todoup-reminders',
      ),
    );

    await _plugin.zonedSchedule(
      id: _notificationId(task.id),
      title: task.title,
      body: _buildBody(task),
      scheduledDate: scheduledDate,
      notificationDetails: details,
      payload: task.id,
      androidScheduleMode: _androidScheduleMode,
      matchDateTimeComponents: _dateTimeComponents(task.repeat),
    );
  }

  Future<void> _configureLocalTimeZone() async {
    if (kIsWeb) {
      return;
    }

    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  tz.TZDateTime? _nextScheduledDate(TaskItem task) {
    final reminderTime = task.dueTime ?? const TimeOfDay(hour: 9, minute: 0);
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
      reminderTime.hour,
      reminderTime.minute,
    );

    switch (task.repeat) {
      case 'Daily':
        while (!scheduledDate.isAfter(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
        return scheduledDate;
      case 'Weekly':
        while (!scheduledDate.isAfter(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 7));
        }
        return scheduledDate;
      case 'Monthly':
        while (!scheduledDate.isAfter(now)) {
          scheduledDate = tz.TZDateTime(
            tz.local,
            scheduledDate.year,
            scheduledDate.month + 1,
            task.dueDate.day,
            reminderTime.hour,
            reminderTime.minute,
          );
        }
        return scheduledDate;
      case 'Yearly':
        while (!scheduledDate.isAfter(now)) {
          scheduledDate = tz.TZDateTime(
            tz.local,
            scheduledDate.year + 1,
            task.dueDate.month,
            task.dueDate.day,
            reminderTime.hour,
            reminderTime.minute,
          );
        }
        return scheduledDate;
      case 'None':
      default:
        return scheduledDate.isAfter(now) ? scheduledDate : null;
    }
  }

  bool _shouldScheduleReminder(TaskItem task) {
    if (!task.reminder || task.completed) {
      return false;
    }
    return task.dueTime != null || task.repeat != 'None';
  }

  String _buildBody(TaskItem task) {
    final time = task.dueTime == null
        ? ''
        : _formatTimeLabel(task.dueTime!.hour, task.dueTime!.minute);
    if (time.isEmpty) {
      return 'Reminder for ${task.dueLabel.toLowerCase()}.';
    }
    return 'Scheduled for ${task.dueLabel.toLowerCase()} at $time.';
  }

  DateTimeComponents? _dateTimeComponents(String repeat) {
    switch (repeat) {
      case 'Daily':
        return DateTimeComponents.time;
      case 'Weekly':
        return DateTimeComponents.dayOfWeekAndTime;
      case 'Monthly':
        return DateTimeComponents.dayOfMonthAndTime;
      case 'Yearly':
        return DateTimeComponents.dateAndTime;
      case 'None':
      default:
        return null;
    }
  }

  AndroidScheduleMode get _androidScheduleMode {
    if (Platform.isAndroid && _canUseExactAlarms) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  int _notificationId(String taskId) {
    var value = 0;
    for (final unit in taskId.codeUnits) {
      value = ((value * 31) + unit) & 0x7fffffff;
    }
    return value;
  }

  bool get _supportsNotifications {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }
}

String _formatTimeLabel(int hour24, int minute) {
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final suffix = hour24 >= 12 ? 'PM' : 'AM';
  return '$hour:${minute.toString().padLeft(2, '0')} $suffix';
}
