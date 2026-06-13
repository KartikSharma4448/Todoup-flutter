import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  final store = JsonStore(Directory.current.path);
  await store.load();

  final assistant = OpenRouterAssistant.fromEnvironment();
  final assistantSecurity = AssistantSecurity.fromEnvironment();
  final api = TodoApi(
    store,
    assistant: assistant,
    assistantSecurity: assistantSecurity,
  );
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addHandler(api.router.call);

  final port = int.tryParse(Platform.environment['PORT'] ?? '4000') ?? 4000;
  final server = await io.serve(
    handler,
    InternetAddress.anyIPv4,
    port,
    shared: true,
  );

  stdout.writeln(
    'ToDoUp backend listening on http://${server.address.address}:$port (${assistant.providerLabel}, ${assistantSecurity.modeLabel})',
  );
}

Middleware _cors() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  };

  return createMiddleware(
    requestHandler: (request) {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }
      return null;
    },
    responseHandler: (response) {
      return response.change(
        headers: {
          ...response.headers,
          ...headers,
        },
      );
    },
  );
}

class TodoApi {
  TodoApi(
    this._store, {
    OpenRouterAssistant? assistant,
    AssistantSecurity? assistantSecurity,
  })  : _assistant = assistant ?? OpenRouterAssistant.fromEnvironment(),
        _assistantSecurity =
            assistantSecurity ?? AssistantSecurity.fromEnvironment() {
    _router
      ..get('/health', (request) => _guard(() => _health(request)))
      ..post('/auth/register', (request) => _guard(() => _register(request)))
      ..post('/auth/login', (request) => _guard(() => _login(request)))
      ..get('/users/profile', (request) => _guard(() => _getProfile(request)))
      ..put(
          '/users/profile', (request) => _guard(() => _updateProfile(request)))
      ..delete(
        '/users/profile',
        (request) => _guard(() => _deleteProfile(request)),
      )
      ..get('/tasks', (request) => _guard(() => _getTasks(request)))
      ..post('/tasks', (request) => _guard(() => _createTask(request)))
      ..put('/tasks/<taskId>', (request, taskId) {
        return _guard(() => _updateTask(request, taskId));
      })
      ..delete('/tasks/<taskId>', (request, taskId) {
        return _guard(() => _deleteTask(request, taskId));
      })
      ..get(
        '/assistant/messages',
        (request) => _guard(() => _getAssistantMessages(request)),
      )
      ..post('/assistant/draft',
          (request) => _guard(() => _assistantDraft(request)))
      ..delete(
        '/assistant/messages',
        (request) => _guard(() => _resetAssistantMessages(request)),
      )
      ..put('/assistant/messages/<messageId>', (request, messageId) {
        return _guard(() => _updateAssistantMessage(request, messageId));
      })
      ..post('/assistant/chat',
          (request) => _guard(() => _assistantChat(request)));
  }

  final JsonStore _store;
  final OpenRouterAssistant _assistant;
  final AssistantSecurity _assistantSecurity;
  final Router _router = Router();
  final Uuid _uuid = const Uuid();

  Router get router => _router;

  Future<Response> _guard(Future<Response> Function() action) async {
    try {
      return await action();
    } on ApiException catch (error) {
      return _json(error.statusCode, {'error': error.message});
    } on FormatException catch (error) {
      return _json(400, {'error': error.message});
    } catch (error, stackTrace) {
      stderr
        ..writeln(error)
        ..writeln(stackTrace);
      return _json(500, {'error': 'Internal server error'});
    }
  }

  Future<Response> _health(Request request) async {
    return _json(200, {
      'status': 'ok',
      'timestamp': DateTime.now().toIso8601String(),
      'users': _store.users.length,
      'tasks': _store.tasks.length,
      'assistantProvider': _assistant.providerLabel,
      'assistantConfigured': _assistant.isConfigured,
      'assistantSecurity': _assistantSecurity.modeLabel,
      'assistantRateLimitMaxRequests': _assistantSecurity.maxRequests,
      'assistantRateLimitWindowSeconds':
          _assistantSecurity.window.inSeconds,
    });
  }

  Future<Response> _register(Request request) async {
    final body = await _readBody(request);
    final name = body['name']?.toString().trim() ?? '';
    final email = body['email']?.toString().trim().toLowerCase() ?? '';
    final password = body['password']?.toString() ?? '';

    if (name.isEmpty) {
      throw const ApiException(400, 'Name is required.');
    }
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      throw const ApiException(400, 'A valid email address is required.');
    }
    if (password.length < 8) {
      throw const ApiException(400, 'Password must be at least 8 characters.');
    }

    final existing = _findUserByEmail(email);
    if (existing != null) {
      throw const ApiException(
          409, 'An account with this email already exists.');
    }

    final now = DateTime.now().toIso8601String();
    final userId = _uuid.v4();
    final user = <String, dynamic>{
      'id': userId,
      'name': name,
      'email': email,
      'passwordHash': _hashPassword(password),
      'phone': body['phone']?.toString() ?? '',
      'location': body['location']?.toString() ?? '',
      'occupation': body['occupation']?.toString() ?? '',
      'bio': body['bio']?.toString() ?? '',
      'createdAt': now,
      'updatedAt': now,
    };

    _store.users.add(user);
    _seedStarterTasks(userId);

    final token = _uuid.v4();
    _store.sessions[token] = userId;
    await _store.save();

    return _json(201, {
      'token': token,
      'user': _publicUser(user),
    });
  }

  Future<Response> _login(Request request) async {
    final body = await _readBody(request);
    final email = body['email']?.toString().trim().toLowerCase() ?? '';
    final password = body['password']?.toString() ?? '';

    final user = _findUserByEmail(email);
    if (user == null || user['passwordHash'] != _hashPassword(password)) {
      throw const ApiException(401, 'Invalid email or password.');
    }

    final token = _uuid.v4();
    _store.sessions[token] = user['id'];
    await _store.save();

    return _json(200, {
      'token': token,
      'user': _publicUser(user),
    });
  }

  Future<Response> _getProfile(Request request) async {
    final user = _requireUser(request);
    return _json(200, _publicUser(user));
  }

  Future<Response> _updateProfile(Request request) async {
    final user = _requireUser(request);
    final body = await _readBody(request);
    final email = body['email']?.toString().trim().toLowerCase() ?? '';

    if (email.isNotEmpty) {
      final existing = _findUserByEmail(email);
      if (existing != null && existing['id'] != user['id']) {
        throw const ApiException(
            409, 'Another account already uses this email.');
      }
      user['email'] = email;
    }

    user['name'] = body['name']?.toString().trim() ?? user['name'];
    user['phone'] = body['phone']?.toString() ?? user['phone'];
    user['location'] = body['location']?.toString() ?? user['location'];
    user['occupation'] = body['occupation']?.toString() ?? user['occupation'];
    user['bio'] = body['bio']?.toString() ?? user['bio'];
    user['updatedAt'] = DateTime.now().toIso8601String();

    await _store.save();
    return _json(200, _publicUser(user));
  }

  Future<Response> _deleteProfile(Request request) async {
    final user = _requireUser(request);
    final userId = user['id']?.toString();
    if (userId == null) {
      throw const ApiException(401, 'Unauthorized.');
    }

    _store.users.removeWhere((item) => item['id'] == userId);
    _store.tasks.removeWhere((item) => item['userId'] == userId);
    _store.assistantMessages.removeWhere((item) => item['userId'] == userId);
    _store.sessions.removeWhere((_, value) => value == userId);
    await _store.save();

    return Response(204);
  }

  Future<Response> _getTasks(Request request) async {
    final user = _requireUser(request);
    final userId = user['id']?.toString();
    final tasks = _store.tasks
        .where((task) => task['userId'] == userId)
        .map(_publicTask)
        .toList(growable: false)
      ..sort(_compareTasks);

    return _json(200, tasks);
  }

  Future<Response> _createTask(Request request) async {
    final user = _requireUser(request);
    final body = await _readBody(request);
    final task = _buildTask(
      body,
      userId: user['id']!.toString(),
      taskId: _uuid.v4(),
      createdAt: DateTime.now().toIso8601String(),
      existing: null,
    );

    _store.tasks.add(task);
    await _store.save();
    return _json(201, _publicTask(task));
  }

  Future<Response> _updateTask(Request request, String taskId) async {
    final user = _requireUser(request);
    final task = _findOwnedTask(taskId, user['id']!.toString());
    final body = await _readBody(request);
    final updated = _buildTask(
      body,
      userId: user['id']!.toString(),
      taskId: taskId,
      createdAt:
          task['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      existing: task,
    );

    task
      ..clear()
      ..addAll(updated);

    await _store.save();
    return _json(200, _publicTask(task));
  }

  Future<Response> _deleteTask(Request request, String taskId) async {
    final user = _requireUser(request);
    final userId = user['id']!.toString();
    final removed = _store.tasks.removeWhereAndReturn(
      (task) => task['id'] == taskId && task['userId'] == userId,
    );
    if (!removed) {
      throw const ApiException(404, 'Task not found.');
    }

    await _store.save();
    return Response(204);
  }

  Future<Response> _getAssistantMessages(Request request) async {
    final user = _requireUser(request);
    final userId = user['id']!.toString();
    final messages = _store.assistantMessages
        .where((message) => message['userId'] == userId)
        .map(_publicAssistantMessage)
        .toList(growable: false)
      ..sort((left, right) {
        final leftTime =
            DateTime.tryParse(left['createdAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
        final rightTime =
            DateTime.tryParse(right['createdAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
        return leftTime.compareTo(rightTime);
      });

    if (messages.isEmpty) {
      return _json(200, [_assistantIntro()]);
    }

    return _json(200, messages);
  }

  Future<Response> _resetAssistantMessages(Request request) async {
    final user = _requireUser(request);
    final userId = user['id']!.toString();
    _store.assistantMessages
        .removeWhere((message) => message['userId'] == userId);
    await _store.save();
    return Response(204);
  }

  Future<Response> _updateAssistantMessage(
    Request request,
    String messageId,
  ) async {
    final user = _requireUser(request);
    final userId = user['id']!.toString();
    final message = _store.assistantMessages.firstWhere(
      (item) => item['id'] == messageId && item['userId'] == userId,
      orElse: () =>
          throw const ApiException(404, 'Assistant message not found.'),
    );

    final body = await _readBody(request);
    if (body.containsKey('content')) {
      message['content'] = body['content']?.toString() ?? message['content'];
    }
    if (body.containsKey('confirmed')) {
      message['confirmed'] = body['confirmed'] == true;
    }
    if (body['preview'] is Map<String, dynamic>) {
      message['preview'] = _sanitizePreview(
        body['preview'] as Map<String, dynamic>,
      );
    }
    message['updatedAt'] = DateTime.now().toIso8601String();

    await _store.save();
    return _json(200, _publicAssistantMessage(message));
  }

  Future<Response> _assistantChat(Request request) async {
    final user = _requireUser(request);
    final userId = user['id']!.toString();
    final body = await _readBody(request);
    final prompt = body['message']?.toString().trim() ?? '';

    if (prompt.isEmpty) {
      throw const ApiException(400, 'Message is required.');
    }

    final timestamp = DateTime.now().toIso8601String();
    final userMessage = <String, dynamic>{
      'id': _uuid.v4(),
      'userId': userId,
      'role': 'user',
      'content': prompt,
      'confirmed': false,
      'createdAt': timestamp,
    };

    final draft = await _buildAssistantDraft(prompt);
    final assistantMessage = <String, dynamic>{
      'id': _uuid.v4(),
      'userId': userId,
      'role': 'assistant',
      'content': draft.message,
      'preview': draft.preview,
      'confirmed': false,
      'createdAt': timestamp,
    };

    _store.assistantMessages
      ..add(userMessage)
      ..add(assistantMessage);
    await _store.save();

    return _json(200, _publicAssistantMessage(assistantMessage));
  }

  Future<Response> _assistantDraft(Request request) async {
    _assistantSecurity.authorize(request);
    final body = await _readBody(request);
    final prompt = body['message']?.toString().trim() ?? '';

    if (prompt.isEmpty) {
      throw const ApiException(400, 'Message is required.');
    }

    final draft = await _buildAssistantDraft(prompt);
    return _json(200, {
      'content': draft.message,
      'preview': draft.preview,
      'provider': _assistant.providerLabel,
    });
  }

  Future<AssistantDraft> _buildAssistantDraft(String prompt) async {
    final fallback = _fallbackAssistantDraft(prompt);
    if (!_assistant.isConfigured) {
      return fallback;
    }

    try {
      final draft = await _assistant.generateTaskDraft(prompt);
      final mergedPreview = {
        ...fallback.preview,
        ...draft.preview,
      };

      return AssistantDraft(
        message:
            draft.message.trim().isEmpty ? fallback.message : draft.message,
        preview: _sanitizePreview({
          ...mergedPreview,
          'title': draft.preview['title']?.toString().trim().isNotEmpty == true
              ? draft.preview['title']
              : fallback.preview['title'],
        }),
      );
    } catch (error, stackTrace) {
      stderr
        ..writeln('OpenRouter assistant failed, using heuristic fallback.')
        ..writeln(error)
        ..writeln(stackTrace);
      return fallback;
    }
  }

  AssistantDraft _fallbackAssistantDraft(String prompt) {
    return AssistantDraft(
      message:
          "I've created a task draft for you. Confirm it if it looks right.",
      preview: _buildAssistantPreview(prompt),
    );
  }

  Map<String, dynamic> _buildTask(
    Map<String, dynamic> body, {
    required String userId,
    required String taskId,
    required String createdAt,
    required Map<String, dynamic>? existing,
  }) {
    final title = body.containsKey('title')
        ? body['title']?.toString().trim() ?? ''
        : existing?['title']?.toString() ?? '';
    if (title.isEmpty) {
      throw const ApiException(400, 'Task title is required.');
    }

    final dueDate = _normalizeDate(
      body.containsKey('dueDate') ? body['dueDate'] : existing?['dueDate'],
    );
    final subtasks = _normalizeStringList(
      body.containsKey('subtasks') ? body['subtasks'] : existing?['subtasks'],
    );

    final completedSubtasks = _normalizeCompletedSubtasks(
      body.containsKey('completedSubtasks')
          ? body['completedSubtasks']
          : existing?['completedSubtasks'],
      subtasks.length,
    );

    final completed = body.containsKey('completed')
        ? body['completed'] == true
        : existing?['completed'] == true;
    final explicitCompletedAt = body.containsKey('completedAt')
        ? body['completedAt']?.toString()
        : existing?['completedAt']?.toString();

    return {
      'id': taskId,
      'userId': userId,
      'title': title,
      'description': body.containsKey('description')
          ? body['description']?.toString() ?? ''
          : existing?['description']?.toString() ?? '',
      'completed': completed,
      'dueDate': _formatDate(dueDate),
      'dueLabel': _relativeDueLabel(dueDate),
      'priority': _normalizePriority(
        body.containsKey('priority') ? body['priority'] : existing?['priority'],
      ),
      'category': _normalizeCategory(
        body.containsKey('category') ? body['category'] : existing?['category'],
      ),
      'reminder': body.containsKey('reminder')
          ? body['reminder'] == true
          : existing?['reminder'] == true,
      'repeat': body.containsKey('repeat')
          ? body['repeat']?.toString() ?? 'None'
          : existing?['repeat']?.toString() ?? 'None',
      'subtasks': subtasks,
      'completedSubtasks': completedSubtasks,
      'dueTime': _normalizeTime(
        body.containsKey('dueTime') ? body['dueTime'] : existing?['dueTime'],
      ),
      'completedAt': completed
          ? (explicitCompletedAt == null || explicitCompletedAt.isEmpty
              ? DateTime.now().toIso8601String()
              : explicitCompletedAt)
          : null,
      'createdAt': createdAt,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  void _seedStarterTasks(String userId) {
    final now = DateTime.now();
    final templates = [
      {
        'title': 'Plan your top three priorities',
        'description': 'Define what matters most for today.',
        'dueDate': now,
        'dueTime': '09:00',
        'priority': 'high',
        'category': 'work',
      },
      {
        'title': 'Review personal errands',
        'description': 'Group your quick wins for the evening.',
        'dueDate': now.add(const Duration(days: 1)),
        'dueTime': '18:30',
        'priority': 'medium',
        'category': 'personal',
      },
      {
        'title': 'Weekly reflection',
        'description': 'Capture what worked and what to improve.',
        'dueDate': now.add(const Duration(days: 2)),
        'dueTime': '20:00',
        'priority': 'low',
        'category': 'others',
      },
    ];

    for (final template in templates) {
      _store.tasks.add({
        'id': _uuid.v4(),
        'userId': userId,
        'title': template['title'],
        'description': template['description'],
        'completed': false,
        'dueDate': _formatDate(template['dueDate']! as DateTime),
        'dueLabel': _relativeDueLabel(template['dueDate']! as DateTime),
        'priority': template['priority'],
        'category': template['category'],
        'reminder': true,
        'repeat': 'None',
        'subtasks': const [],
        'completedSubtasks': 0,
        'dueTime': template['dueTime'],
        'completedAt': null,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Map<String, dynamic> _buildAssistantPreview(String prompt) {
    final lowered = prompt.toLowerCase();
    final dueDate = lowered.contains('today')
        ? DateUtils.dateOnly(DateTime.now())
        : DateUtils.dateOnly(DateTime.now().add(const Duration(days: 1)));
    final timeValue = _extractTimeValue(lowered);

    final priority = lowered.contains('urgent') || lowered.contains('asap')
        ? 'high'
        : lowered.contains('later') || lowered.contains('someday')
            ? 'low'
            : 'medium';

    final category = () {
      if (lowered.contains('gym') || lowered.contains('workout')) {
        return 'health';
      }
      if (lowered.contains('study') || lowered.contains('exam')) {
        return 'study';
      }
      if (lowered.contains('buy') || lowered.contains('grocer')) {
        return 'shopping';
      }
      if (lowered.contains('meeting') || lowered.contains('project')) {
        return 'work';
      }
      return 'personal';
    }();

    return {
      'title': _shortTitle(prompt),
      'dateLabel': _relativeDueLabel(dueDate),
      'dateValue': dueDate.toIso8601String(),
      'timeLabel': _displayTime(timeValue),
      'timeValue': timeValue,
      'priority': priority,
      'category': category,
    };
  }

  Map<String, dynamic> _sanitizePreview(Map<String, dynamic> preview) {
    final date = _normalizeDate(preview['dateValue']);
    final timeValue = _normalizeTime(preview['timeValue']);
    return {
      'title': preview['title']?.toString().trim() ?? '',
      'dateLabel': preview['dateLabel']?.toString() ?? _relativeDueLabel(date),
      'dateValue': preview['dateValue']?.toString() ?? date.toIso8601String(),
      'timeLabel': preview['timeLabel']?.toString() ?? _displayTime(timeValue),
      'timeValue': timeValue,
      'priority': _normalizePriority(preview['priority']),
      'category': _normalizeCategory(preview['category']),
    };
  }

  Map<String, dynamic>? _findUserByEmail(String email) {
    for (final user in _store.users) {
      if (user['email']?.toString().toLowerCase() == email) {
        return user;
      }
    }
    return null;
  }

  Map<String, dynamic> _findOwnedTask(String taskId, String userId) {
    return _store.tasks.firstWhere(
      (task) => task['id'] == taskId && task['userId'] == userId,
      orElse: () => throw const ApiException(404, 'Task not found.'),
    );
  }

  Map<String, dynamic> _requireUser(Request request) {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      throw const ApiException(401, 'Unauthorized.');
    }

    final token = authHeader.substring('Bearer '.length).trim();
    final userId = _store.sessions[token]?.toString();
    if (userId == null) {
      throw const ApiException(401, 'Unauthorized.');
    }

    return _store.users.firstWhere(
      (user) => user['id'] == userId,
      orElse: () => throw const ApiException(401, 'Unauthorized.'),
    );
  }

  Future<Map<String, dynamic>> _readBody(Request request) async {
    final raw = await request.readAsString();
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Request body must be a JSON object.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  Map<String, dynamic> _publicUser(Map<String, dynamic> user) {
    return {
      'id': user['id'],
      'name': user['name'],
      'email': user['email'],
      'phone': user['phone'] ?? '',
      'location': user['location'] ?? '',
      'occupation': user['occupation'] ?? '',
      'bio': user['bio'] ?? '',
    };
  }

  Map<String, dynamic> _publicTask(Map<String, dynamic> task) {
    return {
      'id': task['id'],
      'title': task['title'],
      'description': task['description'],
      'completed': task['completed'] == true,
      'dueDate': task['dueDate'],
      'dueLabel': task['dueLabel'],
      'priority': task['priority'],
      'category': task['category'],
      'reminder': task['reminder'] == true,
      'repeat': task['repeat'],
      'subtasks': task['subtasks'],
      'completedSubtasks': task['completedSubtasks'],
      'dueTime': task['dueTime'],
      'completedAt': task['completedAt'],
      'createdAt': task['createdAt'],
      'updatedAt': task['updatedAt'],
    };
  }

  Map<String, dynamic> _publicAssistantMessage(Map<String, dynamic> message) {
    return {
      'id': message['id'],
      'role': message['role'],
      'content': message['content'],
      'preview': message['preview'],
      'confirmed': message['confirmed'] == true,
      'createdAt': message['createdAt'],
    };
  }

  Map<String, dynamic> _assistantIntro() {
    return {
      'id': 'assistant-intro',
      'role': 'assistant',
      'content':
          "Hi! I'm your AI assistant. Tell me what you need to do and I'll turn it into a task.",
      'confirmed': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  int _compareTasks(Map<String, dynamic> left, Map<String, dynamic> right) {
    final leftCompleted = left['completed'] == true;
    final rightCompleted = right['completed'] == true;
    if (leftCompleted != rightCompleted) {
      return leftCompleted ? 1 : -1;
    }

    final leftDate =
        DateTime.tryParse(left['dueDate']?.toString() ?? '') ?? DateTime.now();
    final rightDate =
        DateTime.tryParse(right['dueDate']?.toString() ?? '') ?? DateTime.now();
    return leftDate.compareTo(rightDate);
  }

  String _normalizePriority(Object? value) {
    switch (value?.toString()) {
      case 'low':
      case 'medium':
      case 'high':
        return value!.toString();
      default:
        return 'medium';
    }
  }

  String _normalizeCategory(Object? value) {
    switch (value?.toString()) {
      case 'work':
      case 'personal':
      case 'health':
      case 'study':
      case 'shopping':
      case 'others':
        return value!.toString();
      default:
        return 'personal';
    }
  }

  DateTime _normalizeDate(Object? value) {
    final raw = value?.toString();
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (parsed == null) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String _normalizeTime(Object? value) {
    final raw = value?.toString() ?? '';
    final parts = raw.split(':');
    if (parts.length != 2) {
      return '09:00';
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return '09:00';
    }

    final safeHour = hour.clamp(0, 23);
    final safeMinute = minute.clamp(0, 59);
    return '${safeHour.toString().padLeft(2, '0')}:${safeMinute.toString().padLeft(2, '0')}';
  }

  List<String> _normalizeStringList(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  int _normalizeCompletedSubtasks(Object? value, int subtaskCount) {
    final parsed =
        value is num ? value.toInt() : int.tryParse('${value ?? ''}');
    if (parsed == null) {
      return 0;
    }

    return parsed.clamp(0, subtaskCount);
  }

  String _extractTimeValue(String text) {
    final match = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)').firstMatch(text);
    if (match == null) {
      return '19:00';
    }

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2) ?? '00');
    final meridiem = match.group(3)!;

    if (meridiem == 'pm' && hour != 12) {
      hour += 12;
    } else if (meridiem == 'am' && hour == 12) {
      hour = 0;
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _displayTime(String timeValue) {
    final parts = timeValue.split(':');
    if (parts.length != 2) {
      return '7:00 PM';
    }

    final hour = int.tryParse(parts[0]) ?? 19;
    final minute = int.tryParse(parts[1]) ?? 0;
    final isPm = hour >= 12;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final displayMinute = minute.toString().padLeft(2, '0');
    final period = isPm ? 'PM' : 'AM';
    return '$displayHour:$displayMinute $period';
  }

  String _shortTitle(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.length <= 48) {
      return trimmed;
    }
    return '${trimmed.substring(0, 45)}...';
  }

  String _hashPassword(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  String _formatDate(DateTime date) {
    return date.toIso8601String().split('T').first;
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
}

class JsonStore {
  JsonStore(String rootPath)
      : _file = File(path.join(rootPath, 'data', 'store.json'));

  final File _file;
  Map<String, dynamic> _document = {
    'users': <Map<String, dynamic>>[],
    'tasks': <Map<String, dynamic>>[],
    'assistantMessages': <Map<String, dynamic>>[],
    'sessions': <String, dynamic>{},
  };

  List<Map<String, dynamic>> get users =>
      (_document['users'] as List).cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get tasks =>
      (_document['tasks'] as List).cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get assistantMessages =>
      (_document['assistantMessages'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> get sessions =>
      (_document['sessions'] as Map).cast<String, dynamic>();

  Future<void> load() async {
    await _file.parent.create(recursive: true);
    if (await _file.exists()) {
      final raw = await _file.readAsString();
      if (raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _document = Map<String, dynamic>.from(decoded);
        }
      }
    } else {
      await save();
    }

    _document = {
      'users': (_document['users'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      'tasks': (_document['tasks'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      'assistantMessages': (_document['assistantMessages'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      'sessions': Map<String, dynamic>.from(
        (_document['sessions'] as Map?) ?? const {},
      ),
    };
  }

  Future<void> save() async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_document),
    );
  }
}

class AssistantDraft {
  const AssistantDraft({
    required this.message,
    required this.preview,
  });

  final String message;
  final Map<String, dynamic> preview;
}

class AssistantSecurity {
  AssistantSecurity({
    required this.jwtSecret,
    required this.jwtAudience,
    required this.window,
    required this.maxRequests,
  });

  factory AssistantSecurity.fromEnvironment() {
    final windowSeconds =
        int.tryParse(
          Platform.environment['ASSISTANT_RATE_LIMIT_WINDOW_SECONDS'] ?? '',
        ) ??
        60;
    final maxRequests =
        int.tryParse(
          Platform.environment['ASSISTANT_RATE_LIMIT_MAX_REQUESTS'] ?? '',
        ) ??
        20;

    return AssistantSecurity(
      jwtSecret: Platform.environment['SUPABASE_JWT_SECRET'] ?? '',
      jwtAudience: Platform.environment['SUPABASE_JWT_AUD'] ?? 'authenticated',
      window: Duration(seconds: windowSeconds.clamp(10, 3600)),
      maxRequests: maxRequests.clamp(1, 500),
    );
  }

  final String jwtSecret;
  final String jwtAudience;
  final Duration window;
  final int maxRequests;
  final Map<String, List<DateTime>> _requestsByIdentity =
      <String, List<DateTime>>{};

  bool get requiresSupabaseJwt => jwtSecret.trim().isNotEmpty;
  String get modeLabel =>
      requiresSupabaseJwt ? 'supabase-jwt+rate-limit' : 'rate-limit';

  void authorize(Request request) {
    final identity = requiresSupabaseJwt
        ? _validateSupabaseJwt(request)
        : 'ip:${_clientAddress(request)}';
    _applyRateLimit(identity);
  }

  String _validateSupabaseJwt(Request request) {
    final authHeader = request.headers[HttpHeaders.authorizationHeader];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      throw const ApiException(401, 'Missing bearer token for assistant access.');
    }

    final token = authHeader.substring('Bearer '.length).trim();
    if (token.isEmpty) {
      throw const ApiException(401, 'Missing bearer token for assistant access.');
    }

    final parts = token.split('.');
    if (parts.length != 3) {
      throw const ApiException(401, 'Invalid Supabase access token.');
    }

    final signingInput = '${parts[0]}.${parts[1]}';
    final expectedSignature = base64Url
        .encode(
          Hmac(
            sha256,
            utf8.encode(jwtSecret),
          ).convert(utf8.encode(signingInput)).bytes,
        )
        .replaceAll('=', '');

    if (!_constantTimeEquals(expectedSignature, parts[2])) {
      throw const ApiException(401, 'Assistant token verification failed.');
    }

    final header = _decodeJwtSection(parts[0]);
    if (header['alg']?.toString() != 'HS256') {
      throw const ApiException(401, 'Unsupported assistant token algorithm.');
    }

    final payload = _decodeJwtSection(parts[1]);
    final exp = payload['exp'];
    final expSeconds = exp is num ? exp.toInt() : int.tryParse('$exp');
    if (expSeconds == null ||
        DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000)
            .isBefore(DateTime.now().toUtc())) {
      throw const ApiException(401, 'Assistant token has expired.');
    }

    final aud = payload['aud'];
    if (jwtAudience.trim().isNotEmpty && !_audienceMatches(aud)) {
      throw const ApiException(401, 'Assistant token audience mismatch.');
    }

    final userId = payload['sub']?.toString().trim() ?? '';
    if (userId.isEmpty) {
      throw const ApiException(401, 'Assistant token is missing user identity.');
    }

    return 'user:$userId';
  }

  Map<String, dynamic> _decodeJwtSection(String value) {
    final decoded = utf8.decode(base64Url.decode(base64Url.normalize(value)));
    final json = jsonDecode(decoded);
    if (json is! Map) {
      throw const ApiException(401, 'Assistant token payload is invalid.');
    }
    return Map<String, dynamic>.from(json);
  }

  bool _audienceMatches(Object? aud) {
    if (aud is String) {
      return aud == jwtAudience;
    }
    if (aud is List) {
      return aud.map((item) => item.toString()).contains(jwtAudience);
    }
    return false;
  }

  void _applyRateLimit(String identity) {
    final now = DateTime.now().toUtc();
    final windowStart = now.subtract(window);
    final requests = _requestsByIdentity.putIfAbsent(identity, () => <DateTime>[])
      ..removeWhere((timestamp) => timestamp.isBefore(windowStart));

    if (requests.length >= maxRequests) {
      throw ApiException(
        429,
        'Assistant rate limit exceeded. Try again in a minute.',
      );
    }

    requests.add(now);
  }

  String _clientAddress(Request request) {
    final forwardedFor = request.headers['x-forwarded-for']?.trim();
    if (forwardedFor != null && forwardedFor.isNotEmpty) {
      return forwardedFor.split(',').first.trim();
    }

    final realIp = request.headers['x-real-ip']?.trim();
    if (realIp != null && realIp.isNotEmpty) {
      return realIp;
    }

    final connectionInfo = request.context['shelf.io.connection_info'];
    if (connectionInfo is HttpConnectionInfo) {
      return connectionInfo.remoteAddress.address;
    }

    return 'unknown';
  }

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) {
      return false;
    }

    var result = 0;
    for (var index = 0; index < left.length; index++) {
      result |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return result == 0;
  }
}

class OpenRouterAssistant {
  OpenRouterAssistant({
    required String apiKey,
    String model = 'openrouter/auto',
    String? httpReferer,
    String appTitle = 'ToDoUp Backend',
    HttpClient? httpClient,
  })  : _apiKey = apiKey.trim(),
        _model = model.trim().isEmpty ? 'openrouter/auto' : model.trim(),
        _httpReferer = httpReferer?.trim(),
        _appTitle =
            appTitle.trim().isEmpty ? 'ToDoUp Backend' : appTitle.trim(),
        _httpClient = httpClient ?? HttpClient();

  factory OpenRouterAssistant.fromEnvironment() {
    return OpenRouterAssistant(
      apiKey: Platform.environment['OPENROUTER_API_KEY'] ?? '',
      model: Platform.environment['OPENROUTER_MODEL'] ?? 'openrouter/auto',
      httpReferer: Platform.environment['OPENROUTER_HTTP_REFERER'],
      appTitle:
          Platform.environment['OPENROUTER_APP_TITLE'] ?? 'ToDoUp Backend',
    );
  }

  final String _apiKey;
  final String _model;
  final String? _httpReferer;
  final String _appTitle;
  final HttpClient _httpClient;

  bool get isConfigured => _apiKey.isNotEmpty;
  String get providerLabel => isConfigured ? 'openrouter' : 'heuristic';

  Future<AssistantDraft> generateTaskDraft(String prompt) async {
    if (!isConfigured) {
      throw const ApiException(500, 'OPENROUTER_API_KEY is not configured.');
    }

    final request = await _httpClient.postUrl(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_apiKey');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    if (_httpReferer != null && _httpReferer.isNotEmpty) {
      request.headers.set('HTTP-Referer', _httpReferer);
    }
    request.headers.set('X-Title', _appTitle);
    request.add(
      utf8.encode(
        jsonEncode({
          'model': _model,
          'temperature': 0.2,
          'messages': [
            {
              'role': 'system',
              'content': _systemPrompt(),
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
        }),
      ),
    );

    final response = await request.close().timeout(const Duration(seconds: 45));
    final raw = await response.transform(utf8.decoder).join();
    final payload = _decodeJsonObject(raw);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        502,
        _errorMessage(payload) ??
            'OpenRouter returned HTTP ${response.statusCode}.',
      );
    }

    final choices = payload['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('OpenRouter returned no choices.');
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map) {
      throw const FormatException('OpenRouter returned an invalid choice.');
    }

    final message = firstChoice['message'];
    if (message is! Map) {
      throw const FormatException('OpenRouter returned no assistant message.');
    }

    final content = _flattenContent(message['content']);
    if (content.trim().isEmpty) {
      throw const FormatException('OpenRouter returned empty content.');
    }

    final decoded = _decodeJsonObject(_extractJson(content));
    final preview = decoded['preview'] is Map
        ? Map<String, dynamic>.from(decoded['preview'] as Map)
        : <String, dynamic>{};

    return AssistantDraft(
      message: decoded['assistantMessage']?.toString().trim() ??
          "I've created a task draft for you. Confirm it if it looks right.",
      preview: preview,
    );
  }

  String _systemPrompt() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day)
        .toIso8601String()
        .split('T')
        .first;
    return '''
You create one task draft for a productivity app.
Today is $today.
Respond with JSON only and no markdown.
Use exactly this shape:
{
  "assistantMessage": "Short friendly confirmation sentence.",
  "preview": {
    "title": "Concise actionable task title",
    "dateValue": "YYYY-MM-DD",
    "timeValue": "HH:MM",
    "priority": "low|medium|high",
    "category": "work|personal|health|study|shopping|others"
  }
}
Rules:
- Use tomorrow when no date is given.
- Use 19:00 when no time is given.
- Use medium priority unless urgency is explicit.
- Use personal unless another category is clearly implied.
- Keep title under 72 characters.
''';
  }

  Map<String, dynamic> _decodeJsonObject(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Expected a JSON object.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  String _flattenContent(Object? content) {
    if (content is String) {
      return content;
    }
    if (content is List) {
      return content.map((item) {
        if (item is Map && item['text'] != null) {
          return item['text'].toString();
        }
        return item.toString();
      }).join('\n');
    }
    return content?.toString() ?? '';
  }

  String _extractJson(String content) {
    final trimmed = content.trim();
    final fencedMatch = RegExp(
      r'^```(?:json)?\s*([\s\S]*?)\s*```$',
      multiLine: true,
    ).firstMatch(trimmed);
    final candidate = fencedMatch?.group(1)?.trim() ?? trimmed;
    final start = candidate.indexOf('{');
    final end = candidate.lastIndexOf('}');
    if (start == -1 || end == -1 || end < start) {
      throw const FormatException('OpenRouter response did not contain JSON.');
    }
    return candidate.substring(start, end + 1);
  }

  String? _errorMessage(Map<String, dynamic> payload) {
    final error = payload['error'];
    if (error is Map && error['message'] != null) {
      return error['message'].toString();
    }
    if (error is String && error.trim().isNotEmpty) {
      return error;
    }
    return null;
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;
}

extension _ListRemoveWhereAndReturn on List<Map<String, dynamic>> {
  bool removeWhereAndReturn(bool Function(Map<String, dynamic>) test) {
    final initialLength = length;
    removeWhere(test);
    return length != initialLength;
  }
}

Response _json(int statusCode, Object body) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: const {'Content-Type': 'application/json'},
  );
}

class DateUtils {
  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
