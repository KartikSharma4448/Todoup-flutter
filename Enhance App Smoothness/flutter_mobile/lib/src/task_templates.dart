import 'models.dart';

const List<TaskTemplate> defaultTaskTemplates = [
  TaskTemplate(
    id: 'study-revision',
    title: 'Study Revision Session',
    description:
        'Review notes, summarize key concepts, and finish practice questions.',
    priority: TaskPriority.high,
    category: TaskCategory.study,
    reminder: true,
    repeat: 'None',
    subtasks: [
      'Review notes',
      'Solve practice questions',
      'Write quick summary',
    ],
  ),
  TaskTemplate(
    id: 'gym-routine',
    title: 'Gym Workout',
    description: 'Warm up, complete the main workout, and log progress.',
    priority: TaskPriority.medium,
    category: TaskCategory.health,
    reminder: true,
    repeat: 'Daily',
    subtasks: ['Warm up', 'Main workout', 'Stretch and log session'],
  ),
  TaskTemplate(
    id: 'office-deep-work',
    title: 'Office Deep Work Block',
    description: 'Focus on the top priority deliverable without interruptions.',
    priority: TaskPriority.high,
    category: TaskCategory.work,
    reminder: true,
    repeat: 'None',
    subtasks: [
      'Review priorities',
      'Work on main task',
      'Send progress update',
    ],
  ),
  TaskTemplate(
    id: 'exam-checklist',
    title: 'Exam Preparation Checklist',
    description:
        'Cover revision, mock tests, and important formulas before the exam.',
    priority: TaskPriority.high,
    category: TaskCategory.study,
    reminder: true,
    repeat: 'None',
    subtasks: ['Revise chapters', 'Attempt mock test', 'Review weak topics'],
  ),
  TaskTemplate(
    id: 'shopping-run',
    title: 'Shopping Run',
    description:
        'Plan purchases, buy essentials, and verify nothing is missed.',
    priority: TaskPriority.medium,
    category: TaskCategory.shopping,
    reminder: false,
    repeat: 'None',
    subtasks: ['Make list', 'Buy essentials', 'Check budget before checkout'],
  ),
];
