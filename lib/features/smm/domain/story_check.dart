import '../../../core/utils/json_utils.dart';

class StoryCheckProject {
  const StoryCheckProject({
    required this.id,
    required this.name,
    required this.target,
    required this.actual,
    required this.status,
    this.crew = const [],
    this.posters = const [],
  });

  final String id;
  final String name;
  final int target;
  final int actual;
  final String status;
  final List<({String id, String name})> crew;
  final List<({String id, String name, int count})> posters;

  bool get isDone => status == 'done';
  bool get isPartial => status == 'partial';
  int get missing => (target - actual).clamp(0, 999);

  factory StoryCheckProject.fromJson(Map<String, dynamic> json) {
    final crew = <({String id, String name})>[];
    for (final raw in asList(json['crew'])) {
      final map = asMap(raw);
      if (map == null) continue;
      crew.add((
        id: asStringOr(map['id'], ''),
        name: asStringOr(map['name'], 'Сотрудник'),
      ));
    }
    final posters = <({String id, String name, int count})>[];
    for (final raw in asList(json['posters'])) {
      final map = asMap(raw);
      if (map == null) continue;
      posters.add((
        id: asStringOr(map['id'], ''),
        name: asStringOr(map['name'], 'Сотрудник'),
        count: asIntOr(map['count'], 0),
      ));
    }
    return StoryCheckProject(
      id: asStringOr(json['id'], ''),
      name: asStringOr(json['name'], 'Проект'),
      target: asIntOr(json['target'], 0),
      actual: asIntOr(json['actual'], 0),
      status: asStringOr(json['status'], 'none'),
      crew: crew,
      posters: posters,
    );
  }
}

class StoryCheckDay {
  const StoryCheckDay({
    required this.date,
    required this.future,
    required this.projects,
    required this.done,
    required this.partial,
    required this.none,
  });

  final String date;
  final bool future;
  final List<StoryCheckProject> projects;
  final int done;
  final int partial;
  final int none;

  int get total => projects.length;
  bool get allDone => total > 0 && done == total;

  factory StoryCheckDay.fromJson(Map<String, dynamic> json) {
    final totals = asMap(json['totals']) ?? const {};
    return StoryCheckDay(
      date: asStringOr(json['date'], ''),
      future: asBool(json['future']),
      projects: asList(json['projects'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(StoryCheckProject.fromJson)
          .toList(),
      done: asIntOr(totals['done'], 0),
      partial: asIntOr(totals['partial'], 0),
      none: asIntOr(totals['none'], 0),
    );
  }
}
