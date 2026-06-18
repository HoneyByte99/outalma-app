#!/usr/bin/env python3
"""
Enrichissement des données seed Firestore.
Tâches :
  - 15 bookings (seed_booking_16 à seed_booking_30)
  - 15 reviews (seed_review_11 à seed_review_25)
  - 7 chats avec messages (seed_chat_09 à seed_chat_15)
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timezone
import sys

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
        print(f"  [SKIP] {col}/{doc_id} existe déjà")
        return False
    ref.set(data)
    print(f"  [OK]   {col}/{doc_id}")
    return True

# ===========================================================================
# TÂCHE 1 — 15 bookings supplémentaires
# ===========================================================================
# Distribution : 7 done, 3 accepted, 2 in_progress, 2 requested, 1 cancelled
# Règle : serviceId doit appartenir au provider concerné

BOOKINGS = [
    # --- done (7) ---
    {
        "id": "seed_booking_16",
        "customerId": "seed_user_16",
        "providerId": "seed_user_01",
        "serviceId": "seed_svc_02",
        "status": "done",
        "createdAt": ts(2026, 1, 5, 9, 0),
        "scheduledAt": ts(2026, 1, 9, 10, 0),
    },
    {
        "id": "seed_booking_17",
        "customerId": "seed_user_13",
        "providerId": "seed_user_05",
        "serviceId": "seed_svc_08",
        "status": "done",
        "createdAt": ts(2026, 1, 12, 11, 0),
        "scheduledAt": ts(2026, 1, 15, 9, 0),
    },
    {
        "id": "seed_booking_18",
        "customerId": "seed_user_19",
        "providerId": "seed_user_07",
        "serviceId": "seed_svc_16",
        "status": "done",
        "createdAt": ts(2026, 1, 20, 8, 30),
        "scheduledAt": ts(2026, 1, 24, 8, 0),
    },
    {
        "id": "seed_booking_19",
        "customerId": "seed_user_14",
        "providerId": "seed_user_02",
        "serviceId": "seed_svc_25",
        "status": "done",
        "createdAt": ts(2026, 2, 3, 10, 0),
        "scheduledAt": ts(2026, 2, 7, 9, 0),
    },
    {
        "id": "seed_booking_20",
        "customerId": "seed_user_18",
        "providerId": "seed_user_10",
        "serviceId": "seed_svc_19",
        "status": "done",
        "createdAt": ts(2026, 2, 10, 14, 0),
        "scheduledAt": ts(2026, 2, 14, 10, 0),
    },
    {
        "id": "seed_booking_21",
        "customerId": "seed_user_20",
        "providerId": "seed_user_08",
        "serviceId": "seed_svc_14",
        "status": "done",
        "createdAt": ts(2026, 2, 17, 9, 30),
        "scheduledAt": ts(2026, 2, 21, 8, 0),
    },
    {
        "id": "seed_booking_22",
        "customerId": "seed_user_15",
        "providerId": "seed_user_11",
        "serviceId": "seed_svc_20",
        "status": "done",
        "createdAt": ts(2026, 3, 3, 11, 0),
        "scheduledAt": ts(2026, 3, 7, 9, 30),
    },
    # --- accepted (3) ---
    {
        "id": "seed_booking_23",
        "customerId": "seed_user_17",
        "providerId": "seed_user_12",
        "serviceId": "seed_svc_23",
        "status": "accepted",
        "createdAt": ts(2026, 4, 1, 10, 0),
        "scheduledAt": ts(2026, 4, 6, 9, 0),
    },
    {
        "id": "seed_booking_24",
        "customerId": "seed_user_16",
        "providerId": "seed_user_04",
        "serviceId": "seed_svc_06",
        "status": "accepted",
        "createdAt": ts(2026, 4, 8, 14, 0),
        "scheduledAt": ts(2026, 4, 12, 8, 0),
    },
    {
        "id": "seed_booking_25",
        "customerId": "seed_user_13",
        "providerId": "seed_user_09",
        "serviceId": "seed_svc_14",
        "status": "accepted",
        "createdAt": ts(2026, 4, 15, 9, 0),
        "scheduledAt": ts(2026, 4, 19, 10, 0),
    },
    # --- in_progress (2) ---
    {
        "id": "seed_booking_26",
        "customerId": "seed_user_20",
        "providerId": "seed_user_03",
        "serviceId": "seed_svc_28",
        "status": "in_progress",
        "createdAt": ts(2026, 5, 1, 8, 0),
        "scheduledAt": ts(2026, 5, 5, 9, 0),
    },
    {
        "id": "seed_booking_27",
        "customerId": "seed_user_18",
        "providerId": "seed_user_06",
        "serviceId": "seed_svc_10",
        "status": "in_progress",
        "createdAt": ts(2026, 5, 8, 10, 0),
        "scheduledAt": ts(2026, 5, 13, 8, 30),
    },
    # --- requested (2) ---
    {
        "id": "seed_booking_28",
        "customerId": "seed_user_19",
        "providerId": "seed_user_05",
        "serviceId": "seed_svc_09",
        "status": "requested",
        "createdAt": ts(2026, 5, 15, 11, 0),
        "scheduledAt": ts(2026, 5, 20, 9, 0),
    },
    {
        "id": "seed_booking_29",
        "customerId": "seed_user_14",
        "providerId": "seed_user_11",
        "serviceId": "seed_svc_22",
        "status": "requested",
        "createdAt": ts(2026, 5, 18, 14, 30),
        "scheduledAt": ts(2026, 5, 23, 10, 0),
    },
    # --- cancelled (1) ---
    {
        "id": "seed_booking_30",
        "customerId": "seed_user_15",
        "providerId": "seed_user_07",
        "serviceId": "seed_svc_17",
        "status": "cancelled",
        "createdAt": ts(2026, 3, 20, 9, 0),
        "scheduledAt": ts(2026, 3, 25, 10, 0),
    },
]

print("\n=== TÂCHE 1 : Bookings ===")
booking_count = 0
for b in BOOKINGS:
    data = {**b, "_seeded": True}
    doc_id = data.pop("id")
    if upsert("bookings", doc_id, data):
        booking_count += 1

# ===========================================================================
# TÂCHE 2 — 15 reviews supplémentaires (liées aux 7 bookings done)
# ===========================================================================
# Bookings done : 16, 17, 18, 19, 20, 21, 22
# On fait 2 reviews par booking done (client + provider) sauf dernier => 7x2=14 + 1 = 15

REVIEWS = [
    # booking_16 : seed_user_16 (client) -> seed_user_01 (provider)
    {
        "id": "seed_review_11",
        "bookingId": "seed_booking_16",
        "reviewerId": "seed_user_16",
        "revieweeId": "seed_user_01",
        "reviewerRole": "client",
        "rating": 5,
        "comment": "Propre et efficace. Appartement nickel en 2 heures.",
        "createdAt": ts(2026, 1, 10, 15, 0),
    },
    {
        "id": "seed_review_12",
        "bookingId": "seed_booking_16",
        "reviewerId": "seed_user_01",
        "revieweeId": "seed_user_16",
        "reviewerRole": "provider",
        "rating": 5,
        "comment": "Client disponible et accueillant. Bonne expérience.",
        "createdAt": ts(2026, 1, 10, 16, 0),
    },
    # booking_17 : seed_user_13 -> seed_user_05
    {
        "id": "seed_review_13",
        "bookingId": "seed_booking_17",
        "reviewerId": "seed_user_13",
        "revieweeId": "seed_user_05",
        "reviewerRole": "client",
        "rating": 4,
        "comment": "Bonne intervention, fuite réparée rapidement.",
        "createdAt": ts(2026, 1, 16, 11, 0),
    },
    {
        "id": "seed_review_14",
        "bookingId": "seed_booking_17",
        "reviewerId": "seed_user_05",
        "revieweeId": "seed_user_13",
        "reviewerRole": "provider",
        "rating": 4,
        "comment": "Client sérieux, accès facile.",
        "createdAt": ts(2026, 1, 16, 12, 30),
    },
    # booking_18 : seed_user_19 -> seed_user_07
    {
        "id": "seed_review_15",
        "bookingId": "seed_booking_18",
        "reviewerId": "seed_user_19",
        "revieweeId": "seed_user_07",
        "reviewerRole": "client",
        "rating": 5,
        "comment": "Jardin transformé, travail soigné.",
        "createdAt": ts(2026, 1, 25, 14, 0),
    },
    {
        "id": "seed_review_16",
        "bookingId": "seed_booking_18",
        "reviewerId": "seed_user_07",
        "revieweeId": "seed_user_19",
        "reviewerRole": "provider",
        "rating": 5,
        "comment": "Très bonne cliente, recommande.",
        "createdAt": ts(2026, 1, 25, 15, 30),
    },
    # booking_19 : seed_user_14 -> seed_user_02
    {
        "id": "seed_review_17",
        "bookingId": "seed_booking_19",
        "reviewerId": "seed_user_14",
        "revieweeId": "seed_user_02",
        "reviewerRole": "client",
        "rating": 4,
        "comment": "Bon travail mais un peu en retard.",
        "createdAt": ts(2026, 2, 8, 13, 0),
    },
    {
        "id": "seed_review_18",
        "bookingId": "seed_booking_19",
        "reviewerId": "seed_user_02",
        "revieweeId": "seed_user_14",
        "reviewerRole": "provider",
        "rating": 4,
        "comment": "Client compréhensif, espace bien entretenu.",
        "createdAt": ts(2026, 2, 8, 14, 0),
    },
    # booking_20 : seed_user_18 -> seed_user_10
    {
        "id": "seed_review_19",
        "bookingId": "seed_booking_20",
        "reviewerId": "seed_user_18",
        "revieweeId": "seed_user_10",
        "reviewerRole": "client",
        "rating": 3,
        "comment": "Rapport qualité-prix correct, rien de plus.",
        "createdAt": ts(2026, 2, 15, 16, 0),
    },
    {
        "id": "seed_review_20",
        "bookingId": "seed_booking_20",
        "reviewerId": "seed_user_10",
        "revieweeId": "seed_user_18",
        "reviewerRole": "provider",
        "rating": 4,
        "comment": "Client ponctuel, instructions claires.",
        "createdAt": ts(2026, 2, 15, 17, 0),
    },
    # booking_21 : seed_user_20 -> seed_user_08
    {
        "id": "seed_review_21",
        "bookingId": "seed_booking_21",
        "reviewerId": "seed_user_20",
        "revieweeId": "seed_user_08",
        "reviewerRole": "client",
        "rating": 5,
        "comment": "Peinture impeccable, délai respecté.",
        "createdAt": ts(2026, 2, 22, 10, 0),
    },
    {
        "id": "seed_review_22",
        "bookingId": "seed_booking_21",
        "reviewerId": "seed_user_08",
        "revieweeId": "seed_user_20",
        "reviewerRole": "provider",
        "rating": 5,
        "comment": "Client agréable, chantier bien préparé.",
        "createdAt": ts(2026, 2, 22, 11, 0),
    },
    # booking_22 : seed_user_15 -> seed_user_11
    {
        "id": "seed_review_23",
        "bookingId": "seed_booking_22",
        "reviewerId": "seed_user_15",
        "revieweeId": "seed_user_11",
        "reviewerRole": "client",
        "rating": 4,
        "comment": "Rapide et efficace.",
        "createdAt": ts(2026, 3, 8, 12, 0),
    },
    {
        "id": "seed_review_24",
        "bookingId": "seed_booking_22",
        "reviewerId": "seed_user_11",
        "revieweeId": "seed_user_15",
        "reviewerRole": "provider",
        "rating": 4,
        "comment": "Bon client, règlement immédiat.",
        "createdAt": ts(2026, 3, 8, 13, 0),
    },
    # 15e review : client seul sur booking_16 (doublon évité : client de booking_20 sur 17)
    {
        "id": "seed_review_25",
        "bookingId": "seed_booking_17",
        "reviewerId": "seed_user_13",
        "revieweeId": "seed_user_05",
        "reviewerRole": "client",
        "rating": 5,
        "comment": "Exactement ce que j'attendais.",
        "createdAt": ts(2026, 1, 17, 9, 0),
    },
]

print("\n=== TÂCHE 2 : Reviews ===")
review_count = 0
for r in REVIEWS:
    data = {**r, "_seeded": True}
    doc_id = data.pop("id")
    if upsert("reviews", doc_id, data):
        review_count += 1

# ===========================================================================
# TÂCHE 3 — 7 chats (seed_chat_09 à seed_chat_15) avec messages
# ===========================================================================
# Liés aux bookings done (16-22) et accepted (23-25)
# Format : chats/{chatId} + chats/{chatId}/messages/{msgId}

CHATS = [
    {
        "id": "seed_chat_09",
        "bookingId": "seed_booking_16",
        "participantIds": ["seed_user_16", "seed_user_01"],
        "createdAt": ts(2026, 1, 5, 9, 30),
        "lastMessageAt": ts(2026, 1, 9, 7, 45),
        "messages": [
            {"id": "msg_09_01", "senderId": "seed_user_16", "text": "Bonjour, je confirme le rendez-vous pour vendredi.", "sentAt": ts(2026, 1, 5, 9, 30)},
            {"id": "msg_09_02", "senderId": "seed_user_01", "text": "Bonjour, parfait. Je serai là vers 10h.", "sentAt": ts(2026, 1, 5, 10, 0)},
            {"id": "msg_09_03", "senderId": "seed_user_16", "text": "Super. L'adresse c'est 12 rue Thiong, Dakar Plateau.", "sentAt": ts(2026, 1, 5, 10, 15)},
            {"id": "msg_09_04", "senderId": "seed_user_01", "text": "Noté. Combien de pièces au total ?", "sentAt": ts(2026, 1, 5, 10, 20)},
            {"id": "msg_09_05", "senderId": "seed_user_16", "text": "3 pièces plus la cuisine et la salle de bain.", "sentAt": ts(2026, 1, 5, 10, 30)},
            {"id": "msg_09_06", "senderId": "seed_user_01", "text": "Pas de problème. Prévoir 2h30 environ.", "sentAt": ts(2026, 1, 5, 10, 35)},
            {"id": "msg_09_07", "senderId": "seed_user_16", "text": "Merci, à vendredi.", "sentAt": ts(2026, 1, 9, 7, 45)},
        ],
    },
    {
        "id": "seed_chat_10",
        "bookingId": "seed_booking_17",
        "participantIds": ["seed_user_13", "seed_user_05"],
        "createdAt": ts(2026, 1, 12, 11, 30),
        "lastMessageAt": ts(2026, 1, 15, 16, 0),
        "messages": [
            {"id": "msg_10_01", "senderId": "seed_user_13", "text": "Bonjour Cheikh. La fuite est sous l'évier de cuisine.", "sentAt": ts(2026, 1, 12, 11, 30)},
            {"id": "msg_10_02", "senderId": "seed_user_05", "text": "Bonjour. C'est le joint ou le tuyau ?", "sentAt": ts(2026, 1, 12, 12, 0)},
            {"id": "msg_10_03", "senderId": "seed_user_13", "text": "Je ne sais pas, de l'eau coule en continu.", "sentAt": ts(2026, 1, 12, 12, 10)},
            {"id": "msg_10_04", "senderId": "seed_user_05", "text": "OK, j'apporterai le matériel pour les deux cas.", "sentAt": ts(2026, 1, 12, 12, 20)},
            {"id": "msg_10_05", "senderId": "seed_user_13", "text": "Merci. On se voit jeudi matin alors.", "sentAt": ts(2026, 1, 12, 12, 25)},
            {"id": "msg_10_06", "senderId": "seed_user_05", "text": "Présent à 9h. Bonne journée.", "sentAt": ts(2026, 1, 12, 12, 30)},
            {"id": "msg_10_07", "senderId": "seed_user_13", "text": "Excellent travail, merci beaucoup.", "sentAt": ts(2026, 1, 15, 16, 0)},
        ],
    },
    {
        "id": "seed_chat_11",
        "bookingId": "seed_booking_18",
        "participantIds": ["seed_user_19", "seed_user_07"],
        "createdAt": ts(2026, 1, 20, 9, 0),
        "lastMessageAt": ts(2026, 1, 24, 17, 30),
        "messages": [
            {"id": "msg_11_01", "senderId": "seed_user_19", "text": "Bonjour Ousmane. Je voudrais une taille de haie et une tonte.", "sentAt": ts(2026, 1, 20, 9, 0)},
            {"id": "msg_11_02", "senderId": "seed_user_07", "text": "Bonjour. Quelle surface pour la pelouse ?", "sentAt": ts(2026, 1, 20, 9, 30)},
            {"id": "msg_11_03", "senderId": "seed_user_19", "text": "Environ 80m2. La haie fait 15m de long.", "sentAt": ts(2026, 1, 20, 9, 45)},
            {"id": "msg_11_04", "senderId": "seed_user_07", "text": "Parfait. Comptez 3h de travail. Je viens vendredi matin.", "sentAt": ts(2026, 1, 20, 10, 0)},
            {"id": "msg_11_05", "senderId": "seed_user_19", "text": "Très bien. L'adresse : cité Malick Sy, Thiès.", "sentAt": ts(2026, 1, 20, 10, 10)},
            {"id": "msg_11_06", "senderId": "seed_user_07", "text": "Noté, à vendredi 8h.", "sentAt": ts(2026, 1, 20, 10, 15)},
            {"id": "msg_11_07", "senderId": "seed_user_19", "text": "Super résultat, je suis ravie.", "sentAt": ts(2026, 1, 24, 17, 30)},
            {"id": "msg_11_08", "senderId": "seed_user_07", "text": "Merci, à bientôt.", "sentAt": ts(2026, 1, 24, 17, 45)},
        ],
    },
    {
        "id": "seed_chat_12",
        "bookingId": "seed_booking_19",
        "participantIds": ["seed_user_14", "seed_user_02"],
        "createdAt": ts(2026, 2, 3, 10, 30),
        "lastMessageAt": ts(2026, 2, 7, 13, 0),
        "messages": [
            {"id": "msg_12_01", "senderId": "seed_user_14", "text": "Bonjour Fatou. Je confirme pour samedi.", "sentAt": ts(2026, 2, 3, 10, 30)},
            {"id": "msg_12_02", "senderId": "seed_user_02", "text": "Bonjour. Quelle heure vous convient ?", "sentAt": ts(2026, 2, 3, 11, 0)},
            {"id": "msg_12_03", "senderId": "seed_user_14", "text": "9h si possible.", "sentAt": ts(2026, 2, 3, 11, 10)},
            {"id": "msg_12_04", "senderId": "seed_user_02", "text": "9h c'est parfait. 75 avenue de Clichy ?", "sentAt": ts(2026, 2, 3, 11, 20)},
            {"id": "msg_12_05", "senderId": "seed_user_14", "text": "Oui, 3e étage sans ascenseur.", "sentAt": ts(2026, 2, 3, 11, 30)},
            {"id": "msg_12_06", "senderId": "seed_user_02", "text": "Pas de souci. A samedi.", "sentAt": ts(2026, 2, 3, 11, 35)},
            {"id": "msg_12_07", "senderId": "seed_user_14", "text": "Merci pour le ménage.", "sentAt": ts(2026, 2, 7, 13, 0)},
        ],
    },
    {
        "id": "seed_chat_13",
        "bookingId": "seed_booking_21",
        "participantIds": ["seed_user_20", "seed_user_08"],
        "createdAt": ts(2026, 2, 17, 10, 0),
        "lastMessageAt": ts(2026, 2, 21, 18, 0),
        "messages": [
            {"id": "msg_13_01", "senderId": "seed_user_20", "text": "Bonjour Rokhaya. Salon 20m2, quelle couleur recommandez-vous ?", "sentAt": ts(2026, 2, 17, 10, 0)},
            {"id": "msg_13_02", "senderId": "seed_user_08", "text": "Bonjour. Un blanc cassé ou un gris clair, selon la lumière.", "sentAt": ts(2026, 2, 17, 10, 30)},
            {"id": "msg_13_03", "senderId": "seed_user_20", "text": "Pièce assez sombre, on va partir sur le blanc cassé.", "sentAt": ts(2026, 2, 17, 10, 45)},
            {"id": "msg_13_04", "senderId": "seed_user_08", "text": "Bon choix. J'apporte la peinture, deux couches prévues.", "sentAt": ts(2026, 2, 17, 11, 0)},
            {"id": "msg_13_05", "senderId": "seed_user_20", "text": "Combien de temps en tout ?", "sentAt": ts(2026, 2, 17, 11, 10)},
            {"id": "msg_13_06", "senderId": "seed_user_08", "text": "Une journée complète. Je démarre à 8h.", "sentAt": ts(2026, 2, 17, 11, 20)},
            {"id": "msg_13_07", "senderId": "seed_user_20", "text": "Parfait. Résultat impeccable, bravo.", "sentAt": ts(2026, 2, 21, 18, 0)},
        ],
    },
    {
        "id": "seed_chat_14",
        "bookingId": "seed_booking_22",
        "participantIds": ["seed_user_15", "seed_user_11"],
        "createdAt": ts(2026, 3, 3, 11, 30),
        "lastMessageAt": ts(2026, 3, 7, 15, 0),
        "messages": [
            {"id": "msg_14_01", "senderId": "seed_user_15", "text": "Bonjour Mamadou. Problème de chasse d'eau et un robinet qui fuit.", "sentAt": ts(2026, 3, 3, 11, 30)},
            {"id": "msg_14_02", "senderId": "seed_user_11", "text": "Bonjour. Je peux passer vendredi matin.", "sentAt": ts(2026, 3, 3, 12, 0)},
            {"id": "msg_14_03", "senderId": "seed_user_15", "text": "Vendredi 9h30 c'est possible ?", "sentAt": ts(2026, 3, 3, 12, 10)},
            {"id": "msg_14_04", "senderId": "seed_user_11", "text": "Oui, 9h30 c'est bon.", "sentAt": ts(2026, 3, 3, 12, 15)},
            {"id": "msg_14_05", "senderId": "seed_user_15", "text": "Merci. 8 impasse des Lilas, Blois.", "sentAt": ts(2026, 3, 3, 12, 20)},
            {"id": "msg_14_06", "senderId": "seed_user_11", "text": "Noté. A vendredi.", "sentAt": ts(2026, 3, 3, 12, 25)},
            {"id": "msg_14_07", "senderId": "seed_user_15", "text": "Tout réparé, rapide et efficace. Merci.", "sentAt": ts(2026, 3, 7, 15, 0)},
        ],
    },
    {
        "id": "seed_chat_15",
        "bookingId": "seed_booking_23",
        "participantIds": ["seed_user_17", "seed_user_12"],
        "createdAt": ts(2026, 4, 1, 10, 30),
        "lastMessageAt": ts(2026, 4, 5, 9, 0),
        "messages": [
            {"id": "msg_15_01", "senderId": "seed_user_17", "text": "Bonjour Aissatou. J'ai besoin d'une garde pour deux enfants de 3 et 5 ans.", "sentAt": ts(2026, 4, 1, 10, 30)},
            {"id": "msg_15_02", "senderId": "seed_user_12", "text": "Bonjour. Pour combien de temps par semaine ?", "sentAt": ts(2026, 4, 1, 11, 0)},
            {"id": "msg_15_03", "senderId": "seed_user_17", "text": "Trois après-midis, mercredi jeudi vendredi.", "sentAt": ts(2026, 4, 1, 11, 15)},
            {"id": "msg_15_04", "senderId": "seed_user_12", "text": "C'est faisable. De 13h à 18h ?", "sentAt": ts(2026, 4, 1, 11, 30)},
            {"id": "msg_15_05", "senderId": "seed_user_17", "text": "Oui, exactement. Vous êtes disponible dès la semaine prochaine ?", "sentAt": ts(2026, 4, 1, 11, 45)},
            {"id": "msg_15_06", "senderId": "seed_user_12", "text": "Oui dès lundi. Je vous envoie mon contrat.", "sentAt": ts(2026, 4, 1, 12, 0)},
            {"id": "msg_15_07", "senderId": "seed_user_17", "text": "Parfait. A la semaine prochaine.", "sentAt": ts(2026, 4, 5, 9, 0)},
        ],
    },
]

print("\n=== TÂCHE 3 : Chats et messages ===")
chat_count = 0
msg_count = 0

for chat in CHATS:
    messages = chat.pop("messages")
    chat_id = chat.pop("id")
    chat_data = {**chat, "_seeded": True}

    chat_ref = db.collection("chats").document(chat_id)
    chat_doc = chat_ref.get()
    if chat_doc.exists:
        print(f"  [SKIP] chats/{chat_id} existe déjà")
    else:
        chat_ref.set(chat_data)
        print(f"  [OK]   chats/{chat_id}")
        chat_count += 1

    for msg in messages:
        msg_id = msg.pop("id")
        msg_data = {**msg, "_seeded": True}
        msg_ref = chat_ref.collection("messages").document(msg_id)
        msg_doc = msg_ref.get()
        if msg_doc.exists:
            print(f"    [SKIP] messages/{msg_id}")
        else:
            msg_ref.set(msg_data)
            print(f"    [OK]   messages/{msg_id}")
            msg_count += 1

# ===========================================================================
# RÉSUMÉ
# ===========================================================================
print("\n" + "="*50)
print("RÉSUMÉ")
print("="*50)
print(f"Bookings créés  : {booking_count}/15")
print(f"Reviews créées  : {review_count}/15")
print(f"Chats créés     : {chat_count}/7")
print(f"Messages créés  : {msg_count}")
print("="*50)
print("Terminé.")
