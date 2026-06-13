import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import 'local_database_service.dart';
import 'supabase_service.dart';

class TaskRepository {
  TaskRepository({
    LocalDatabaseService? localDatabase,
    SupabaseService? supabaseService,
    Uuid? uuid,
  })  : _localDatabase = localDatabase ?? LocalDatabaseService.instance,
        _supabaseService = supabaseService ?? SupabaseService(),
        _uuid = uuid ?? const Uuid();

  final LocalDatabaseService _localDatabase;
  final SupabaseService _supabaseService;
  final Uuid _uuid;

  Future<void> init() async {
    await _localDatabase.init();
    await _localDatabase.clearPendingOperations();
  }

  List<TaskItem> get cachedTasks => _localDatabase.getCachedTasks();
  List<TaskAttachment> get cachedAttachments =>
      _localDatabase.getCachedAttachments();
  bool get hasPendingOperations => false;
  UserProfile? get cachedProfile => _localDatabase.getCachedProfile();

  Future<void> cacheProfile(UserProfile profile) async {
    await _localDatabase.cacheProfile(profile);
  }

  Future<TaskItem> addTask({
    required String title,
    required String description,
    required DateTime dueDate,
    required TimeOfDay dueTime,
    required TaskPriority priority,
    required TaskCategory category,
    required bool reminder,
    required String repeat,
    required List<String> subtasks,
  }) async {
    final now = DateTime.now();
    final normalizedDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final task = TaskItem(
      localId: 'local-${_uuid.v4()}',
      title: title.trim(),
      completed: false,
      dueDate: normalizedDate,
      dueLabel: buildRelativeDueLabel(normalizedDate),
      priority: priority,
      category: category,
      description: description.trim().isEmpty ? null : description.trim(),
      reminder: reminder,
      repeat: repeat,
      subtasks: subtasks,
      completedSubtasks: 0,
      dueTime: dueTime,
      createdAt: now,
      updatedAt: now,
      syncStatus: TaskSyncStatus.synced,
    );

    await _localDatabase.upsertTask(task);
    return task;
  }

  Future<TaskItem?> toggleTaskCompletion(String taskId) async {
    final task = _localDatabase.getTaskById(taskId);
    if (task == null) {
      return null;
    }

    final updated = task.copyWith(
      completed: !task.completed,
      completedAt: !task.completed ? DateTime.now() : null,
      updatedAt: DateTime.now(),
      syncStatus: TaskSyncStatus.synced,
    );

    await _localDatabase.upsertTask(updated);
    return updated;
  }

  Future<void> deleteTask(String taskId) async {
    final task = _localDatabase.getTaskById(taskId);
    if (task == null) {
      return;
    }

    await _localDatabase.removeTask(task.localId);
    await _localDatabase.removeAttachmentsForTask(task.id);
  }

  Future<bool> syncPending() async {
    await _localDatabase.clearPendingOperations();
    return false;
  }

  Future<List<TaskAttachment>> uploadAttachments(
    String taskId,
    List<PendingTaskAttachment> attachments,
  ) async {
    final timestamp = DateTime.now();
    return List<TaskAttachment>.generate(attachments.length, (index) {
      final attachment = attachments[index];
      return TaskAttachment(
        id: 'local-attachment-${_uuid.v4()}',
        taskId: taskId,
        storagePath: '',
        fileName: attachment.fileName,
        mimeType: attachment.mimeType,
        sizeBytes: attachment.sizeBytes,
        createdAt: timestamp,
      );
    }, growable: false);
  }

  Future<void> saveLocalAttachments(List<TaskAttachment> attachments) {
    return _localDatabase.saveTaskAttachments(attachments);
  }

  Future<void> replaceLocalSnapshot({
    required List<TaskItem> tasks,
    List<TaskAttachment> attachments = const [],
  }) async {
    await _localDatabase.replaceTasks(tasks);
    await _localDatabase.replaceAttachments(attachments);
  }

  Future<int> uploadTasksBackup() async {
    final tasks = cachedTasks;
    await _supabaseService.replaceCloudTasks(tasks);
    return tasks.length;
  }

  Future<List<TaskItem>> restoreTasksBackup() {
    return _supabaseService.getTasks();
  }
}
