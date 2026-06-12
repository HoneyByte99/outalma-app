import '../models/blocked_slot.dart';
import '../models/provider_profile.dart';

abstract interface class ProviderRepository {
  Stream<ProviderProfile?> watchByUid(String uid);

  /// UIDs of providers currently "En pause" (`active == false`). Used to hide
  /// their listings from client discovery. Small set (only paused providers).
  Stream<Set<String>> watchPausedProviderIds();

  Future<void> upsert(ProviderProfile profile);

  /// Flips the provider's own availability ("Disponible"/"En pause"). The only
  /// status field a provider may write on their own doc; non-destructive (never
  /// touches any service's `published`).
  Future<void> setActive(String uid, bool active);

  // Blocked slots
  Stream<List<BlockedSlot>> watchBlockedSlots(String uid);
  Future<void> addBlockedSlot(String uid, BlockedSlot slot);
  Future<void> removeBlockedSlot(String uid, String slotId);
}
