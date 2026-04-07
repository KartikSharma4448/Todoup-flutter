import 'package:hive_flutter/hive_flutter.dart';

import '../models.dart';

class LocalDatabaseService {
  LocalDatabaseService._();

  static final LocalDatabaseService instance = LocalDatabaseService._();

  static const _tasksBoxName = 'todo_tasks';
  static const _pendingBoxName = 'todo_pending_operations';
  static const _profileBoxName = 'todo_profile';
  static const _attachmentsBoxName = 'todo_task_attachments';

  bool _initialized = false;
  late final Box<Map> _tasksBox;
  late final Box<Map> _pendingBox;
  late final Box<Map> _profileBox;
  late final Box<Map> _attachmentsBox;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    await Hive.initFlutter();
    _tasksBox = await Hive.openBox<Map>(_tasksBoxName);
    _pendingBox = await Hive.openBox<Map>(_pendingBoxName);
    _profileBox = await Hive.openBox<Map>(_profileBoxName);
    _attachmentsBox = await Hive.openBox<Map>(_attachmentsBoxName);
    _initialized = true;
  }

  List<TaskItem> getCachedTasks() {
    return _tasksBox.values
        .map((raw) => TaskItem.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  TaskItem? getTaskByLocalId(String localId) {
    final raw = _tasksBox.get(localId);
    if (raw is Map) {
      return TaskItem.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  TaskItem? getTaskById(String id) {
    for (final raw in _tasksBox.values) {
      final task = TaskItem.fromJson(Map<String, dynamic>.from(raw));
      if (task.id == id) {
        return task;
      }
    }
    return null;
  }

  Future<void> upsertTask(TaskItem task) async {
    await _tasksBox.put(task.localId, task.toJson());
  }

  Future<void> removeTask(String localId) async {
    await _tasksBox.delete(localId);
  }

  Future<void> replaceTasks(List<TaskItem> tasks) async {
    await _tasksBox.clear();
    if (tasks.isEmpty) {
      return;
    }

    final entries = <String, Map<String, dynamic>>{
      for (final task in tasks) task.localId: task.toJson(),
    };
    await _tasksBox.putAll(entries);
  }

  Future<void> cacheRemoteTasks(List<TaskItem> remote) async {
    final localDrafts = _tasksBox.keys
        .whereType<String>()
        .where((key) => key.startsWith('local-'))
        .toSet();

    final keysToRemove = _tasksBox.keys
        .whereType<String>()
        .where((key) => !localDrafts.contains(key))
        .toList(growable: false);

    if (keysToRemove.isNotEmpty) {
      await _tasksBox.deleteAll(keysToRemove);
    }

    for (final task in remote) {
      await _tasksBox.put(task.localId, task.toJson());
    }
  }

  List<PendingTaskOperation> getPendingOperations() {
    return _pendingBox.values
        .map((raw) => PendingTaskOperation.fromJson(
              Map<String, dynamic>.from(raw),
            ))
        .toList(growable: false);
  }

  PendingTaskOperation? getPendingOperation(
    String localId,
    PendingTaskOperationType type,
  ) {
    for (final raw in _pendingBox.values) {
      final entry = PendingTaskOperation.fromJson(
        Map<String, dynamic>.from(raw),
      );
      if (entry.localId == localId && entry.type == type) {
        return entry;
      }
    }
    return null;
  }

  Future<void> savePendingOperation(PendingTaskOperation operation) async {
    await _pendingBox.put(operation.id, operation.toJson());
  }

  Future<void> removePendingOperation(String id) async {
    await _pendingBox.delete(id);
  }

  bool get hasPendingOperations => _pendingBox.isNotEmpty;

  Future<void> clearPendingOperations() async {
    await _pendingBox.clear();
  }

  List<TaskAttachment> getCachedAttachments() {
    return _attachmentsBox.values
        .map((raw) => TaskAttachment.fromApi(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<void> saveTaskAttachments(List<TaskAttachment> attachments) async {
    if (attachments.isEmpty) {
      return;
    }

    final entries = <String, Map<String, dynamic>>{
      for (final attachment in attachments) attachment.id: attachment.toJson(),
    };
    await _attachmentsBox.putAll(entries);
  }

  Future<void> removeAttachmentsForTask(String taskId) async {
    final keysToRemove = <dynamic>[];
    for (final entry in _attachmentsBox.toMap().entries) {
      final attachment = TaskAttachment.fromApi(
        Map<String, dynamic>.from(entry.value),
      );
      if (attachment.taskId == taskId) {
        keysToRemove.add(entry.key);
      }
    }

    if (keysToRemove.isEmpty) {
      return;
    }

    await _attachmentsBox.deleteAll(keysToRemove);
  }

  Future<void> replaceAttachments(List<TaskAttachment> attachments) async {
    await _attachmentsBox.clear();
    await saveTaskAttachments(attachments);
  }

  Future<void> cacheProfile(UserProfile profile) async {
    await _profileBox.put('profile', profile.toJson());
  }

  UserProfile? getCachedProfile() {
    final raw = _profileBox.get('profile');
    if (raw is Map) {
      try {
        return UserProfile.fromApi(Map<String, dynamic>.from(raw));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> clear() async {
    await _tasksBox.clear();
    await _pendingBox.clear();
    await _profileBox.clear();
    await _attachmentsBox.clear();
  }
}
