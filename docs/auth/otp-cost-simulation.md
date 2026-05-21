# OTP Cost Simulation — 4 Providers × 3 Volumes

> Date : mai 2026 — basé sur les tarifs publics fetchés dans `otp-benchmark.md`.
> Ces chiffres sont **indicatifs** : les prix réels en console peuvent varier ±20% selon FX, frais opérateurs, négociations volume.

## Hypothèses

| Variable | Valeur |
|---|---|
| Mix géographique | 70% France / 30% Sénégal |
| Taux de retry (utilisateur ne reçoit pas, en redemande) | 15% |
| Taux de fallback Voice (SMS échoué après retry) | 5% |
| Durée appel Voice | 30 secondes |
| Taux de réussite global (PIN matched) | 85% |

> Note importante : Twilio Verify et Vonage Verify ne facturent le "platform fee" qu'au succès. Mais les SMS d'attempts sont facturés tous. Firebase Phone Auth facture chaque SMS, succès ou non.

## Scénarios de volume

### Scénario A — MVP early (< 1 000 / mois)

Hypothèse : **800 vérifications** lancées / mois (signups + connexions par téléphone).

| Provider | Calcul | Coût mensuel | Notes |
|---|---|---|---|
| **Firebase Phone Auth** | 800 × 1.15 retries = 920 SMS<br>– 300 free<br>= 620 SMS × $0.06 | **~$37/mois** | Free tier mange 1/3 du volume |
| **Twilio Verify** | 920 SMS · 70% FR ($0.0798) + 30% SN ($0.5506)<br>+ 0.85 × 800 platform fees ($0.05)<br>+ 5% × 800 voice (30s × $0.66) | **~$255/mois** | SN explose le coût |
| **Vonage Verify v2** | Estimation ~30% en moyenne moins cher que Twilio sur SN<br>(success fee $0.057 + ~$0.20 SN, ~$0.06 FR) | **~$120-160/mois** | Pricing exact à confirmer en dashboard |
| **Africa's Talking** (SN seul) | 30% × 920 = 276 SMS SN × $0.03 | **~$8/mois pour SN uniquement** | Combinable avec Firebase pour FR |
| **Hybride Firebase + A.T.** | FR via Firebase ($0.06 × 644 SMS – 300 free) + SN via A.T. ($0.03 × 276) | **~$29/mois** | 🏆 Économique mais double intégration |

### Scénario B — Croissance (8 000 / mois)

Hypothèse : **8 000 vérifications** / mois, mêmes ratios.

| Provider | Calcul | Coût mensuel |
|---|---|---|
| **Firebase Phone Auth** | 8 000 × 1.15 = 9 200 SMS – 300 free × $0.06 | **~$534/mois** |
| **Twilio Verify** | mêmes ratios × 10 | **~$2 550/mois** |
| **Vonage Verify v2** | mêmes ratios × 10 | **~$1 200-1 600/mois** |
| **Hybride Firebase + A.T.** | FR ($0.06 × 6 440 SMS – 300) + SN A.T. ($0.03 × 2 760) | **~$452/mois** |

### Scénario C — Scale (50 000 / mois)

Hypothèse : **50 000 vérifications** / mois, mêmes ratios.

| Provider | Coût mensuel | Note |
|---|---|---|
| **Firebase Phone Auth** | **~$3 350/mois** | Tarifs négociables au-delà via Identity Platform tiered |
| **Twilio Verify** | **~$16 000/mois** | Volume discounts attendus mais plancher SN haut |
| **Vonage Verify v2** | **~$7 500–10 000/mois** | Volume discounts négociables |
| **Hybride Firebase + A.T.** | **~$2 800/mois** | Reste champion économique |

---

## Tableau pivot — Coût par vérification (€/$ par vérif)

À 800/mois :

| Provider | $ / vérif moyen |
|---|---|
| Firebase | $0.046 |
| Twilio | $0.319 |
| Vonage | $0.150–0.200 |
| Hybride Firebase + A.T. | $0.036 |

À 8 000/mois (le free tier devient négligeable) :

| Provider | $ / vérif moyen |
|---|---|
| Firebase | $0.067 |
| Twilio | $0.319 |
| Vonage | $0.150–0.200 |
| Hybride Firebase + A.T. | $0.057 |

---

## Coûts annexes à ne pas oublier

### Firebase Cloud Functions (si on passe par un proxy)
- Invocations gratuites : 2 000 000/mois
- Au-delà : $0.40 / 1M invocations
- À 50k OTP/mois × 2 fonctions (send + verify) = 100k invocations → **0 €** (largement free tier)

### Firestore (si on stocke des codes générés)
- Reads/Writes : free tier 50k/jour
- À ne pas négliger si on build notre propre système Verify avec stockage des codes

### Onboarding admin
- **Twilio** : compliance fees A2P 10DLC US (~$5/mois pour brand registration), pas FR/SN.
- **Vonage** : déclaration Sender ID France gratuite, validation manuelle (3-5 jours).
- **Africa's Talking** : peuvent demander un Sender ID enregistré au SN (~$10-30 one-shot selon opérateur).

---

## Conclusions provisoires

1. **À volume MVP (<1k/mois), Firebase est de loin le moins cher** (~$30/mois) avec une solution clé-en-main.
2. **Twilio est ~7x plus cher que Firebase** au volume MVP, principalement à cause du SMS Sénégal à $0.55/message.
3. **L'hybride Firebase + Africa's Talking** est l'optimum théorique mais ajoute 1-2 semaines d'intégration et de complexité opérationnelle. **Pas recommandé pour le MVP.**
4. **Vonage** est l'alternative équilibrée : 3-4x Firebase mais avec voice fallback intégré et délivrabilité supérieure.

## Recommandation pour la phase 2 (à valider par tests réels)

| Question | Si la réponse est… | Choix |
|---|---|---|
| Firebase délivre-t-il bien au Sénégal ? | Oui | **Firebase Phone Auth seul** |
| Firebase délivre-t-il bien au Sénégal ? | Non, < 80% | **Vonage Verify v2** (voice fallback inclus) |
| As-tu besoin de voice fallback dès le lancement ? | Oui | **Vonage** ou **Twilio** |
| As-tu besoin de voice fallback dès le lancement ? | Non | **Firebase** (option moins chère) |

→ Le **test de délivrabilité réelle au Sénégal en Phase 3 est le facteur décisif**. Tout le reste (coût, code, voice) découle de ce résultat.
