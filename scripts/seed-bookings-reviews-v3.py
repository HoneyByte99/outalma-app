#!/usr/bin/env python3
"""
Seed Firestore — Phase 3
  - 60 bookings (seed_booking_31 a seed_booking_90)
  - 50 reviews (seed_review_26 a seed_review_75)

Idempotent : verifie l'existence avant chaque ecriture.
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timezone, timedelta

# --- Init Firebase ---
SA_PATH = "/Users/amathba/WORKSPACE/outalma/app/scripts/service-account.json"
cred = credentials.Certificate(SA_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()


def ts(year, month, day, hour=10, minute=0):
    return datetime(year, month, day, hour, minute, tzinfo=timezone.utc)


def upsert(col, doc_id, data):
    ref = db.collection(col).document(doc_id)
    doc = ref.get()
    if doc.exists:
        print(f"  [SKIP] {col}/{doc_id} existe deja")
        return False
    ref.set(data)
    print(f"  [OK]   {col}/{doc_id}")
    return True


# ===========================================================================
# BOOKINGS
# Distribution :
#   done        : 30  (31-60)
#   accepted    : 10  (61-70)
#   in_progress :  5  (71-75)
#   requested   : 10  (76-85)
#   cancelled   :  3  (86-88)
#   rejected    :  2  (89-90)
# ===========================================================================

BOOKINGS = [
    # ---- done (30) : seed_booking_31 a 60 ----
    {
        "id": "seed_booking_31",
        "customerId": "seed_user_13",
        "providerId": "seed_user_01",
        "serviceId": "seed_svc_01",
        "status": "done",
        "createdAt": ts(2025, 10, 3, 8, 0),
        "scheduledAt": ts(2025, 10, 7, 9, 0),
    },
    {
        "id": "seed_booking_32",
        "customerId": "seed_user_14",
        "providerId": "seed_user_02",
        "serviceId": "seed_svc_03",
        "status": "done",
        "createdAt": ts(2025, 10, 8, 9, 30),
        "scheduledAt": ts(2025, 10, 13, 10, 0),
    },
    {
        "id": "seed_booking_33",
        "customerId": "seed_user_15",
        "providerId": "seed_user_03",
        "serviceId": "seed_svc_04",
        "status": "done",
        "createdAt": ts(2025, 10, 12, 11, 0),
        "scheduledAt": ts(2025, 10, 16, 8, 0),
    },
    {
        "id": "seed_booking_34",
        "customerId": "seed_user_16",
        "providerId": "seed_user_04",
        "serviceId": "seed_svc_05",
        "status": "done",
        "createdAt": ts(2025, 10, 18, 14, 0),
        "scheduledAt": ts(2025, 10, 23, 9, 30),
    },
    {
        "id": "seed_booking_35",
        "customerId": "seed_user_17",
        "providerId": "seed_user_05",
        "serviceId": "seed_svc_07",
        "status": "done",
        "createdAt": ts(2025, 10, 22, 10, 0),
        "scheduledAt": ts(2025, 10, 27, 8, 0),
    },
    {
        "id": "seed_booking_36",
        "customerId": "seed_user_18",
        "providerId": "seed_user_06",
        "serviceId": "seed_svc_11",
        "status": "done",
        "createdAt": ts(2025, 10, 28, 9, 0),
        "scheduledAt": ts(2025, 11, 2, 10, 0),
    },
    {
        "id": "seed_booking_37",
        "customerId": "seed_user_19",
        "providerId": "seed_user_07",
        "serviceId": "seed_svc_12",
        "status": "done",
        "createdAt": ts(2025, 11, 3, 8, 30),
        "scheduledAt": ts(2025, 11, 7, 9, 0),
    },
    {
        "id": "seed_booking_38",
        "customerId": "seed_user_20",
        "providerId": "seed_user_08",
        "serviceId": "seed_svc_13",
        "status": "done",
        "createdAt": ts(2025, 11, 7, 11, 0),
        "scheduledAt": ts(2025, 11, 12, 8, 30),
    },
    {
        "id": "seed_booking_39",
        "customerId": "seed_user_13",
        "providerId": "seed_user_09",
        "serviceId": "seed_svc_15",
        "status": "done",
        "createdAt": ts(2025, 11, 11, 10, 0),
        "scheduledAt": ts(2025, 11, 16, 9, 0),
    },
    {
        "id": "seed_booking_40",
        "customerId": "seed_user_14",
        "providerId": "seed_user_10",
        "serviceId": "seed_svc_18",
        "status": "done",
        "createdAt": ts(2025, 11, 17, 9, 0),
        "scheduledAt": ts(2025, 11, 21, 10, 0),
    },
    {
        "id": "seed_booking_41",
        "customerId": "seed_user_15",
        "providerId": "seed_user_11",
        "serviceId": "seed_svc_21",
        "status": "done",
        "createdAt": ts(2025, 11, 22, 14, 0),
        "scheduledAt": ts(2025, 11, 26, 8, 0),
    },
    {
        "id": "seed_booking_42",
        "customerId": "seed_user_16",
        "providerId": "seed_user_12",
        "serviceId": "seed_svc_24",
        "status": "done",
        "createdAt": ts(2025, 11, 27, 9, 30),
        "scheduledAt": ts(2025, 12, 1, 9, 0),
    },
    {
        "id": "seed_booking_43",
        "customerId": "seed_user_17",
        "providerId": "seed_user_01",
        "serviceId": "seed_svc_02",
        "status": "done",
        "createdAt": ts(2025, 12, 2, 8, 0),
        "scheduledAt": ts(2025, 12, 6, 10, 0),
    },
    {
        "id": "seed_booking_44",
        "customerId": "seed_user_18",
        "providerId": "seed_user_03",
        "serviceId": "seed_svc_26",
        "status": "done",
        "createdAt": ts(2025, 12, 6, 11, 0),
        "scheduledAt": ts(2025, 12, 11, 9, 0),
    },
    {
        "id": "seed_booking_45",
        "customerId": "seed_user_19",
        "providerId": "seed_user_04",
        "serviceId": "seed_svc_06",
        "status": "done",
        "createdAt": ts(2025, 12, 10, 9, 30),
        "scheduledAt": ts(2025, 12, 15, 8, 0),
    },
    {
        "id": "seed_booking_46",
        "customerId": "seed_user_20",
        "providerId": "seed_user_05",
        "serviceId": "seed_svc_08",
        "status": "done",
        "createdAt": ts(2025, 12, 14, 10, 0),
        "scheduledAt": ts(2025, 12, 19, 9, 30),
    },
    {
        "id": "seed_booking_47",
        "customerId": "seed_user_13",
        "providerId": "seed_user_06",
        "serviceId": "seed_svc_10",
        "status": "done",
        "createdAt": ts(2025, 12, 18, 14, 0),
        "scheduledAt": ts(2025, 12, 23, 10, 0),
    },
    {
        "id": "seed_booking_48",
        "customerId": "seed_user_14",
        "providerId": "seed_user_07",
        "serviceId": "seed_svc_16",
        "status": "done",
        "createdAt": ts(2025, 12, 22, 9, 0),
        "scheduledAt": ts(2025, 12, 27, 8, 30),
    },
    {
        "id": "seed_booking_49",
        "customerId": "seed_user_15",
        "providerId": "seed_user_08",
        "serviceId": "seed_svc_14",
        "status": "done",
        "createdAt": ts(2026, 1, 2, 10, 0),
        "scheduledAt": ts(2026, 1, 6, 9, 0),
    },
    {
        "id": "seed_booking_50",
        "customerId": "seed_user_16",
        "providerId": "seed_user_09",
        "serviceId": "seed_svc_17",
        "status": "done",
        "createdAt": ts(2026, 1, 7, 11, 0),
        "scheduledAt": ts(2026, 1, 11, 10, 0),
    },
    {
        "id": "seed_booking_51",
        "customerId": "seed_user_17",
        "providerId": "seed_user_10",
        "serviceId": "seed_svc_19",
        "status": "done",
        "createdAt": ts(2026, 1, 13, 9, 0),
        "scheduledAt": ts(2026, 1, 17, 8, 0),
    },
    {
        "id": "seed_booking_52",
        "customerId": "seed_user_18",
        "providerId": "seed_user_11",
        "serviceId": "seed_svc_22",
        "status": "done",
        "createdAt": ts(2026, 1, 18, 10, 30),
        "scheduledAt": ts(2026, 1, 22, 9, 0),
    },
    {
        "id": "seed_booking_53",
        "customerId": "seed_user_19",
        "providerId": "seed_user_12",
        "serviceId": "seed_svc_23",
        "status": "done",
        "createdAt": ts(2026, 1, 22, 8, 0),
        "scheduledAt": ts(2026, 1, 26, 10, 0),
    },
    {
        "id": "seed_booking_54",
        "customerId": "seed_user_20",
        "providerId": "seed_user_02",
        "serviceId": "seed_svc_25",
        "status": "done",
        "createdAt": ts(2026, 2, 1, 9, 0),
        "scheduledAt": ts(2026, 2, 5, 8, 30),
    },
    {
        "id": "seed_booking_55",
        "customerId": "seed_user_13",
        "providerId": "seed_user_04",
        "serviceId": "seed_svc_06",
        "status": "done",
        "createdAt": ts(2026, 2, 6, 11, 0),
        "scheduledAt": ts(2026, 2, 10, 9, 0),
    },
    {
        "id": "seed_booking_56",
        "customerId": "seed_user_14",
        "providerId": "seed_user_06",
        "serviceId": "seed_svc_11",
        "status": "done",
        "createdAt": ts(2026, 2, 11, 14, 0),
        "scheduledAt": ts(2026, 2, 16, 10, 0),
    },
    {
        "id": "seed_booking_57",
        "customerId": "seed_user_15",
        "providerId": "seed_user_09",
        "serviceId": "seed_svc_15",
        "status": "done",
        "createdAt": ts(2026, 2, 19, 9, 30),
        "scheduledAt": ts(2026, 2, 23, 8, 0),
    },
    {
        "id": "seed_booking_58",
        "customerId": "seed_user_16",
        "providerId": "seed_user_03",
        "serviceId": "seed_svc_27",
        "status": "done",
        "createdAt": ts(2026, 3, 1, 10, 0),
        "scheduledAt": ts(2026, 3, 5, 9, 0),
    },
    {
        "id": "seed_booking_59",
        "customerId": "seed_user_17",
        "providerId": "seed_user_08",
        "serviceId": "seed_svc_13",
        "status": "done",
        "createdAt": ts(2026, 3, 8, 8, 30),
        "scheduledAt": ts(2026, 3, 12, 10, 0),
    },
    {
        "id": "seed_booking_60",
        "customerId": "seed_user_18",
        "providerId": "seed_user_12",
        "serviceId": "seed_svc_24",
        "status": "done",
        "createdAt": ts(2026, 3, 14, 11, 0),
        "scheduledAt": ts(2026, 3, 19, 9, 0),
    },

    # ---- accepted (10) : seed_booking_61 a 70 ----
    {
        "id": "seed_booking_61",
        "customerId": "seed_user_19",
        "providerId": "seed_user_01",
        "serviceId": "seed_svc_01",
        "status": "accepted",
        "createdAt": ts(2026, 4, 2, 9, 0),
        "scheduledAt": ts(2026, 4, 7, 10, 0),
    },
    {
        "id": "seed_booking_62",
        "customerId": "seed_user_20",
        "providerId": "seed_user_04",
        "serviceId": "seed_svc_05",
        "status": "accepted",
        "createdAt": ts(2026, 4, 4, 10, 0),
        "scheduledAt": ts(2026, 4, 9, 9, 0),
    },
    {
        "id": "seed_booking_63",
        "customerId": "seed_user_13",
        "providerId": "seed_user_07",
        "serviceId": "seed_svc_12",
        "status": "accepted",
        "createdAt": ts(2026, 4, 7, 11, 0),
        "scheduledAt": ts(2026, 4, 12, 8, 30),
    },
    {
        "id": "seed_booking_64",
        "customerId": "seed_user_14",
        "providerId": "seed_user_10",
        "serviceId": "seed_svc_18",
        "status": "accepted",
        "createdAt": ts(2026, 4, 10, 9, 30),
        "scheduledAt": ts(2026, 4, 15, 10, 0),
    },
    {
        "id": "seed_booking_65",
        "customerId": "seed_user_15",
        "providerId": "seed_user_02",
        "serviceId": "seed_svc_03",
        "status": "accepted",
        "createdAt": ts(2026, 4, 13, 8, 0),
        "scheduledAt": ts(2026, 4, 18, 9, 0),
    },
    {
        "id": "seed_booking_66",
        "customerId": "seed_user_16",
        "providerId": "seed_user_05",
        "serviceId": "seed_svc_09",
        "status": "accepted",
        "createdAt": ts(2026, 4, 16, 10, 0),
        "scheduledAt": ts(2026, 4, 21, 8, 0),
    },
    {
        "id": "seed_booking_67",
        "customerId": "seed_user_17",
        "providerId": "seed_user_06",
        "serviceId": "seed_svc_11",
        "status": "accepted",
        "createdAt": ts(2026, 4, 20, 14, 0),
        "scheduledAt": ts(2026, 4, 25, 9, 30),
    },
    {
        "id": "seed_booking_68",
        "customerId": "seed_user_18",
        "providerId": "seed_user_09",
        "serviceId": "seed_svc_14",
        "status": "accepted",
        "createdAt": ts(2026, 4, 23, 9, 0),
        "scheduledAt": ts(2026, 4, 28, 10, 0),
    },
    {
        "id": "seed_booking_69",
        "customerId": "seed_user_19",
        "providerId": "seed_user_11",
        "serviceId": "seed_svc_21",
        "status": "accepted",
        "createdAt": ts(2026, 4, 27, 11, 0),
        "scheduledAt": ts(2026, 5, 2, 9, 0),
    },
    {
        "id": "seed_booking_70",
        "customerId": "seed_user_20",
        "providerId": "seed_user_12",
        "serviceId": "seed_svc_23",
        "status": "accepted",
        "createdAt": ts(2026, 5, 1, 8, 30),
        "scheduledAt": ts(2026, 5, 6, 10, 0),
    },

    # ---- in_progress (5) : seed_booking_71 a 75 ----
    {
        "id": "seed_booking_71",
        "customerId": "seed_user_13",
        "providerId": "seed_user_03",
        "serviceId": "seed_svc_04",
        "status": "in_progress",
        "createdAt": ts(2026, 5, 6, 9, 0),
        "scheduledAt": ts(2026, 5, 10, 8, 0),
    },
    {
        "id": "seed_booking_72",
        "customerId": "seed_user_14",
        "providerId": "seed_user_08",
        "serviceId": "seed_svc_13",
        "status": "in_progress",
        "createdAt": ts(2026, 5, 8, 10, 0),
        "scheduledAt": ts(2026, 5, 12, 9, 0),
    },
    {
        "id": "seed_booking_73",
        "customerId": "seed_user_15",
        "providerId": "seed_user_04",
        "serviceId": "seed_svc_26",
        "status": "in_progress",
        "createdAt": ts(2026, 5, 10, 14, 0),
        "scheduledAt": ts(2026, 5, 15, 10, 0),
    },
    {
        "id": "seed_booking_74",
        "customerId": "seed_user_16",
        "providerId": "seed_user_07",
        "serviceId": "seed_svc_16",
        "status": "in_progress",
        "createdAt": ts(2026, 5, 13, 9, 30),
        "scheduledAt": ts(2026, 5, 17, 8, 30),
    },
    {
        "id": "seed_booking_75",
        "customerId": "seed_user_17",
        "providerId": "seed_user_10",
        "serviceId": "seed_svc_19",
        "status": "in_progress",
        "createdAt": ts(2026, 5, 15, 11, 0),
        "scheduledAt": ts(2026, 5, 20, 9, 0),
    },

    # ---- requested (10) : seed_booking_76 a 85 ----
    {
        "id": "seed_booking_76",
        "customerId": "seed_user_18",
        "providerId": "seed_user_01",
        "serviceId": "seed_svc_02",
        "status": "requested",
        "createdAt": ts(2026, 5, 17, 9, 0),
        "scheduledAt": ts(2026, 5, 22, 10, 0),
    },
    {
        "id": "seed_booking_77",
        "customerId": "seed_user_19",
        "providerId": "seed_user_02",
        "serviceId": "seed_svc_25",
        "status": "requested",
        "createdAt": ts(2026, 5, 17, 10, 30),
        "scheduledAt": ts(2026, 5, 22, 9, 0),
    },
    {
        "id": "seed_booking_78",
        "customerId": "seed_user_20",
        "providerId": "seed_user_05",
        "serviceId": "seed_svc_07",
        "status": "requested",
        "createdAt": ts(2026, 5, 18, 8, 0),
        "scheduledAt": ts(2026, 5, 23, 8, 30),
    },
    {
        "id": "seed_booking_79",
        "customerId": "seed_user_13",
        "providerId": "seed_user_06",
        "serviceId": "seed_svc_10",
        "status": "requested",
        "createdAt": ts(2026, 5, 18, 11, 0),
        "scheduledAt": ts(2026, 5, 24, 9, 0),
    },
    {
        "id": "seed_booking_80",
        "customerId": "seed_user_14",
        "providerId": "seed_user_09",
        "serviceId": "seed_svc_15",
        "status": "requested",
        "createdAt": ts(2026, 5, 19, 9, 0),
        "scheduledAt": ts(2026, 5, 24, 10, 0),
    },
    {
        "id": "seed_booking_81",
        "customerId": "seed_user_15",
        "providerId": "seed_user_11",
        "serviceId": "seed_svc_22",
        "status": "requested",
        "createdAt": ts(2026, 5, 19, 14, 0),
        "scheduledAt": ts(2026, 5, 25, 8, 0),
    },
    {
        "id": "seed_booking_82",
        "customerId": "seed_user_16",
        "providerId": "seed_user_12",
        "serviceId": "seed_svc_24",
        "status": "requested",
        "createdAt": ts(2026, 5, 20, 9, 30),
        "scheduledAt": ts(2026, 5, 26, 9, 0),
    },
    {
        "id": "seed_booking_83",
        "customerId": "seed_user_17",
        "providerId": "seed_user_03",
        "serviceId": "seed_svc_28",
        "status": "requested",
        "createdAt": ts(2026, 5, 20, 11, 0),
        "scheduledAt": ts(2026, 5, 26, 10, 0),
    },
    {
        "id": "seed_booking_84",
        "customerId": "seed_user_18",
        "providerId": "seed_user_07",
        "serviceId": "seed_svc_17",
        "status": "requested",
        "createdAt": ts(2026, 5, 21, 8, 30),
        "scheduledAt": ts(2026, 5, 27, 8, 0),
    },
    {
        "id": "seed_booking_85",
        "customerId": "seed_user_19",
        "providerId": "seed_user_10",
        "serviceId": "seed_svc_20",
        "status": "requested",
        "createdAt": ts(2026, 5, 21, 10, 0),
        "scheduledAt": ts(2026, 5, 27, 9, 30),
    },

    # ---- cancelled (3) : seed_booking_86 a 88 ----
    {
        "id": "seed_booking_86",
        "customerId": "seed_user_20",
        "providerId": "seed_user_04",
        "serviceId": "seed_svc_05",
        "status": "cancelled",
        "createdAt": ts(2026, 3, 22, 9, 0),
        "scheduledAt": ts(2026, 3, 27, 10, 0),
    },
    {
        "id": "seed_booking_87",
        "customerId": "seed_user_13",
        "providerId": "seed_user_08",
        "serviceId": "seed_svc_13",
        "status": "cancelled",
        "createdAt": ts(2026, 4, 5, 10, 0),
        "scheduledAt": ts(2026, 4, 10, 8, 30),
    },
    {
        "id": "seed_booking_88",
        "customerId": "seed_user_14",
        "providerId": "seed_user_02",
        "serviceId": "seed_svc_03",
        "status": "cancelled",
        "createdAt": ts(2026, 4, 18, 11, 0),
        "scheduledAt": ts(2026, 4, 23, 9, 0),
    },

    # ---- rejected (2) : seed_booking_89 a 90 ----
    {
        "id": "seed_booking_89",
        "customerId": "seed_user_15",
        "providerId": "seed_user_06",
        "serviceId": "seed_svc_11",
        "status": "rejected",
        "createdAt": ts(2026, 2, 25, 9, 0),
        "scheduledAt": ts(2026, 3, 1, 10, 0),
    },
    {
        "id": "seed_booking_90",
        "customerId": "seed_user_16",
        "providerId": "seed_user_11",
        "serviceId": "seed_svc_21",
        "status": "rejected",
        "createdAt": ts(2026, 3, 10, 10, 30),
        "scheduledAt": ts(2026, 3, 15, 9, 0),
    },
]

print("\n=== TÂCHE 1 : Bookings (31-90) ===")
booking_count = 0
status_counts = {}
for b in BOOKINGS:
    data = {**b, "_seeded": True}
    doc_id = data.pop("id")
    created = upsert("bookings", doc_id, data)
    if created:
        booking_count += 1
        s = data["status"]
        status_counts[s] = status_counts.get(s, 0) + 1


# ===========================================================================
# REVIEWS — 50 reviews sur les 30 bookings done (31-60)
# Ratings : 8 x 3 etoiles, 17 x 4 etoiles, 25 x 5 etoiles  (total 50)
# Bookings 31-50 : 2 reviews chacun  = 40
# Bookings 51-60 : 1 review chacun   = 10
# Total : 50
#
# reviewer = customerId du booking
# reviewee = providerId du booking
# createdAt = scheduledAt + 1 jour
# ===========================================================================

COMMENTS = [
    "Tres professionnel, je recommande.",
    "Travail soigne et rapide.",
    "Ponctuel et efficace.",
    "Bon rapport qualite-prix.",
    "Un peu en retard mais bon resultat.",
    "Exactement ce que j'attendais.",
    "Je referai appel a lui.",
    "Satisfaite du travail.",
    "Tres a l'ecoute, merci.",
    "Propre et serieux.",
    "Resultat impeccable.",
    "Intervention rapide, merci.",
    "Prestation conforme, je recommande.",
    "Bonne communication, travail bien fait.",
    "Correct, rien a redire.",
]

# Ratings sequence : 8 threes, 17 fours, 25 fives
RATINGS = [3]*8 + [4]*17 + [5]*25  # 50 total

# Build done_map : id -> {customerId, providerId, scheduledAt}
done_map = {}
for b in BOOKINGS:
    if b["status"] == "done":
        done_map[b["id"]] = b

# Build reviews list with explicit IDs seed_review_26 to seed_review_75
REVIEWS = []
r_idx = 0       # index into RATINGS
c_idx = 0       # index into COMMENTS
review_num = 26  # next review number

# Bookings 31-50 get 2 reviews each
for bnum in range(31, 51):
    bid = f"seed_booking_{bnum}"
    bdata = done_map[bid]
    sched = bdata["scheduledAt"]
    next_day = sched + timedelta(days=1)
    cid = bdata["customerId"]
    pid = bdata["providerId"]

    REVIEWS.append({
        "id": f"seed_review_{review_num}",
        "bookingId": bid,
        "reviewerId": cid,
        "revieweeId": pid,
        "rating": RATINGS[r_idx],
        "comment": COMMENTS[c_idx % len(COMMENTS)],
        "createdAt": datetime(next_day.year, next_day.month, next_day.day, 10, 0, tzinfo=timezone.utc),
    })
    review_num += 1
    r_idx += 1
    c_idx += 1

    REVIEWS.append({
        "id": f"seed_review_{review_num}",
        "bookingId": bid,
        "reviewerId": cid,
        "revieweeId": pid,
        "rating": RATINGS[r_idx],
        "comment": COMMENTS[c_idx % len(COMMENTS)],
        "createdAt": datetime(next_day.year, next_day.month, next_day.day, 14, 0, tzinfo=timezone.utc),
    })
    review_num += 1
    r_idx += 1
    c_idx += 1

# Bookings 51-60 get 1 review each
for bnum in range(51, 61):
    bid = f"seed_booking_{bnum}"
    bdata = done_map[bid]
    sched = bdata["scheduledAt"]
    next_day = sched + timedelta(days=1)
    cid = bdata["customerId"]
    pid = bdata["providerId"]

    REVIEWS.append({
        "id": f"seed_review_{review_num}",
        "bookingId": bid,
        "reviewerId": cid,
        "revieweeId": pid,
        "rating": RATINGS[r_idx],
        "comment": COMMENTS[c_idx % len(COMMENTS)],
        "createdAt": datetime(next_day.year, next_day.month, next_day.day, 11, 0, tzinfo=timezone.utc),
    })
    review_num += 1
    r_idx += 1
    c_idx += 1

assert len(REVIEWS) == 50, f"Attendu 50 reviews, obtenu {len(REVIEWS)}"
assert review_num == 76, f"Dernier review_num attendu 76, obtenu {review_num}"

print("\n=== TÂCHE 2 : Reviews (26-75) ===")
review_count = 0
rating_dist = {3: 0, 4: 0, 5: 0}
for r in REVIEWS:
    data = {**r, "_seeded": True}
    doc_id = data.pop("id")
    created = upsert("reviews", doc_id, data)
    if created:
        review_count += 1
        rating_dist[data["rating"]] = rating_dist.get(data["rating"], 0) + 1

# ===========================================================================
# RÉSUMÉ
# ===========================================================================
print("\n" + "="*50)
print("RÉSUMÉ")
print("="*50)
print(f"Bookings crees  : {booking_count}/60")
for s in ["done", "accepted", "in_progress", "requested", "cancelled", "rejected"]:
    print(f"  {s}: {status_counts.get(s, 0)}")
print(f"Reviews creees  : {review_count}/50")
for star in [3, 4, 5]:
    print(f"  {star} etoiles: {rating_dist.get(star, 0)}")
print("="*50)
print("Termine.")
