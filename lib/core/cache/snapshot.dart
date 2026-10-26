import 'cached_json.dart';

class Snapshot<T> {
  const Snapshot({
    required this.data,
    this.savedAt,
    this.fromCache = false,
    this.error,
    this.revision = 0,
  });

  final T data;
  final DateTime? savedAt;
  final bool fromCache;
  final String? error;
  final int revision;

  bool get hasError => error != null;
  bool get isStale => fromCache;

  Snapshot<T> copyWith({
    T? data,
    DateTime? savedAt,
    bool? fromCache,
    String? error,
    int? revision,
  }) =>
      Snapshot(
        data: data ?? this.data,
        savedAt: savedAt ?? this.savedAt,
        fromCache: fromCache ?? this.fromCache,
        error: error ?? this.error,
        revision: revision ?? this.revision,
      );

  static Snapshot<T> fromPayload<T>(
    CachedPayload payload,
    T Function(dynamic data) decode, {
    int revision = 0,
  }) {
    return Snapshot<T>(
      data: decode(payload.data),
      savedAt: payload.savedAt,
      fromCache: payload.fromCache,
      error: payload.error,
      revision: revision,
    );
  }
}
