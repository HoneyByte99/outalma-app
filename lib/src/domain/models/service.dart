import '../enums/category_id.dart';
import '../enums/price_type.dart';
import 'service_zone.dart';

/// Sentinel marking an omitted `copyWith` argument, so nullable fields can be
/// explicitly cleared (pass null) or left untouched (omit the argument).
const Object _unset = Object();

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
    this.extraTasks = const [],
    this.priceMax,
  });

  final String id;
  final String providerId;
  final CategoryId categoryId;
  final String title;
  final String? description;
  final List<String> photos;
  final PriceType priceType;

  /// Price in whole FCFA. For hourly/daily modes this is the flat price; for the
  /// monthly mode it is the LOW end of the range (the high end is [priceMax]).
  final int price;

  /// High end of the monthly range, in whole FCFA. Present only when
  /// [priceType] is monthly; null for hourly and daily.
  final int? priceMax;

  /// Extra tasks the listing also covers, beyond the main [categoryId].
  /// Zero to three entries; never contains the main category.
  final List<String> extraTasks;

  final bool published;
  final List<ServiceZone> serviceZones;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Server-managed moderation status: null (never reviewed), 'pending_review',
  /// 'approved', or 'rejected'. Set exclusively by the moderation Cloud
  /// Functions, the client reads it but never writes it.
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
    List<String>? extraTasks,
    // Wrapped so a caller can explicitly clear priceMax (e.g. switching a
    // monthly listing back to hourly): pass `priceMax: null` and it clears;
    // omit the argument and the current value is kept.
    Object? priceMax = _unset,
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
      extraTasks: extraTasks ?? this.extraTasks,
      priceMax: identical(priceMax, _unset) ? this.priceMax : priceMax as int?,
    );
  }
}
