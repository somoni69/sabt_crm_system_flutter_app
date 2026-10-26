import '../../../core/utils/api_urls.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';

class TaskFile {
  const TaskFile({
    required this.id,
    required this.originalName,
    required this.path,
    this.mimetype,
    this.size = 0,
    this.uploadedByName,
    this.createdAt,
  });

  final String id;
  final String originalName;
  final String path;
  final String? mimetype;
  final int size;
  final String? uploadedByName;
  final DateTime? createdAt;

  String get url => ApiUrls.file(path);

  String get sizeLabel {
    if (size <= 0) return '';
    if (size < 1024) return '$size Б';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} КБ';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  bool get isImage => (mimetype ?? '').startsWith('image/');

  factory TaskFile.fromJson(Map<String, dynamic> json) {
    final uploader = asMap(json['uploadedBy']);
    return TaskFile(
      id: asStringOr(json['id'], ''),
      originalName: asStringOr(json['originalName'] ?? json['filename'], 'Файл'),
      path: asStringOr(json['path'], ''),
      mimetype: asString(json['mimetype']),
      size: asIntOr(json['size'], 0),
      uploadedByName: asString(uploader?['name']),
      createdAt: BizDate.parse(json['createdAt']),
    );
  }
}
