#!/usr/bin/env python3
"""
Enrich seeded providers in Firestore.
- Adds avgRating (4.0-4.9), reviewCount (8-47) to all providers where _seeded == True
- Adds photoUrl only if absent, mapped from seed_user_N -> avatar_N

Idempotent: avgRating/reviewCount always patched (deterministic by doc ID),
photoUrl only added if missing.

Usage: python3 scripts/enrich-providers.py
"""

import sys
import warnings
warnings.filterwarnings("ignore")

from pathlib import Path

SERVICE_ACCOUNT = Path(__file__).parent / "service-account.json"

# Deterministic ratings per user index so re-runs produce the same values
RATINGS = [
    (4.8, 34),
    (4.5, 19),
    (4.9, 47),
    (4.2, 11),
    (4.7, 28),
    (4.3, 15),
    (4.6, 22),
    (4.4, 8),
    (4.8, 41),
    (4.1, 13),
    (4.7, 37),
    (4.5, 24),
    (4.9, 43),
    (4.3, 17),
    (4.6, 31),
    (4.2, 9),
    (4.8, 38),
    (4.4, 21),
    (4.7, 29),
    (4.5, 16),
]

def avatar_url(n: int) -> str:
    return f"https://storage.googleapis.com/outalmaservice-d1e59.firebasestorage.app/seed/avatars/avatar_{n:02d}.jpg"


def user_index_from_id(doc_id: str):
    """Extract numeric index from seed_user_NN, returns 1-based int or None."""
    if doc_id.startswith("seed_user_"):
        try:
            return int(doc_id.replace("seed_user_", ""))
        except ValueError:
            pass
    return None


def main():
    import firebase_admin
    from firebase_admin import credentials, firestore

    if not firebase_admin._apps:
        cred = credentials.Certificate(str(SERVICE_ACCOUNT))
        firebase_admin.initialize_app(cred)

    db = firestore.client()

    print("\nFetching seeded providers...")
    providers_ref = db.collection("providers")
    docs = providers_ref.where("_seeded", "==", True).stream()
    docs = list(docs)
    print(f"  Found {len(docs)} seeded providers")

    updated = 0
    skipped_photo = 0

    for i, doc in enumerate(docs):
        data = doc.to_dict() or {}
        doc_id = doc.id

        # Determine rating/review values: use user index if available, else cycle through RATINGS
        user_idx = user_index_from_id(doc_id)
        if user_idx is not None and 1 <= user_idx <= len(RATINGS):
            avg_rating, review_count = RATINGS[user_idx - 1]
        else:
            avg_rating, review_count = RATINGS[i % len(RATINGS)]

        patch = {
            "avgRating": avg_rating,
            "reviewCount": review_count,
        }

        # Only add photoUrl if absent
        if not data.get("photoUrl"):
            if user_idx is not None and 1 <= user_idx <= 20:
                patch["photoUrl"] = avatar_url(user_idx)
            else:
                patch["photoUrl"] = avatar_url((i % 20) + 1)
        else:
            skipped_photo += 1

        doc.reference.update(patch)
        photo_note = "(photo skipped, already set)" if data.get("photoUrl") else f"photo=avatar_{user_idx or (i%20)+1:02d}"
        print(f"  {doc_id}: rating={avg_rating}, reviews={review_count}, {photo_note}")
        updated += 1

    print(f"\nDone. {updated} providers enriched, {skipped_photo} already had photoUrl.")


if __name__ == "__main__":
    main()
