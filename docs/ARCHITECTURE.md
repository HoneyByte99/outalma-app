# Architecture (Flutter)

This document defines the minimal **data/domain** foundation for the Outlama app.

## Goals

- Keep UI code free of Firestore serialization details.
- Provide a clean seam for future implementations (Firestore, REST, mock).
- Stay minimal: **models + enums + repository interfaces + Firestore converters**.

## Folder structure (recommended)

```text
lib/
  main.dart
  src/
    domain/
      enums/
      models/
      repositories/
      domain.dart

    data/
      firestore/
        firestore_collections.dart
        firestore_serialization.dart
      data.dart

    application/          # (future) use-cases / services / state mgmt
    presentation/         # (future) UI (widgets/pages)
```

## Naming conventions

- **Files**: `snake_case.dart`
- **Classes**: `PascalCase`
- **Domain models**: no `DTO` suffix.
- **User model**: named `AppUser` (avoid clashing with FirebaseAuth `User`).
- **Dates**: domain uses `DateTime` in **UTC**.

## Domain layer

### Models

- `Booking`
- `Service`
- `AppUser`
- `ChatMessage`

### Enums

- `BookingStatus`
- `ServiceStatus`
- `UserRole`
- `MessageType`

### Repository interfaces

Repositories are defined as pure abstractions under `domain/repositories/`.
They expose `Stream` for live updates and `Future` for commands.

## Data layer (Firestore)

### Why `withConverter`

Firestore is strongly typed only when using `CollectionReference<T>` via `withConverter`.
We centralize this in `FirestoreCollections`:

- `users(db)` → `CollectionReference<AppUser>`
- `services(db)` → `CollectionReference<Service>`
- `bookings(db)` → `CollectionReference<Booking>`
- `chatMessages(db, chatId)` → `CollectionReference<ChatMessage>`

### Timestamp handling

`firestore_serialization.dart` supports reading timestamps from:
- `Timestamp` (preferred)
- ISO-8601 `String`
- epoch millis `int`

Everything is normalized to **UTC DateTime** in domain.

## Next steps (not in this commit)

- Implement repository classes in `data/` (Firestore-backed).
- Add tests for serialization (golden JSON + Firestore timestamp variations).
- Add CI linting + formatting.
