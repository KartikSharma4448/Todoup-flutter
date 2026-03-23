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

  Future<void> init() => _localDatabase.init();

  List<TaskItem> get cachedTasks => _localDatabase.getCachedTasks();
  bool get hasPendingOperations => _localDatabase.hasPendingOperations;
  UserProfile? get cachedProfile => _localDatabase.getCachedProfile();

  Future<void> cacheProfile(UserProfile profile) async {
    await _localDatabase.cacheProfile(profile);
  }

  Future<List<TaskItem>> refreshRemoteTasks() async {
    final remoteTasks = await _supabaseService.getTasks();
    await _localDatabase.cacheRemoteTasks(remoteTasks);
    return remoteTasks;
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
      syncStatus: TaskSyncStatus.pending,
    );

    await _localDatabase.upsertTask(task);
    await _queuePendingOperation(task, PendingTaskOperationType.create);
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
      syncStatus: TaskSyncStatus.pending,
    );

    await _localDatabase.upsertTask(updated);
    await _queuePendingOperation(updated, PendingTaskOperationType.update);
    return updated;
  }

  Future<void> deleteTask(String taskId) async {
    final task = _localDatabase.getTaskById(taskId);
    if (task == null) {
      return;
    }

    await _localDatabase.removeTask(task.localId);

    final pendingCreate = _localDatabase.getPendingOperation(
      task.localId,
      PendingTaskOperationType.create,
    );
    if (pendingCreate != null) {
      await _localDatabase.removePendingOperation(pendingCreate.id);
      return;
    }

    final deleteOp = PendingTaskOperation(
      id: 'op-${_uuid.v4()}',
      type: PendingTaskOperationType.delete,
      localId: task.localId,
      serverId: task.serverId,
      payload: {},
    );

    await _localDatabase.savePendingOperation(deleteOp);
  }

  Future<bool> syncPending() async {
    final operations = _localDatabase.getPendingOperations();
    if (operations.isEmpty) {
      return false;
    }

    var synced = false;

    for (final operation in operations) {
      switch (operation.type) {
        case PendingTaskOperationType.create:
          final created = await _supabaseService.createTask(operation.payload);
          await _localDatabase.removeTask(operation.localId);
          await _localDatabase.removePendingOperation(operation.id);
          await _localDatabase.upsertTask(
            created.copyWith(
              localId: created.id,
              serverId: created.id,
              syncStatus: TaskSyncStatus.synced,
            ),
          );
          synced = true;
          break;
        case PendingTaskOperationType.update:
          final serverId = operation.serverId ?? operation.payload['id']?.toString();
          if (serverId == null) {
            await _localDatabase.removePendingOperation(operation.id);
            continue;
          }
          await _supabaseService.updateTask(serverId, operation.payload);
          final stored = _localDatabase.getTaskByLocalId(operation.localId);
          if (stored != null) {
            await _localDatabase.upsertTask(stored.copyWith(
              serverId: serverId,
              syncStatus: TaskSyncStatus.synced,
              updatedAt: DateTime.now(),
            ));
          }
          await _localDatabase.removePendingOperation(operation.id);
          synced = true;
          break;
        case PendingTaskOperationType.delete:
          if (operation.serverId != null) {
            await _supabaseService.deleteTask(operation.serverId!);
          }
          await _localDatabase.removeTask(operation.localId);
          await _localDatabase.removePendingOperation(operation.id);
          synced = true;
          break;
      }
    }

    if (synced) {
      final remoteTasks = await _supabaseService.getTasks();
      await _localDatabase.cacheRemoteTasks(remoteTasks);
    }

    return synced;
  }

  Future<List<TaskAttachment>> uploadAttachments(
    String taskId,
    List<PendingTaskAttachment> attachments,
  ) {
    return _supabaseService.uploadTaskAttachments(taskId, attachments);
  }

  Future<void> _queuePendingOperation(
    TaskItem task,
    PendingTaskOperationType type,
  ) async {
    if (type == PendingTaskOperationType.create) {
      final existing = _localDatabase.getPendingOperation(task.localId, type);
      final operation = existing?.copyWith(
            payload: task.toPayload(),
            localId: task.localId,
          ) ??
          PendingTaskOperation(
            id: 'op-${_uuid.v4()}',
            type: PendingTaskOperationType.create,
            localId: task.localId,
            payload: task.toPayload(),
          );
      await _localDatabase.savePendingOperation(operation);
      return;
    }

    if (task.serverId == null) {
      final createOp = _localDatabase.getPendingOperation(
        task.localId,
        PendingTaskOperationType.create,
      );
      if (createOp != null) {
        await _localDatabase.savePendingOperation(
          createOp.copyWith(payload: task.toPayload()),
        );
        return;
      }
    }

    final existing = _localDatabase.getPendingOperation(task.localId, type);
    final operation = existing?.copyWith(
          payload: task.toPayload(),
          serverId: task.serverId,
        ) ??
        PendingTaskOperation(
          id: 'op-${_uuid.v4()}',
          type: type,
          localId: task.localId,
          serverId: task.serverId,
          payload: task.toPayload(),
        );
    await _localDatabase.savePendingOperation(operation);
  }
}
