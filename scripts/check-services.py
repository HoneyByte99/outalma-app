#!/usr/bin/env python3
"""
Check all 28 seed services in Firestore for:
- description non vide (5-15 mots)
- price coherent
- published: true
Patch any anomalies directly in Firestore.

Usage: python3 scripts/check-services.py
"""
import sys
import warnings
warnings.filterwarnings("ignore")

from pathlib import Path

SERVICE_ACCOUNT = Path(__file__).parent / "service-account.json"

# Fallback descriptions for services with missing/short descriptions
FALLBACK_DESCRIPTIONS = {
    "seed_svc_01": "Nettoyage complet de maison ou appartement, toutes surfaces.",
    "seed_svc_02": "Remise en etat apres chantier, poussiere et vitres inclus.",
    "seed_svc_03": "Entretien regulier hebdomadaire ou bimensuel de votre appartement.",
    "seed_svc_04": "Reparation de fuites, joints et robinetterie, intervention rapide.",
    "seed_svc_05": "Pose de douche, baignoire, WC ou lavabo, neuf ou remplacement.",
    "seed_svc_06": "Tonte, desherbage, taille de haies, forfait mensuel ou ponctuel.",
    "seed_svc_07": "Conception et mise en place de massifs fleuris adaptes au sol.",
    "seed_svc_08": "Pose et mise en service de pompes pour puits et forages.",
    "seed_svc_09": "Debouchage rapide de WC, evier, douche et canalisation principale.",
    "seed_svc_10": "Garde en journee ou apres l'ecole pour enfants de 2 a 10 ans.",
    "seed_svc_11": "Garde a domicile en soiree et le weekend pour vos enfants.",
    "seed_svc_12": "Panne de courant, prises defectueuses, intervention rapide a Dakar.",
    "seed_svc_13": "Diagnostic et remise aux normes de l'installation electrique.",
    "seed_svc_14": "Preparation des surfaces et application de peinture de qualite.",
    "seed_svc_15": "Nettoyage, reparation des fissures et peinture de facade.",
    "seed_svc_16": "Nettoyage de cours, taille d'arbres fruitiers et entretien de potager.",
    "seed_svc_17": "Conseil et realisation de jardins tropicaux avec especes locales.",
    "seed_svc_18": "Passage hebdomadaire avec vos produits ou les miens, travail soigne.",
    "seed_svc_19": "Nettoyage complet de l'appartement, placards et vitres inclus.",
    "seed_svc_20": "Montage de meubles, fixation de tableaux, etageres et tringles.",
    "seed_svc_21": "Portes, serrures, robinets : petits travaux sans chantier.",
    "seed_svc_22": "Depose de l'ancien revetement et pose de parquet flottant.",
    "seed_svc_23": "Garde de bebes des 3 mois, journee complete ou demi-journee.",
    "seed_svc_24": "Recupeartion a l'ecole, gouter, devoirs et activites jusqu'au retour.",
    "seed_svc_25": "Entretien de bureaux et espaces professionnels hors heures d'ouverture.",
    "seed_svc_26": "Pose et mise en service de climatiseurs split, toutes marques.",
    "seed_svc_27": "Beton cire, stucco, badigeon a la chaux et murs textures.",
    "seed_svc_28": "Remise en etat de lave-linge, seche-linge et lave-vaisselle.",
}

def count_words(text):
    return len(text.strip().split())


def main():
    import firebase_admin
    from firebase_admin import credentials, firestore

    if not firebase_admin._apps:
        cred = credentials.Certificate(str(SERVICE_ACCOUNT))
        firebase_admin.initialize_app(cred)

    db = firestore.client()

    print("\nChecking seeded services in Firestore...")
    docs = list(db.collection("services").where("_seeded", "==", True).stream())
    print(f"  Found {len(docs)} seeded services\n")

    anomalies = []
    patched = 0

    for doc in docs:
        data = doc.to_dict() or {}
        doc_id = doc.id
        issues = []
        patch = {}

        # Check published
        if not data.get("published", False):
            issues.append("published missing/false")
            patch["published"] = True

        # Check description
        desc = data.get("description", "")
        wc = count_words(desc) if desc else 0
        if wc < 5:
            issues.append(f"description too short ({wc} words): '{desc[:40]}'")
            fallback = FALLBACK_DESCRIPTIONS.get(doc_id)
            if fallback:
                patch["description"] = fallback
            else:
                issues.append("  -> no fallback available, manual fix needed")

        # Check price
        price = data.get("price", 0)
        price_type = data.get("priceType", "")
        if not price or price <= 0:
            issues.append(f"price invalid: {price}")

        if issues:
            anomalies.append((doc_id, issues))
            print(f"  ANOMALY {doc_id}:")
            for iss in issues:
                print(f"    - {iss}")
            if patch:
                doc.reference.update(patch)
                print(f"    -> patched: {list(patch.keys())}")
                patched += 1
        else:
            print(f"  OK {doc_id} ({data.get('categoryId')}) — {wc} words, price={price} {price_type}, published={data.get('published')}")

    print(f"\nSummary: {len(docs)} services checked, {len(anomalies)} anomalies found, {patched} patched.")


if __name__ == "__main__":
    main()
