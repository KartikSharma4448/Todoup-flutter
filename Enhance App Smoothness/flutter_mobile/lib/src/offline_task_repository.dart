import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'api_service.dart';
import 'models.dart';

class OfflineTaskRepository {
  OfflineTaskRepository._();

  static final OfflineTaskRepository instance = OfflineTaskRepository._();

  static const String _tasksBoxName = 'offline_tasks';
  static const String _pendingBoxName = 'pending_task_queue';
  static const String _profileBoxName = 'offline_profile';

  final Uuid _uuid = const Uuid();
  bool _initialized = false;
  late Box<Map> _tasksBox;
  late Box<Map> _pendingBox;
  late Box<Map> _profileBox;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    await Hive.initFlutter();
    _tasksBox = await Hive.openBox<Map>(_tasksBoxName);
    _pendingBox = await Hive.openBox<Map>(_pendingBoxName);
    _profileBox = await Hive.openBox<Map>(_profileBoxName);
    _initialized = true;
  }

  List<TaskItem> getCachedTasks() {
    return _tasksBox.values
        .map((raw) => TaskItem.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  List<TaskItem> getLocalDrafts() {
    return getCachedTasks()
        .where((task) => task.id.startsWith('local-'))
        .toList(growable: false);
  }

  Future<void> cacheServerTasks(List<TaskItem> remote) async {
    // Keep local drafts; replace only server-backed tasks.
    final keysToRemove = _tasksBox.keys
        .where((key) => key is String && !key.startsWith('local-'))
        .toList(growable: false);
    if (keysToRemove.isNotEmpty) {
      await _tasksBox.deleteAll(keysToRemove);
    }
    for (final task in remote) {
      await _tasksBox.put(task.id, task.toJson());
    }
  }

  Future<TaskItem> createLocalTask({
    required String title,
    required String description,
    required DateTime dueDate,
    required TaskPriority priority,
    required TaskCategory category,
    required bool reminder,
    required String repeat,
    required List<String> subtasks,
    required TimeOfDay dueTime,
  }) async {
    final now = DateTime.now();
    final id = 'local-${_uuid.v4()}';
    final task = TaskItem(
      id: id,
      title: title,
      completed: false,
      dueDate: DateTime(dueDate.year, dueDate.month, dueDate.day),
      dueLabel: _relativeDueLabel(dueDate),
      priority: priority,
      category: category,
      description: description.isEmpty ? null : description,
      reminder: reminder,
      repeat: repeat,
      subtasks: subtasks,
      completedSubtasks: 0,
      dueTime: dueTime,
      createdAt: now,
      updatedAt: now,
    );

    final payload = {
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'dueTime':
          '${dueTime.hour.toString().padLeft(2, '0')}:${dueTime.minute.toString().padLeft(2, '0')}',
      'priority': priority.apiValue,
      'category': category.apiValue,
      'reminder': reminder,
      'repeat': repeat,
      'subtasks': subtasks,
      'completedSubtasks': 0,
    };

    await _tasksBox.put(id, task.toJson());
    await _pendingBox.add({
      'type': 'create',
      'localId': id,
      'payload': payload,
    });

    return task;
  }

  Future<void> clear() async {
    await _tasksBox.clear();
    await _pendingBox.clear();
    await _profileBox.clear();
  }

  Future<void> cacheProfile(UserProfile profile) async {
    await _profileBox.put('profile', profile.toJson());
  }

  UserProfile? getCachedProfile() {
    final raw = _profileBox.get('profile');
    if (raw is Map) {
      return UserProfile.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  bool get hasPendingSync => _pendingBox.isNotEmpty;

  Future<List<TaskItem>> syncPendingTasks(ApiService api) async {
    final syncedTasks = <TaskItem>[];
    final keys = _pendingBox.keys.toList(growable: false);

    for (final key in keys) {
      final raw = _pendingBox.get(key);
      if (raw is! Map) {
        continue;
      }
      final type = raw['type']?.toString();
      if (type != 'create') {
        continue;
      }

      final localId = raw['localId']?.toString() ?? '';
      final payload = Map<String, dynamic>.from(
        raw['payload'] as Map<String, dynamic>,
      );

      try {
        final created = await api.createTask(payload);
        // Replace local draft with server copy.
        await _tasksBox.delete(localId);
        await _tasksBox.put(created.id, created.toJson());
        await _pendingBox.delete(key);
        syncedTasks.add(created);
      } catch (_) {
        // Keep in queue; will retry on next connectivity change.
      }
    }

    return syncedTasks;
  }
}

String _relativeDueLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final difference = target.difference(today).inDays;
  if (difference == 0) {
    return 'Today';
  }
  if (difference == 1) {
    return 'Tomorrow';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}
