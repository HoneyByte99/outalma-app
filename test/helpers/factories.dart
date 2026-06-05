// Test factory helpers.
//
// Provides makeTestUser(), makeTestService(), makeTestBooking(),
// makeTestChat(), makeTestReview() builders with sensible defaults
// and named parameters to override specific fields.
//
// This file contains NO tests — import it from test files.

import 'package:outalma_app/src/domain/enums/active_mode.dart';
import 'package:outalma_app/src/domain/enums/booking_status.dart';
import 'package:outalma_app/src/domain/enums/category_id.dart';
import 'package:outalma_app/src/domain/enums/price_type.dart';
import 'package:outalma_app/src/domain/enums/reviewer_role.dart';
import 'package:outalma_app/src/domain/models/app_user.dart';
import 'package:outalma_app/src/domain/models/booking.dart';
import 'package:outalma_app/src/domain/models/chat.dart';
import 'package:outalma_app/src/domain/models/review.dart';
import 'package:outalma_app/src/domain/models/service.dart';

final _epoch = DateTime(2024, 1, 1);

AppUser makeTestUser({
  String id = 'user-001',
  String displayName = 'Test User',
  String email = 'test@example.com',
  String country = 'FR',
  ActiveMode activeMode = ActiveMode.client,
  DateTime? createdAt,
  String? photoPath,
  String? phoneE164,
  String? pushToken,
}) => AppUser(
  id: id,
  displayName: displayName,
  email: email,
  country: country,
  activeMode: activeMode,
  createdAt: createdAt ?? _epoch,
  photoPath: photoPath,
  phoneE164: phoneE164,
  pushToken: pushToken,
);

Service makeTestService({
  String id = 'service-001',
  String providerId = 'provider-001',
  CategoryId categoryId = CategoryId.menage,
  String title = 'Test Service',
  String? description,
  List<String>? photos,
  PriceType priceType = PriceType.hourly,
  int price = 2500,
  bool published = true,
  DateTime? createdAt,
  DateTime? updatedAt,
}) => Service(
  id: id,
  providerId: providerId,
  categoryId: categoryId,
  title: title,
  description: description,
  photos: photos ?? const [],
  priceType: priceType,
  price: price,
  published: published,
  createdAt: createdAt ?? _epoch,
  updatedAt: updatedAt ?? _epoch,
);

Booking makeTestBooking({
  String id = 'booking-001',
  String customerId = 'customer-001',
  String providerId = 'provider-001',
  String serviceId = 'service-001',
  BookingStatus status = BookingStatus.requested,
  String requestMessage = 'Test booking request',
  DateTime? createdAt,
  DateTime? scheduledAt,
  String? chatId,
  DateTime? acceptedAt,
  DateTime? rejectedAt,
  DateTime? cancelledAt,
  DateTime? startedAt,
  DateTime? doneAt,
  String? audioMessageUrl,
}) => Booking(
  id: id,
  customerId: customerId,
  providerId: providerId,
  serviceId: serviceId,
  status: status,
  requestMessage: requestMessage,
  createdAt: createdAt ?? _epoch,
  scheduledAt: scheduledAt,
  chatId: chatId,
  acceptedAt: acceptedAt,
  rejectedAt: rejectedAt,
  cancelledAt: cancelledAt,
  startedAt: startedAt,
  doneAt: doneAt,
  audioMessageUrl: audioMessageUrl,
);

Chat makeTestChat({
  String id = 'chat-001',
  String bookingId = 'booking-001',
  List<String>? participantIds,
  DateTime? createdAt,
  DateTime? lastMessageAt,
  String customerId = 'customer-001',
  String providerId = 'provider-001',
}) => Chat(
  id: id,
  bookingId: bookingId,
  participantIds: participantIds ?? const ['customer-001', 'provider-001'],
  createdAt: createdAt ?? _epoch,
  lastMessageAt: lastMessageAt,
  customerId: customerId,
  providerId: providerId,
);

Review makeTestReview({
  String id = 'review-001',
  String bookingId = 'booking-001',
  String reviewerId = 'customer-001',
  String revieweeId = 'provider-001',
  ReviewerRole reviewerRole = ReviewerRole.client,
  int rating = 5,
  String? comment,
  DateTime? createdAt,
}) => Review(
  id: id,
  bookingId: bookingId,
  reviewerId: reviewerId,
  revieweeId: revieweeId,
  reviewerRole: reviewerRole,
  rating: rating,
  comment: comment,
  createdAt: createdAt ?? _epoch,
);
