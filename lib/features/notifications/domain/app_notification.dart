import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.link,
    this.createdAt,
    this.data,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final String? link;
  final DateTime? createdAt;
  final Map<String, dynamic>? data;

  String get timeLabel => createdAt == null ? '' : BizDate.relative(createdAt!);

  String get groupLabel {
    final date = createdAt;
    if (date == null) return 'Ранее';
    if (BizDate.isToday(date)) return 'Сегодня';
    if (BizDate.isYesterday(date)) return 'Вчера';
    if (BizDate.daysBetween(date, BizDate.today()) < 7) return 'На этой неделе';
    return 'Ранее';
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        message: message,
        isRead: isRead ?? this.isRead,
        link: link,
        createdAt: createdAt,
        data: data,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: asStringOr(json['id'], ''),
        type: asStringOr(json['type'], 'info'),
        title: asStringOr(json['title'], 'Уведомление'),
        message: asStringOr(json['message'], ''),
        isRead: asBool(json['isRead']),
        link: asString(json['link']),
        createdAt: BizDate.parse(json['createdAt']),
        data: asMap(json['data']),
      );
}
