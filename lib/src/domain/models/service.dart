import '../enums/category_id.dart';
import '../enums/price_type.dart';
import 'service_zone.dart';

class Service {
  const Service({
    required this.id,
    required this.providerId,
    required this.categoryId,
    required this.title,
    required this.photos,
    required this.priceType,
    required this.price,
    required this.published,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.serviceZones = const [],
    this.status,
  });

  final String id;
  final String providerId;
  final CategoryId categoryId;
  final String title;
  final String? description;
  final List<String> photos;
  final PriceType priceType;
  final int price;
  final bool published;
  final List<ServiceZone> serviceZones;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Server-managed moderation status: null (never reviewed), 'pending_review',
  /// 'approved', or 'rejected'. Set exclusively by the moderation Cloud
  /// Functions — the client reads it but never writes it.
  final String? status;

  Service copyWith({
    String? providerId,
    CategoryId? categoryId,
    String? title,
    String? description,
    List<String>? photos,
    PriceType? priceType,
    int? price,
    bool? published,
    List<ServiceZone>? serviceZones,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return Service(
      id: id,
      providerId: providerId ?? this.providerId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      priceType: priceType ?? this.priceType,
      price: price ?? this.price,
      published: published ?? this.published,
      serviceZones: serviceZones ?? this.serviceZones,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }
}
