import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';

class AppFile {
  const AppFile({
    required this.id,
    required this.name,
    required this.url,
    this.mimeType,
    this.size = 0,
    this.createdAt,
    this.projectId,
    this.uploadedByName,
  });

  final String id;
  final String name;
  final String url;
  final String? mimeType;
  final int size;
  final DateTime? createdAt;
  final String? projectId;
  final String? uploadedByName;

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory AppFile.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user'] ?? json['uploadedBy']);
    return AppFile(
      id: asStringOr(json['id'], ''),
      name: asStringOr(json['originalName'] ?? json['name'] ?? json['filename'], 'Файл'),
      url: asStringOr(json['url'] ?? json['path'], ''),
      mimeType: asString(json['mimeType'] ?? json['mimetype']),
      size: asIntOr(json['size'] ?? json['bytes'], 0),
      createdAt: BizDate.parse(json['createdAt']),
      projectId: asString(json['projectId']),
      uploadedByName: asString(user?['name'] ?? json['userName']),
    );
  }
}
