import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'models.dart';

class SmartWidgetService {
  SmartWidgetService._();

  static final SmartWidgetService instance = SmartWidgetService._();

  static const String androidWidgetName = 'ToDoUpWidgetProvider';
  static const String androidQualifiedName = 'app.todoup.ToDoUpWidgetProvider';
  static const String iOSWidgetName = 'ToDoUpWidget';
  static const String iOSAppGroupId = 'group.app.todoup';
  static const int _maxTasks = 3;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !_supportsWidgets) {
      return;
    }

    if (Platform.isIOS) {
      try {
        await HomeWidget.setAppGroupId(iOSAppGroupId);
      } catch (_) {
        // The iOS widget target may not be configured in local development.
      }
    }

    _initialized = true;
  }

  Future<void> sync({
    required List<TaskItem> tasks,
    required double productivityScore,
    required double completionRate,
    required int pendingTasks,
    UserProfile? profile,
  }) async {
    if (!_supportsWidgets) {
      return;
    }

    try {
      await initialize();

      final snapshot = SmartWidgetSnapshot.fromTasks(
        tasks: tasks,
        productivityScore: productivityScore,
        completionRate: completionRate,
        pendingTasks: pendingTasks,
        profileName: profile?.name,
      );

      final writes = <Future<bool?>>[
        HomeWidget.saveWidgetData<String>('todoup_header', snapshot.header),
        HomeWidget.saveWidgetData<String>('todoup_subtitle', snapshot.subtitle),
        HomeWidget.saveWidgetData<int>('todoup_score', snapshot.score),
        HomeWidget.saveWidgetData<String>(
          'todoup_progress_label',
          snapshot.progressLabel,
        ),
        HomeWidget.saveWidgetData<String>(
          'todoup_completion_label',
          snapshot.completionLabel,
        ),
        HomeWidget.saveWidgetData<String>(
          'todoup_footer_label',
          snapshot.footerLabel,
        ),
        HomeWidget.saveWidgetData<int>(
          'todoup_task_count',
          snapshot.tasks.length,
        ),
        HomeWidget.saveWidgetData<bool>(
          'todoup_has_tasks',
          snapshot.tasks.isNotEmpty,
        ),
        HomeWidget.saveWidgetData<String>(
          'todoup_updated_at',
          snapshot.updatedAtLabel,
        ),
      ];

      for (var index = 0; index < _maxTasks; index++) {
        final task = index < snapshot.tasks.length
            ? snapshot.tasks[index]
            : null;
        writes.addAll([
          HomeWidget.saveWidgetData<String>(
            'todoup_task_${index}_title',
            task?.title ?? '',
          ),
          HomeWidget.saveWidgetData<String>(
            'todoup_task_${index}_subtitle',
            task?.subtitle ?? '',
          ),
          HomeWidget.saveWidgetData<String>(
            'todoup_task_${index}_category',
            task?.category.apiValue ?? '',
          ),
          HomeWidget.saveWidgetData<bool>(
            'todoup_task_${index}_completed',
            task?.completed ?? false,
          ),
        ]);
      }

      await Future.wait(writes);
      await _updateWidget();
    } catch (_) {
      // Widget sync should never block the app UI.
    }
  }

  Future<void> clear() async {
    if (!_supportsWidgets) {
      return;
    }

    try {
      await initialize();

      final clears = <Future<bool?>>[
        HomeWidget.saveWidgetData<String>('todoup_header', 'ToDoUp'),
        HomeWidget.saveWidgetData<String>(
          'todoup_subtitle',
          'Sign in to sync your daily widget',
        ),
        HomeWidget.saveWidgetData<int>('todoup_score', 0),
        HomeWidget.saveWidgetData<String>(
          'todoup_progress_label',
          '0 tasks today',
        ),
        HomeWidget.saveWidgetData<String>(
          'todoup_completion_label',
          '0% complete',
        ),
        HomeWidget.saveWidgetData<String>(
          'todoup_footer_label',
          'No synced tasks',
        ),
        HomeWidget.saveWidgetData<int>('todoup_task_count', 0),
        HomeWidget.saveWidgetData<bool>('todoup_has_tasks', false),
        HomeWidget.saveWidgetData<String>(
          'todoup_updated_at',
          'Waiting for sync',
        ),
      ];

      for (var index = 0; index < _maxTasks; index++) {
        clears.addAll([
          HomeWidget.saveWidgetData<String>('todoup_task_${index}_title', ''),
          HomeWidget.saveWidgetData<String>(
            'todoup_task_${index}_subtitle',
            '',
          ),
          HomeWidget.saveWidgetData<String>(
            'todoup_task_${index}_category',
            '',
          ),
          HomeWidget.saveWidgetData<bool>(
            'todoup_task_${index}_completed',
            false,
          ),
        ]);
      }

      await Future.wait(clears);
      await _updateWidget();
    } catch (_) {
      // Widget clear is best-effort and shouldn't break auth flows.
    }
  }

  Future<void> requestPinWidget() async {
    if (!_supportsWidgets || !Platform.isAndroid) {
      return;
    }

    await initialize();
    await HomeWidget.requestPinWidget(
      qualifiedAndroidName: androidQualifiedName,
    );
  }

  Future<bool> isPinWidgetSupported() async {
    if (!_supportsWidgets || !Platform.isAndroid) {
      return false;
    }

    await initialize();
    return await HomeWidget.isRequestPinWidgetSupported() ?? false;
  }

  Future<void> _updateWidget() {
    return HomeWidget.updateWidget(
      name: androidWidgetName,
      iOSName: iOSWidgetName,
      qualifiedAndroidName: androidQualifiedName,
    );
  }

  bool get _supportsWidgets {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }
}

class SmartWidgetSnapshot {
  SmartWidgetSnapshot({
    required this.header,
    required this.subtitle,
    required this.score,
    required this.progressLabel,
    required this.completionLabel,
    required this.footerLabel,
    required this.updatedAtLabel,
    required this.tasks,
  });

  factory SmartWidgetSnapshot.fromTasks({
    required List<TaskItem> tasks,
    required double productivityScore,
    required double completionRate,
    required int pendingTasks,
    String? profileName,
  }) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final tomorrowOnly = todayOnly.add(const Duration(days: 1));

    final todayTasks = tasks
        .where(
          (task) =>
              !task.completed &&
              !task.dueDate.isBefore(todayOnly) &&
              task.dueDate.isBefore(tomorrowOnly),
        )
        .toList(growable: false);

    final fallbackTasks = tasks
        .where((task) => !task.completed)
        .take(SmartWidgetService._maxTasks)
        .toList(growable: false);

    final widgetTasks = (todayTasks.isNotEmpty ? todayTasks : fallbackTasks)
        .take(SmartWidgetService._maxTasks)
        .map(WidgetTaskSummary.fromTask)
        .toList(growable: false);

    final todayCount = tasks.where((task) {
      final dueDate = DateTime(
        task.dueDate.year,
        task.dueDate.month,
        task.dueDate.day,
      );
      return dueDate == todayOnly;
    }).length;

    final completedToday = tasks.where((task) {
      final completedAt = task.completedAt;
      if (completedAt == null) {
        return false;
      }
      final day = DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      );
      return day == todayOnly;
    }).length;

    final firstName = _firstName(profileName);

    return SmartWidgetSnapshot(
      header: firstName == null ? 'ToDoUp' : '$firstName\'s Day',
      subtitle: widgetTasks.isEmpty
          ? 'No active tasks lined up'
          : 'Today\'s focus',
      score: productivityScore.round(),
      progressLabel: todayCount == 0
          ? 'No tasks due today'
          : '$completedToday/$todayCount done today',
      completionLabel: '${(completionRate * 100).round()}% complete',
      footerLabel: pendingTasks == 0
          ? 'Inbox clear'
          : '$pendingTasks task${pendingTasks == 1 ? '' : 's'} pending',
      updatedAtLabel: _buildUpdatedAtLabel(today),
      tasks: widgetTasks,
    );
  }

  final String header;
  final String subtitle;
  final int score;
  final String progressLabel;
  final String completionLabel;
  final String footerLabel;
  final String updatedAtLabel;
  final List<WidgetTaskSummary> tasks;

  static String _buildUpdatedAtLabel(DateTime now) {
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final suffix = now.hour >= 12 ? 'PM' : 'AM';
    return 'Updated $hour:$minute $suffix';
  }

  static String? _firstName(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized.split(RegExp(r'\s+')).first;
  }
}

class WidgetTaskSummary {
  const WidgetTaskSummary({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.completed,
  });

  factory WidgetTaskSummary.fromTask(TaskItem task) {
    final time = task.dueTime == null
        ? ''
        : _formatTimeLabel(task.dueTime!.hour, task.dueTime!.minute);
    final subtitle = time.isEmpty ? task.dueLabel : '${task.dueLabel} - $time';
    return WidgetTaskSummary(
      title: task.title,
      subtitle: subtitle,
      category: task.category,
      completed: task.completed,
    );
  }

  final String title;
  final String subtitle;
  final TaskCategory category;
  final bool completed;
}

String _formatTimeLabel(int hour24, int minute) {
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final suffix = hour24 >= 12 ? 'PM' : 'AM';
  return '$hour:${minute.toString().padLeft(2, '0')} $suffix';
}
