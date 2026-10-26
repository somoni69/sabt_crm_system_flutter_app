import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';

class Note {
  const Note({
    required this.id,
    required this.text,
    this.date,
    this.done = false,
    this.createdAt,
  });

  final String id;
  final String text;
  final String? date;
  final bool done;
  final DateTime? createdAt;

  Note copyWith({
    String? id,
    String? text,
    String? date,
    bool? done,
    DateTime? createdAt,
  }) {
    return Note(
      id: id ?? this.id,
      text: text ?? this.text,
      date: date ?? this.date,
      done: done ?? this.done,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: asStringOr(json['id'], ''),
        text: asStringOr(json['text'], ''),
        date: asString(json['date']),
        done: asBool(json['done']),
        createdAt: BizDate.parse(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        if (date != null) 'date': date,
        'done': done,
      };
}
