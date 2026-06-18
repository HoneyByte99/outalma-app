#!/usr/bin/env python3
"""
Seed Firestore : chats seed_chat_16 à seed_chat_40 avec messages.
Idempotent : skip si le document existe déjà.
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timezone
import sys

SA_PATH = "/Users/amathba/WORKSPACE/outalma/app/scripts/service-account.json"
cred = credentials.Certificate(SA_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()


def ts(year, month, day, hour=10, minute=0):
    return datetime(year, month, day, hour, minute, tzinfo=timezone.utc)


def upsert_chat(chat_id, data):
    ref = db.collection("chats").document(chat_id)
    if ref.get().exists:
        print(f"  [SKIP] chats/{chat_id}")
        return False
    ref.set(data)
    print(f"  [OK]   chats/{chat_id}")
    return True


def upsert_msg(chat_id, msg_id, data):
    ref = db.collection("chats").document(chat_id).collection("messages").document(msg_id)
    if ref.get().exists:
        print(f"  [SKIP] chats/{chat_id}/messages/{msg_id}")
        return False
    ref.set(data)
    print(f"  [OK]   chats/{chat_id}/messages/{msg_id}")
    return True


# Mapping booking -> (customer, provider)
MAPPING = {
    31: (13, 1),
    32: (14, 2),
    33: (15, 3),
    34: (16, 4),
    35: (17, 5),
    36: (18, 6),
    37: (19, 7),
    38: (20, 8),
    39: (13, 9),
    40: (14, 10),
    41: (15, 11),
    42: (16, 12),
    43: (17, 1),
    44: (18, 2),
    45: (19, 3),
    46: (20, 4),
    47: (13, 5),
    48: (14, 6),
    49: (15, 7),
    50: (16, 8),
    51: (17, 9),
    52: (18, 10),
    53: (19, 11),
    54: (20, 12),
    55: (13, 3),
}

# chat_num (16..40) -> booking_num (31..55)
CHAT_TO_BOOKING = {16 + i: 31 + i for i in range(25)}

# Conversations variées en français, sans tirets cadratin
# Format : liste de (sender_role, texte) — role = "c" (customer) ou "p" (provider)
CONVERSATIONS = {
    16: [
        ("c", "Bonjour, je viens de confirmer la réservation. Vous êtes disponible le jour prévu ?"),
        ("p", "Bonjour ! Oui, c'est noté de mon côté. Je serai là à l'heure convenue."),
        ("c", "Super. Faut-il prévoir quelque chose de particulier avant votre arrivée ?"),
        ("p", "Non, rien de spécial. Je viens avec tout le matériel nécessaire."),
        ("c", "Parfait, merci. À bientôt."),
    ],
    17: [
        ("c", "Bonjour, ma demande vient d'être acceptée. Pouvez-vous me confirmer l'heure exacte ?"),
        ("p", "Bonjour ! Je serai chez vous entre 9h et 9h30."),
        ("c", "Très bien. L'adresse est bien la même que celle indiquée dans la réservation ?"),
        ("p", "Oui, j'ai bien noté votre adresse. Pas de problème."),
        ("c", "Merci, à demain alors."),
        ("p", "À demain. Bonne journée."),
    ],
    18: [
        ("p", "Bonjour, je voulais juste confirmer que j'ai bien reçu votre demande."),
        ("c", "Bonjour, oui merci. Est-ce que l'intervention dure environ combien de temps ?"),
        ("p", "Comptez à peu près deux heures selon l'état du chantier."),
        ("c", "D'accord, je libère la matinée."),
        ("p", "Parfait. On se voit à l'heure prévue."),
        ("c", "Merci, à bientôt."),
    ],
    19: [
        ("c", "Bonjour, une petite question : est-ce que je dois dégager la pièce avant votre venue ?"),
        ("p", "Bonjour ! Ce serait idéal, oui. Laissez un accès libre d'environ un mètre autour de la zone."),
        ("c", "Je m'en occupe ce soir. Pas de souci."),
        ("p", "Merci, ce sera plus pratique pour moi aussi."),
        ("c", "À jeudi donc."),
        ("p", "À jeudi."),
        ("c", "Bonne soirée."),
    ],
    20: [
        ("c", "Bonjour, pouvez-vous me rappeler le tarif exact ? Je veux être sûr d'avoir le bon montant."),
        ("p", "Bonjour ! Le montant est bien celui indiqué dans la réservation. Aucun supplément prévu."),
        ("c", "Très bien, merci de le confirmer."),
        ("p", "Avec plaisir. Si vous avez d'autres questions, n'hésitez pas."),
        ("c", "Non, c'est bon. À mercredi."),
    ],
    21: [
        ("p", "Bonjour, j'ai accepté votre demande. À quelle heure vous convient-il que je passe ?"),
        ("c", "Bonjour ! De préférence en matinée, avant 11h si possible."),
        ("p", "Je serai là à 9h30 alors."),
        ("c", "Parfait. Je vous laisse la clé de la boite aux lettres si jamais je suis en bas."),
        ("p", "Super, merci de me prévenir si c'est le cas. À bientôt."),
        ("c", "À bientôt."),
    ],
    22: [
        ("c", "Bonjour, tout est confirmé de votre côté ?"),
        ("p", "Bonjour, oui c'est bien noté. Je n'ai aucun conflit dans mon agenda."),
        ("c", "Bien. Est-ce qu'il faut que j'achète des fournitures avant ?"),
        ("p", "Non, je gère tout. Vous n'avez rien à prévoir."),
        ("c", "Excellent. Merci."),
        ("p", "À vendredi alors."),
        ("c", "À vendredi, bonne journée."),
    ],
    23: [
        ("c", "Bonjour, j'ai une contrainte : je dois partir à 13h. Ça pose un problème ?"),
        ("p", "Bonjour ! Non, on devrait finir bien avant. L'intervention prend environ une heure et demie."),
        ("c", "Très bien, ça me convient."),
        ("p", "On commence à 10h, vous serez libre à 11h30 au plus tard."),
        ("c", "Parfait, merci pour la précision."),
    ],
    24: [
        ("p", "Bonjour, votre réservation est bien confirmée. Avez-vous des préférences particulières ?"),
        ("c", "Bonjour ! Pas vraiment, je vous fais confiance pour le déroulement."),
        ("p", "Très bien. Je m'adapte toujours aux besoins du client."),
        ("c", "Super. Hâte de voir le résultat."),
        ("p", "Je ferai mon possible pour que vous soyez satisfait. À bientôt."),
        ("c", "À bientôt, merci."),
    ],
    25: [
        ("c", "Bonjour, pouvez-vous venir en fin d'après-midi plutôt que le matin ?"),
        ("p", "Bonjour ! Je vais vérifier mon planning... Oui, 17h c'est possible."),
        ("c", "Parfait, 17h me convient très bien."),
        ("p", "Noté, je mets ça à jour de mon côté."),
        ("c", "Merci de votre flexibilité."),
        ("p", "Pas de problème. À bientôt."),
    ],
    26: [
        ("c", "Bonjour, tout s'est bien passé, merci beaucoup pour votre intervention."),
        ("p", "Bonjour ! Content que tout soit à votre satisfaction."),
        ("c", "Le travail est vraiment soigné. Je vous recommanderai sans hésiter."),
        ("p", "C'est très gentil, merci. N'hésitez pas à refaire appel à moi."),
        ("c", "Je n'y manquerai pas. Bonne continuation."),
        ("p", "Merci à vous. À la prochaine."),
    ],
    27: [
        ("p", "Bonjour, je serai chez vous à 10h comme prévu."),
        ("c", "Bonjour, merci de me le confirmer. Je serai là."),
        ("p", "Y a-t-il un code d'entrée pour l'immeuble ?"),
        ("c", "Oui, le code est le B1234. Sonnez au 3e étage."),
        ("p", "Noté, merci. À tout à l'heure."),
        ("c", "À tout à l'heure."),
        ("p", "Tout est terminé. Le résultat est propre, bonne journée."),
        ("c", "Merci beaucoup ! Excellente journée à vous aussi."),
    ],
    28: [
        ("c", "Bonjour, est-ce qu'il faut que je signe quelque chose à la fin ?"),
        ("p", "Bonjour ! Pas de signature nécessaire, on passe tout par l'application."),
        ("c", "Ah très bien, plus simple comme ça."),
        ("p", "Exactement. Vous confirmez juste depuis l'appli une fois que c'est terminé."),
        ("c", "D'accord, je l'ai déjà fait. Merci."),
    ],
    29: [
        ("c", "Bonjour, je suis disponible toute la journée le jour J. Venez quand vous voulez."),
        ("p", "Bonjour ! Je préfère venir le matin pour être plus efficace. Disons 8h30 ?"),
        ("c", "8h30 c'est un peu tôt pour moi. 9h30 serait mieux."),
        ("p", "9h30, c'est noté. À demain."),
        ("c", "À demain. Bonne soirée."),
        ("p", "Bonne soirée à vous."),
    ],
    30: [
        ("p", "Bonjour, avez-vous des animaux chez vous ? Je dois le savoir pour me préparer."),
        ("c", "Bonjour, oui j'ai un chat mais il ne pose aucun problème. Je le confine dans une autre pièce si besoin."),
        ("p", "Parfait, pas de souci de mon côté non plus."),
        ("c", "Super, merci de l'avoir demandé."),
        ("p", "C'est plus simple de le savoir à l'avance. À bientôt."),
        ("c", "À bientôt."),
    ],
    31: [
        ("c", "Bonjour, la prestation a bien eu lieu hier. Tout s'est très bien passé."),
        ("p", "Bonjour ! Merci, je suis content que vous soyez satisfait."),
        ("c", "Je vous mets une bonne note sur l'application."),
        ("p", "Merci beaucoup, c'est important pour moi."),
        ("c", "Vous le méritez. Bonne continuation."),
    ],
    32: [
        ("c", "Bonjour, je voulais juste savoir si vous avez besoin que j'achète des piles ou des accessoires ?"),
        ("p", "Bonjour ! Non, j'ai tout le matériel avec moi. Rien à prévoir de votre côté."),
        ("c", "Parfait, merci."),
        ("p", "Je serai ponctuel, pas d'inquiétude."),
        ("c", "J'en suis sûr. À bientôt."),
        ("p", "À très bientôt."),
    ],
    33: [
        ("p", "Bonjour, je tenais à vous dire que j'ai été très bien accueilli. Merci."),
        ("c", "Bonjour ! Tout le plaisir était pour moi. Votre travail était impeccable."),
        ("p", "Merci, c'est toujours agréable à entendre."),
        ("c", "N'hésitez pas si vous avez d'autres créneaux disponibles dans le mois."),
        ("p", "Je vous enverrai un message si un créneau se libère."),
        ("c", "Super, merci encore."),
    ],
    34: [
        ("c", "Bonjour, c'est bon pour vous si j'invite un ami pour observer le travail ?"),
        ("p", "Bonjour ! Oui, pas de problème, à condition qu'il reste à l'écart de la zone."),
        ("c", "Bien sûr, on ne va pas vous gêner."),
        ("p", "Parfait. À mercredi."),
        ("c", "À mercredi."),
    ],
    35: [
        ("c", "Bonjour, l'intervention a duré moins longtemps que prévu. Ça se passe bien ?"),
        ("p", "Bonjour ! Oui, tout s'est bien déroulé. Je travaille de manière efficace quand les conditions sont bonnes."),
        ("c", "C'est rassurant. Merci pour tout."),
        ("p", "Avec plaisir. N'hésitez pas à refaire appel à moi."),
        ("c", "C'est noté. Bonne journée."),
        ("p", "Bonne journée."),
        ("c", "Merci encore."),
    ],
    36: [
        ("p", "Bonjour, je voulais confirmer votre adresse avant de partir."),
        ("c", "Bonjour ! C'est le 8 avenue des Lilas, bâtiment C, interphone 24."),
        ("p", "Noté, merci. Je serai là dans environ 20 minutes."),
        ("c", "Je descends vous ouvrir si vous avez du mal avec l'interphone."),
        ("p", "Ce serait sympa, merci. À tout de suite."),
        ("c", "À tout de suite."),
    ],
    37: [
        ("c", "Bonjour, le paiement se fait comment exactement via l'application ?"),
        ("p", "Bonjour ! Le paiement est géré automatiquement par la plateforme. Vous n'avez rien à faire manuellement."),
        ("c", "Ah bien, c'est simple alors."),
        ("p", "Exactement. Tout est sécurisé."),
        ("c", "Merci de l'explication."),
        ("p", "De rien. À bientôt."),
    ],
    38: [
        ("c", "Bonjour, j'aurais un service supplémentaire à vous soumettre si vous en avez la compétence."),
        ("p", "Bonjour ! Dites-moi, je vous dirai si c'est dans mon domaine."),
        ("c", "Il s'agit d'un second point à traiter dans la même pièce."),
        ("p", "Oui, je peux le faire en même temps. On verra ça sur place."),
        ("c", "Super, merci. À bientôt."),
        ("p", "À bientôt."),
    ],
    39: [
        ("p", "Bonjour, tout est terminé. Êtes-vous satisfait du résultat ?"),
        ("c", "Bonjour ! Oui, très satisfait. C'était exactement ce que je cherchais."),
        ("p", "Merci, c'est le plus important."),
        ("c", "Je vais confirmer sur l'application maintenant."),
        ("p", "Merci. Bonne journée à vous."),
        ("c", "À vous aussi."),
    ],
    40: [
        ("c", "Bonjour, je voulais juste confirmer que nous sommes bien d'accord sur le périmètre de l'intervention."),
        ("p", "Bonjour ! Oui, tout est clair. Je m'occupe exactement de ce qui est indiqué dans la demande."),
        ("c", "Parfait. Merci pour la clarté."),
        ("p", "C'est important d'être alignés. À bientôt."),
        ("c", "À bientôt."),
    ],
}


def run():
    total_chats_created = 0
    total_msgs_created = 0
    total_chats_skipped = 0
    total_msgs_skipped = 0

    # Base dates : étalement sur février-avril 2026
    base_dates = {
        16: (2026, 2, 1),
        17: (2026, 2, 3),
        18: (2026, 2, 5),
        19: (2026, 2, 7),
        20: (2026, 2, 9),
        21: (2026, 2, 11),
        22: (2026, 2, 13),
        23: (2026, 2, 15),
        24: (2026, 2, 17),
        25: (2026, 2, 19),
        26: (2026, 2, 21),
        27: (2026, 2, 23),
        28: (2026, 2, 25),
        29: (2026, 2, 27),
        30: (2026, 3, 1),
        31: (2026, 3, 3),
        32: (2026, 3, 5),
        33: (2026, 3, 7),
        34: (2026, 3, 9),
        35: (2026, 3, 11),
        36: (2026, 3, 13),
        37: (2026, 3, 15),
        38: (2026, 3, 17),
        39: (2026, 3, 19),
        40: (2026, 3, 21),
    }

    for chat_num in range(16, 41):
        booking_num = CHAT_TO_BOOKING[chat_num]
        cust_num, prov_num = MAPPING[booking_num]

        customer_id = f"seed_user_{cust_num:02d}"
        provider_id = f"seed_user_{prov_num:02d}"
        chat_id = f"seed_chat_{chat_num:02d}"
        booking_id = f"seed_booking_{booking_num}"

        y, mo, d = base_dates[chat_num]
        created_at = ts(y, mo, d, 8, 0)

        conversation = CONVERSATIONS[chat_num]
        # last message offset in minutes (max ~70 min for 8 msgs, stays within same hour+)
        last_msg_offset = 10 * (len(conversation) - 1)
        total_minutes = 8 * 60 + last_msg_offset
        last_msg_at = ts(y, mo, d, total_minutes // 60, total_minutes % 60)

        chat_data = {
            "bookingId": booking_id,
            "customerId": customer_id,
            "providerId": provider_id,
            "participantIds": [customer_id, provider_id],
            "createdAt": created_at,
            "lastMessageAt": last_msg_at,
            "_seeded": True,
        }

        print(f"\n--- {chat_id} (booking={booking_id}, cust={customer_id}, prov={provider_id}) ---")
        created = upsert_chat(chat_id, chat_data)
        if created:
            total_chats_created += 1
        else:
            total_chats_skipped += 1

        for msg_idx, (role, text) in enumerate(conversation):
            msg_num = msg_idx + 1
            msg_id = f"seed_msg_{chat_num:02d}_{msg_num:02d}"
            sender_id = customer_id if role == "c" else provider_id
            other_id = provider_id if role == "c" else customer_id
            msg_offset_min = 10 * msg_idx
            msg_total = 8 * 60 + msg_offset_min
            msg_at = ts(y, mo, d, msg_total // 60, msg_total % 60)

            msg_data = {
                "chatId": chat_id,
                "senderId": sender_id,
                "type": "text",
                "text": text,
                "readBy": [sender_id, other_id],
                "createdAt": msg_at,
                "_seeded": True,
            }

            msg_created = upsert_msg(chat_id, msg_id, msg_data)
            if msg_created:
                total_msgs_created += 1
            else:
                total_msgs_skipped += 1

    print("\n=============================")
    print(f"Chats crees   : {total_chats_created}")
    print(f"Chats skipped : {total_chats_skipped}")
    print(f"Msgs crees    : {total_msgs_created}")
    print(f"Msgs skipped  : {total_msgs_skipped}")
    print("=============================")


if __name__ == "__main__":
    run()
