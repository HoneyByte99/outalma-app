#!/usr/bin/env python3
"""
Seed 32 services supplémentaires : seed_svc_29 à seed_svc_60.
Idempotent : vérifie existence avant écriture.

Usage: python3 scripts/seed-services-29-60.py
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timezone

SA_PATH = "/Users/amathba/WORKSPACE/outalma/app/scripts/service-account.json"
cred = credentials.Certificate(SA_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()


def ts(year, month, day):
    return datetime(year, month, day, 10, 0, tzinfo=timezone.utc)


def upsert(col, doc_id, data):
    ref = db.collection(col).document(doc_id)
    if ref.get().exists:
        print(f"  [SKIP] {col}/{doc_id} existe déjà")
        return False
    ref.set(data)
    print(f"  [OK]   {col}/{doc_id}")
    return True


# Coordonnées
DAKAR      = {"label": "Dakar",         "latitude": 14.6928, "longitude": -17.4467, "radiusKm": 15}
PARIS93    = {"label": "Paris 93",      "latitude": 48.9356, "longitude":   2.3539, "radiusKm": 20}
ORLEANS    = {"label": "Orléans",       "latitude": 47.9029, "longitude":   1.9039, "radiusKm": 15}
CHARTRES   = {"label": "Chartres",      "latitude": 48.4484, "longitude":   1.4876, "radiusKm": 15}
BLOIS      = {"label": "Blois",         "latitude": 47.5861, "longitude":   1.3359, "radiusKm": 15}
ETAMPES    = {"label": "Étampes",       "latitude": 48.4344, "longitude":   2.1600, "radiusKm": 15}
THIES      = {"label": "Thiès",         "latitude": 14.7900, "longitude": -16.9200, "radiusKm": 15}
SAINT_LOUIS = {"label": "Saint-Louis",  "latitude": 16.0179, "longitude": -16.4896, "radiusKm": 15}

# Photos par catégorie
PHOTOS = {
    "menage":       [
        "https://images.unsplash.com/photo-1581578731548?w=900&q=80",
        "https://images.unsplash.com/photo-1527515545081?w=900&q=80",
        "https://images.unsplash.com/photo-1563453392212?w=900&q=80",
        "https://images.unsplash.com/photo-1585771724684?w=900&q=80",
    ],
    "plomberie":    [
        "https://images.unsplash.com/photo-1585771724684?w=900&q=80",
        "https://images.unsplash.com/photo-1504328345606?w=900&q=80",
        "https://images.unsplash.com/photo-1607472586893?w=900&q=80",
    ],
    "jardinage":    [
        "https://images.unsplash.com/photo-1416879595882?w=900&q=80",
        "https://images.unsplash.com/photo-1523348837708?w=900&q=80",
        "https://images.unsplash.com/photo-1599598425997?w=900&q=80",
        "https://images.unsplash.com/photo-1591857177580?w=900&q=80",
    ],
    "gardeEnfants": [
        "https://images.unsplash.com/photo-1587654780293?w=900&q=80",
        "https://images.unsplash.com/photo-1503454537195?w=900&q=80",
        "https://images.unsplash.com/photo-1516627145497?w=900&q=80",
    ],
    "electricite":  [
        "https://images.unsplash.com/photo-1621905251918?w=900&q=80",
        "https://images.unsplash.com/photo-1581244277943?w=900&q=80",
        "https://images.unsplash.com/photo-1572981779307?w=900&q=80",
    ],
    "peinture":     [
        "https://images.unsplash.com/photo-1562259929?w=900&q=80",
        "https://images.unsplash.com/photo-1589939705384?w=900&q=80",
    ],
    "bricolage":    [
        "https://images.unsplash.com/photo-1504148455328?w=900&q=80",
        "https://images.unsplash.com/photo-1530124566582?w=900&q=80",
        "https://images.unsplash.com/photo-1581783898377?w=900&q=80",
    ],
}

# ===========================================================================
# 32 services : seed_svc_29 à seed_svc_60
# Distribution : 2-3 services par provider, catégories variées
#
# seed_user_01 Moussa Diallo      -> menage, Dakar         (3 svc : 29-31)
# seed_user_02 Fatou Ndiaye       -> gardeEnfants, Paris93 (3 svc : 32-34)
# seed_user_03 Ibrahima Sow       -> electricite, Orléans  (3 svc : 35-37)
# seed_user_04 Aminata Traore     -> menage, Chartres      (3 svc : 38-40)
# seed_user_05 Cheikh Mbaye       -> plomberie, Dakar      (3 svc : 41-43)
# seed_user_06 Mariama Bah        -> gardeEnfants, Orléans (3 svc : 44-46)
# seed_user_07 Ousmane Diop       -> jardinage, Thiès      (3 svc : 47-49)
# seed_user_08 Rokhaya Sarr       -> menage, Étampes       (3 svc : 50-52)
# seed_user_09 Abdoulaye Fall     -> peinture, Saint-Louis (2 svc : 53-54)
# seed_user_10 Ndeye Cisse        -> bricolage, Paris93    (3 svc : 55-57)
# seed_user_11 Mamadou Kouyate    -> plomberie, Blois      (3 svc : 58-60)
# Total : 32 services
# ===========================================================================

SERVICES = [
    # -----------------------------------------------------------------------
    # seed_user_01 — Moussa Diallo — menage, Dakar (svc 29, 30, 31)
    # -----------------------------------------------------------------------
    {
        "id": "seed_svc_29",
        "providerId": "seed_user_01",
        "categoryId": "menage",
        "title": "Grand ménage de printemps complet",
        "description": "Nettoyage approfondi de toute la maison, placards et terrasse inclus.",
        "photos": [PHOTOS["menage"][0]],
        "priceType": "fixed",
        "price": 15000,
        "published": True,
        "serviceZones": [DAKAR],
        "createdAt": ts(2025, 11, 3),
        "_seeded": True,
    },
    {
        "id": "seed_svc_30",
        "providerId": "seed_user_01",
        "categoryId": "menage",
        "title": "Nettoyage vitres et baies vitrées",
        "description": "Lavage intérieur et extérieur de toutes les vitres, résultat impeccable.",
        "photos": [PHOTOS["menage"][1]],
        "priceType": "fixed",
        "price": 6000,
        "published": True,
        "serviceZones": [DAKAR],
        "createdAt": ts(2025, 11, 15),
        "_seeded": True,
    },
    {
        "id": "seed_svc_31",
        "providerId": "seed_user_01",
        "categoryId": "bricolage",
        "title": "Montage et installation de meubles",
        "description": "Assemblage de meubles en kit, fixations murales et réglages inclus.",
        "photos": [PHOTOS["bricolage"][0]],
        "priceType": "hourly",
        "price": 3500,
        "published": True,
        "serviceZones": [DAKAR],
        "createdAt": ts(2025, 12, 1),
        "_seeded": True,
    },
    # -----------------------------------------------------------------------
    # seed_user_02 — Fatou Ndiaye — gardeEnfants, Paris 93 (svc 32, 33, 34)
    # -----------------------------------------------------------------------
    {
        "id": "seed_svc_32",
        "providerId": "seed_user_02",
        "categoryId": "gardeEnfants",
        "title": "Garde d'enfants le mercredi journée",
        "description": "Accueil, repas, activités et sieste pour enfants de 2 à 8 ans.",
        "photos": [PHOTOS["gardeEnfants"][0]],
        "priceType": "fixed",
        "price": 8000,
        "published": True,
        "serviceZones": [PARIS93],
        "createdAt": ts(2025, 10, 10),
        "_seeded": True,
    },
    {
        "id": "seed_svc_33",
        "providerId": "seed_user_02",
        "categoryId": "gardeEnfants",
        "title": "Baby-sitting soirée et weekend",
        "description": "Garde en soirée ou le weekend, enfants à partir de 6 mois.",
        "photos": [PHOTOS["gardeEnfants"][1]],
        "priceType": "hourly",
        "price": 1500,
        "published": True,
        "serviceZones": [PARIS93],
        "createdAt": ts(2025, 10, 22),
        "_seeded": True,
    },
    {
        "id": "seed_svc_34",
        "providerId": "seed_user_02",
        "categoryId": "menage",
        "title": "Ménage domicile et repassage inclus",
        "description": "Entretien régulier de l'appartement avec repassage des chemises et draps.",
        "photos": [PHOTOS["menage"][2]],
        "priceType": "hourly",
        "price": 1800,
        "published": True,
        "serviceZones": [PARIS93],
        "createdAt": ts(2025, 11, 5),
        "_seeded": True,
    },
    # -----------------------------------------------------------------------
    # seed_user_03 — Ibrahima Sow — electricite, Orléans (svc 35, 36, 37)
    # -----------------------------------------------------------------------
    {
        "id": "seed_svc_35",
        "providerId": "seed_user_03",
        "categoryId": "electricite",
        "title": "Installation tableau électrique et disjoncteurs",
        "description": "Pose ou remplacement de tableau, mise aux normes NF C 15-100.",
        "photos": [PHOTOS["electricite"][0]],
        "priceType": "fixed",
        "price": 25000,
        "published": True,
        "serviceZones": [ORLEANS],
        "createdAt": ts(2025, 10, 8),
        "_seeded": True,
    },
    {
        "id": "seed_svc_36",
        "providerId": "seed_user_03",
        "categoryId": "electricite",
        "title": "Pose de prises et interrupteurs",
        "description": "Installation ou remplacement de prises, interrupteurs et variateurs au tarif horaire.",
        "photos": [PHOTOS["electricite"][1]],
        "priceType": "hourly",
        "price": 4500,
        "published": True,
        "serviceZones": [ORLEANS],
        "createdAt": ts(2025, 11, 20),
        "_seeded": True,
    },
    {
        "id": "seed_svc_37",
        "providerId": "seed_user_03",
        "categoryId": "bricolage",
        "title": "Petits travaux brico intérieur et extérieur",
        "description": "Fixations, serrurerie, plomberie légère et montage de meubles en kit.",
        "photos": [PHOTOS["bricolage"][1]],
        "priceType": "hourly",
        "price": 3500,
        "published": True,
        "serviceZones": [ORLEANS],
        "createdAt": ts(2025, 12, 10),
        "_seeded": True,
    },
    # -----------------------------------------------------------------------
    # seed_user_04 — Aminata Traore — menage, Chartres (svc 38, 39, 40)
    # -----------------------------------------------------------------------
    {
        "id": "seed_svc_38",
        "providerId": "seed_user_04",
        "categoryId": "menage",
        "title": "Ménage hebdomadaire appartement ou maison",
        "description": "Passage régulier chaque semaine, produits fournis, travail soigné.",
        "photos": [PHOTOS["menage"][0]],
        "priceType": "hourly",
        "price": 1600,
        "published": True,
        "serviceZones": [CHARTRES],
        "createdAt": ts(2025, 10, 5),
        "_seeded": True,
    },
    {
        "id": "seed_svc_39",
        "providerId": "seed_user_04",
        "categoryId": "menage",
        "title": "Remise en état après déménagement",
        "description": "Nettoyage complet de logement vide avant état des lieux de sortie.",
        "photos": [PHOTOS["menage"][3]],
        "priceType": "fixed",
        "price": 12000,
        "published": True,
        "serviceZones": [CHARTRES],
        "createdAt": ts(2025, 11, 12),
        "_seeded": True,
    },
    {
        "id": "seed_svc_40",
        "providerId": "seed_user_04",
        "categoryId": "gardeEnfants",
        "title": "Garde périscolaire matin et soir",
        "description": "Accompagnement école, goûter et devoirs pour enfants de 3 à 12 ans.",
        "photos": [PHOTOS["gardeEnfants"][2]],
        "priceType": "hourly",
        "price": 1400,
        "published": True,
        "serviceZones": [CHARTRES],
        "createdAt": ts(2025, 12, 3),
        "_seeded": True,
    },
    # -----------------------------------------------------------------------
    # seed_user_05 — Cheikh Mbaye — plomberie, Dakar (svc 41, 42, 43)
    # -----------------------------------------------------------------------
    {
        "id": "seed_svc_41",
        "providerId": "seed_user_05",
        "categoryId": "plomberie",
        "title": "Installation complète salle de bain neuve",
        "description": "Pose de baignoire, douche, WC et lavabo, raccordements eau et évacuation.",
        "photos": [PHOTOS["plomberie"][0]],
        "priceType": "fixed",
        "price": 80000,
        "published": True,
        "serviceZones": [DAKAR],
        "createdAt": ts(2025, 10, 18),
        "_seeded": True,
    },
    {
        "id": "seed_svc_42",
        "providerId": "seed_user_05",
        "categoryId": "plomberie",
        "title": "Remplacement chauffe-eau et ballon eau chaude",
        "description": "Dépose de l'ancien appareil, pose et mise en service du nouveau.",
        "photos": [PHOTOS["plomberie"][1]],
        "priceType": "fixed",
        "price": 35000,
        "published": True,
        "serviceZones": [DAKAR],
        "createdAt": ts(2025, 11, 28),
        "_seeded": True,
    },
    {
        "id": "seed_svc_43",
        "providerId": "seed_user_05",
        "categoryId": "electricite",
        "title": "Dépannage électrique toutes urgences",
        "description": "Panne générale, court-circuit, prise défectueuse : intervention rapide à Dakar.",
        "photos": [PHOTOS["electricite"][2]],
        "priceType": "fixed",
        "price": 10000,
        "published": True,
        "serviceZones": [DAKAR],
        "createdAt": ts(2025, 12, 15),
        "_seeded": True,
    },
    # -----------------------------------------------------------------------
    # seed_user_06 — Mariama Bah — gardeEnfants, Orléans (svc 44, 45, 46)
    # -----------------------------------------------------------------------
    {
        "id": "seed_svc_44",
        "providerId": "seed_user_06",
        "categoryId": "gardeEnfants",
        "title": "Garde d'enfants journée complète à domicile",
        "description": "Accueil 8h-18h, repas, sieste et activités adaptées à l'âge.",
        "photos": [PHOTOS["gardeEnfants"][0]],
        "priceType": "fixed",
        "price": 9000,
        "published": True,
        "serviceZones": [ORLEANS],
        "createdAt": ts(2025, 10, 12),
        "_seeded": True,
    },
    {
        "id": "seed_svc_45",
        "providerId": "seed_user_06",
        "categoryId": "gardeEnfants",
        "title": "Garde partagée plusieurs familles Orléans",
        "description": "Solution garde partagée pour deux familles, tarif réduit par enfant.",
        "photos": [PHOTOS["gardeEnfants"][1]],
        "priceType": "hourly",
        "price": 1200,
        "published": True,
        "serviceZones": [ORLEANS],
        "createdAt": ts(2025, 11, 8),
        "_seeded": True,
    },
    {
        "id": "seed_svc_46",
        "providerId": "seed_user_06",
        "categoryId": "menage",
        "title": "Ménage léger et entretien du linge",
        "description": "Passage deux fois par semaine, lessive et repassage en option.",
        "photos": [PHOTOS["menage"][1]],
        "priceType": "hourly",
        "price": 1500,
        "published": True,
        "serviceZones": [ORLEANS],
        "createdAt": ts(2025, 12, 5),
        "_seeded": True,
    },
    # -----------------------------------------------------------------------
    # seed_user_07 — Ousmane Diop — jardinage, Thiès (svc 47, 48, 49)
    # -----------------------------------------------------------------------
    {
        "id": "seed_svc_47",
        "providerId": "seed_user_07",
        "categoryId": "jardinage",
        "title": "Création et aménagement de potager",
        "description": "Préparation du sol, choix des plants, irrigation et suivi de croissance.",
        "photos": [PHOTOS["jardinage"][0]],
        "priceType": "fixed",
        "price": 25000,
        "published": True,
        "serviceZones": [THIES],
        "createdAt": ts(2025, 10, 20),
        "_seeded": True,
    },
    {
        "id": "seed_svc_48",
        "providerId": "seed_user_07",
        "categoryId": "jardinage",
        "title": "Taille arbres fruitiers et entretien verger",
        "description": "Taille de formation et fructification, traitement naturel des parasites.",
        "photos": [PHOTOS["jardinage"][1]],
        "priceType": "hourly",
        "price": 4000,
        "published": True,
        "serviceZones": [THIES],
        "createdAt": ts(2025, 11, 10),
        "_seeded": True,
    },
    {
        "id": "seed_svc_49",
        "providerId": "seed_user_07",
        "categoryId": "bricolage",
        "title": "Pose de clôture et portail de jardin",
        "description": "Installation de clôtures bois ou métal, portail battant ou coulissant.",
        "photos": [PHOTOS["bricolage"][2]],
        "priceType": "fixed",
        "price": 30000,
        "published": True,
        "serviceZones": [THIES],
        "createdAt": ts(2025, 12, 8),
        "_seeded": True,
    },
    # -----------------------------------------------------------------------
    # seed_user_08 — Rokhaya Sarr — menage, Étampes (svc 50, 51, 52)
    # -----------------------------------------------------------------------
    {
        "id": "seed_svc_50",
        "providerId": "seed_user_08",
        "categoryId": "menage",
        "title": "Nettoyage de bureaux et locaux professionnels",
        "description": "Entretien quotidien ou hebdomadaire de vos espaces professionnels, hors heures.",
        "photos": [PHOTOS["menage"][0]],
        "priceType": "hourly",
        "price": 2000,
        "published": True,
        "serviceZones": [ETAMPES],
        "createdAt": ts(2025, 10, 25),
        "_seeded": True,
    },
    {
        "id": "seed_svc_51",
        "providerId": "seed_user_08",
        "categoryId": "menage",
        "title": "Ménage après travaux et chantier",
        "description": "Aspiration poussière de plâtre, lavage sols et vitres après rénovation.",
        "photos": [PHOTOS["menage"][2]],
        "priceType": "fixed",
        "price": 10000,
        "published": True,
        "serviceZones": [ETAMPES],
        "createdAt": ts(2025, 11, 18),
        "_seeded": True,
    },
    {
        "id": "seed_svc_52",
        "providerId": "seed_user_08",
        "categoryId": "peinture",
        "title": "Peinture chambre ou salon en deux couches",
        "description": "Préparation des murs, application deux couches, finition soignée garantie.",
        "photos": [PHOTOS["peinture"][0]],
        "priceType": "fixed",
        "price": 18000,
        "published": True,
        "serviceZones": [ETAMPES],
        "createdAt": ts(2025, 12, 12),
        "_seeded": True,
    },
    # -----------------------------------------------------------------------
    # seed_user_09 — Abdoulaye Fall — peinture, Saint-Louis SN (svc 53, 54)
    # -----------------------------------------------------------------------
    {
        "id": "seed_svc_53",
        "providerId": "seed_user_09",
        "categoryId": "peinture",
        "title": "Peinture décorative et enduits texturés",
        "description": "Béton ciré, badigeon à la chaux, stucco et finitions décoratives sur mesure.",
        "photos": [PHOTOS["peinture"][1]],
        "priceType": "fixed",
        "price": 40000,
        "published": True,
        "serviceZones": [SAINT_LOUIS],
        "createdAt": ts(2025, 11, 2),
        "_seeded": True,
    },
    {
        "id": "seed_svc_54",
        "providerId": "seed_user_09",
        "categoryId": "jardinage",
        "title": "Entretien espaces verts de résidence",
        "description": "Tonte, désherbage, arrosage et taille haies pour résidences et copropriétés.",
        "photos": [PHOTOS["jardinage"][2]],
        "priceType": "fixed",
        "price": 20000,
        "published": True,
        "serviceZones": [SAINT_LOUIS],
        "createdAt": ts(2025, 12, 20),
        "_seeded": True,
    },
    # -----------------------------------------------------------------------
    # seed_user_10 — Ndeye Cisse — bricolage, Paris 93 (svc 55, 56, 57)
    # -----------------------------------------------------------------------
    {
        "id": "seed_svc_55",
        "providerId": "seed_user_10",
        "categoryId": "bricolage",
        "title": "Pose de parquet flottant toutes pièces",
        "description": "Dépose ancien revêtement, pose parquet avec sous-couche phonique incluse.",
        "photos": [PHOTOS["bricolage"][0]],
        "priceType": "fixed",
        "price": 35000,
        "published": True,
        "serviceZones": [PARIS93],
        "createdAt": ts(2025, 10, 15),
        "_seeded": True,
    },
    {
        "id": "seed_svc_56",
        "providerId": "seed_user_10",
        "categoryId": "bricolage",
        "title": "Réparation porte, serrure et volet",
        "description": "Remplacement de serrure, réglage de porte qui grince, réparation de volet roulant.",
        "photos": [PHOTOS["bricolage"][1]],
        "priceType": "hourly",
        "price": 4000,
        "published": True,
        "serviceZones": [PARIS93],
        "createdAt": ts(2025, 11, 25),
        "_seeded": True,
    },
    {
        "id": "seed_svc_57",
        "providerId": "seed_user_10",
        "categoryId": "electricite",
        "title": "Pose de luminaires et spots encastrés",
        "description": "Installation de plafonniers, lustres, spots LED et bandeau lumineux.",
        "photos": [PHOTOS["electricite"][0]],
        "priceType": "fixed",
        "price": 8000,
        "published": True,
        "serviceZones": [PARIS93],
        "createdAt": ts(2026, 1, 10),
        "_seeded": True,
    },
    # -----------------------------------------------------------------------
    # seed_user_11 — Mamadou Kouyate — plomberie, Blois (svc 58, 59, 60)
    # -----------------------------------------------------------------------
    {
        "id": "seed_svc_58",
        "providerId": "seed_user_11",
        "categoryId": "plomberie",
        "title": "Débouchage canalisations évier et WC",
        "description": "Intervention rapide avec furet ou haute pression, sans dégâts aux tuyaux.",
        "photos": [PHOTOS["plomberie"][1]],
        "priceType": "fixed",
        "price": 8000,
        "published": True,
        "serviceZones": [BLOIS],
        "createdAt": ts(2025, 10, 28),
        "_seeded": True,
    },
    {
        "id": "seed_svc_59",
        "providerId": "seed_user_11",
        "categoryId": "plomberie",
        "title": "Remplacement robinetterie cuisine et salle de bain",
        "description": "Dépose de l'ancien robinet, pose du nouveau mitigeur, test étanchéité compris.",
        "photos": [PHOTOS["plomberie"][2]],
        "priceType": "fixed",
        "price": 12000,
        "published": True,
        "serviceZones": [BLOIS],
        "createdAt": ts(2025, 12, 5),
        "_seeded": True,
    },
    {
        "id": "seed_svc_60",
        "providerId": "seed_user_11",
        "categoryId": "jardinage",
        "title": "Taille de haies et débroussaillage terrain",
        "description": "Taille haies vives, débroussaillage de terrains en friche, évacuation incluse.",
        "photos": [PHOTOS["jardinage"][3]],
        "priceType": "hourly",
        "price": 3500,
        "published": True,
        "serviceZones": [BLOIS],
        "createdAt": ts(2026, 1, 15),
        "_seeded": True,
    },
]

# ===========================================================================
# EXÉCUTION
# ===========================================================================
print(f"\n=== Seed services seed_svc_29 à seed_svc_60 ({len(SERVICES)} services) ===\n")

created = 0
skipped = 0

for svc in SERVICES:
    data = {**svc}
    doc_id = data.pop("id")
    if upsert("services", doc_id, data):
        created += 1
    else:
        skipped += 1

print("\n" + "=" * 50)
print("RÉSUMÉ")
print("=" * 50)
print(f"Services créés  : {created}/{len(SERVICES)}")
print(f"Services skippés: {skipped}/{len(SERVICES)}")
print("=" * 50)
print("Terminé.")
