import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_mobile/src/models.dart';
import 'package:flutter_mobile/src/state.dart';

void main() {
  test('TaskItem.fromJson rebuilds the due label from the date', () {
    final today = DateTime.now();
    final task = TaskItem.fromJson({
      'localId': 'task-1',
      'title': 'Check dates',
      'completed': false,
      'dueDate': DateTime(today.year, today.month, today.day).toIso8601String(),
      'dueLabel': 'Wrong label',
      'priority': 'medium',
      'category': 'personal',
    });

    expect(task.dueLabel, 'Today');
  });

  test('formatTaskScheduleLabel includes both relative date and time', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final task = TaskItem(
      localId: 'task-2',
      title: 'Morning review',
      completed: false,
      dueDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
      dueLabel: 'Tomorrow',
      priority: TaskPriority.medium,
      category: TaskCategory.work,
      dueTime: const TimeOfDay(hour: 9, minute: 30),
    );

    final label = formatTaskScheduleLabel(task);

    expect(label, contains('Tomorrow'));
    expect(label, contains('9:30 AM'));
  });

  test('isTaskOverdue detects past timed tasks', () {
    final task = TaskItem(
      localId: 'task-3',
      title: 'Missed reminder',
      completed: false,
      dueDate: DateTime(2026, 4, 1),
      dueLabel: 'Yesterday',
      priority: TaskPriority.high,
      category: TaskCategory.work,
      dueTime: const TimeOfDay(hour: 8, minute: 0),
    );

    expect(isTaskOverdue(task, now: DateTime(2026, 4, 2, 9)), isTrue);
    expect(isTaskOverdue(task.copyWith(completed: true), now: DateTime(2026, 4, 2, 9)), isFalse);
  });
}
