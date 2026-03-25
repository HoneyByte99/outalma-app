import '../enums/service_status.dart';

class Service {
  const Service({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.durationMinutes,
    this.priceCents,
  });

  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final int? durationMinutes;
  final int? priceCents;
  final ServiceStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Service copyWith({
    String? ownerId,
    String? title,
    String? description,
    int? durationMinutes,
    int? priceCents,
    ServiceStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Service(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      priceCents: priceCents ?? this.priceCents,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'durationMinutes': durationMinutes,
      'priceCents': priceCents,
      'status': status.name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  static Service fromJson(String id, Map<String, Object?> json) {
    DateTime parseUtc(Object? raw) {
      if (raw is String) return DateTime.parse(raw).toUtc();
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    return Service(
      id: id,
      ownerId: (json['ownerId'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: json['description'] as String?,
      durationMinutes: json['durationMinutes'] as int?,
      priceCents: json['priceCents'] as int?,
      status: ServiceStatus.fromString(
        (json['status'] as String?) ?? ServiceStatus.draft.name,
      ),
      createdAt: parseUtc(json['createdAt']),
      updatedAt: parseUtc(json['updatedAt']),
    );
  }
}
