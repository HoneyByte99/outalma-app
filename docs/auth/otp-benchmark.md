# OTP Provider Benchmark — Phase 1 (Desk Research)

> **Date** : mai 2026
> **Auteur** : équipe Outalma
> **Statut** : phase 1/5 du benchmark — recherche desk uniquement, à compléter par tests réels (phase 2-3).

## Contexte

Outalma a besoin d'un service d'envoi de codes OTP pour :
1. **Vérifier le numéro** à l'inscription (preuve de propriété du téléphone)
2. **Connexion par téléphone** (alternative à email/password, sans mot de passe à retenir)

### Contraintes
- **Plateformes** : iOS + Android + **Web** (les 3 obligatoires)
- **Marchés** : France + Sénégal
- **Canaux** : SMS principal, Voice en fallback
- **Volume estimé** : < 1 000 OTP/mois sur 6-12 mois, projection 8-10k/mois à 24 mois
- **Backbone auth** : Firebase Auth — on garde, on ne migre pas

---

## Comparatif synthétique

| Provider | Free tier | Prix FR /vérif | Prix SN /vérif | Voice fallback | Web friction | Intégration Firebase |
|---|---|---|---|---|---|---|
| **A. Firebase Phone Auth** | 10 SMS/jour (~300/mois) | $0.06 | $0.06 | ❌ | ⚠️ reCAPTCHA visible | ✅ Native |
| **B. Twilio Verify** | $15 trial credit | ~$0.13 | ~$0.60 | ✅ | ✅ | ⚙️ Custom token via Cloud Function |
| **C. Vonage Verify v2** | €2 trial credit | ~$0.06–0.10 | ~$0.20–0.30 | ✅ Built-in | ✅ | ⚙️ Custom token via Cloud Function |
| **D. Africa's Talking** | Sandbox gratuit | N/A (pas marché core) | ~$0.02–0.04 | ✅ | ✅ | ⚙️ Custom token via Cloud Function |

> Les prix exacts pour le Sénégal sont indicatifs et à valider en console (FX, frais opérateurs locaux). **Pour Africa's Talking**, le tarif SN précis n'est accessible qu'après inscription au dashboard.

---

## Fiche A — Firebase Phone Auth

### Description
Phone Authentication intégré nativement à Firebase Auth. Utilise `verifyPhoneNumber()` côté client. Le SMS part directement depuis l'infra Google.

### Tarifs (mai 2026)
- **Free tier** : 10 SMS gratuits par jour (~300/mois). _Source : Firebase Phone Number Verification pricing._
- **Au-delà** : $0.01/SMS pour US, Canada, Inde — **$0.06/SMS pour le reste du monde** (incluant FR et SN).
- **Pas de modèle pay-per-success** : chaque SMS envoyé est facturé, même si l'utilisateur n'entre jamais le code.
- Aucun frais voice puisque la fonctionnalité n'existe pas.

### Forces
- ✅ Déjà partiellement scaffoldé dans le code (`phone_otp_service_stub.dart`).
- ✅ SDK Flutter officiel — un seul package, support iOS/Android/Web.
- ✅ Le retour direct de credentials Firebase (pas de glue à écrire).
- ✅ Auto-retrieval Android (le code se remplit tout seul depuis le SMS).
- ✅ Free tier suffisant pour tout le MVP.

### Faiblesses
- ❌ **Web : reCAPTCHA visible obligatoire** depuis la mise à jour Firebase 2024 (avant : invisible). Friction UX significative sur web.
- ❌ **Pas de Voice fallback** — quand le SMS ne passe pas, l'utilisateur est bloqué.
- ⚠️ Configuration iOS lourde depuis 2024 : APNs key requis, App Attest pour la prod, certificats à gérer.
- ⚠️ Délivrabilité Sénégal **inégale selon les opérateurs** (retours communauté Firebase) — Google sous-traite à des partenaires, pas de connexion directe avec Orange SN ou Free SN.
- ⚠️ Pas de stats de délivrabilité par opérateur dans la console.

### Use case idéal
Volume modeste, marché majoritaire FR/EU, pas besoin de voice fallback, web non critique.

---

## Fiche B — Twilio Verify

### Description
API dédiée à l'OTP / multi-factor. Channels : SMS, Voice, WhatsApp, Email, Push, TOTP. Pas de SDK Flutter officiel, mais REST API bien documentée. Le pattern : on appelle Twilio depuis une **Cloud Function** Firebase qui retourne ensuite un **custom token** au client.

### Tarifs (mai 2026)
- **Verify base fee** : $0.05 / vérification réussie (peu importe le canal).
- **+ Channel fees** :
  - SMS France : $0.0798/SMS → **~$0.13/vérif**
  - SMS Sénégal : $0.5506/SMS → **~$0.60/vérif** (très cher)
  - Voice mobile Sénégal : $0.6581/min → **~$0.38/vérif** pour un appel de 30s
  - WhatsApp authentication template : ~$0.0034/message (US, à confirmer FR/SN)
- **Trial credit** : ~$15 à l'inscription
- Échecs = SMS quand même envoyé = facturé (le base fee $0.05 est seul "per success")

### Forces
- ✅ **Délivrabilité référence** mondiale, dont Sénégal (relations carriers solides).
- ✅ **Voice fallback** intégré (un appel de TTS dicte le code).
- ✅ Doc et DX excellents.
- ✅ Multi-channel future-proof (WhatsApp, Email si besoin plus tard).
- ✅ Status page + monitoring carrier-level.

### Faiblesses
- ❌ **Senegal très cher** : ~$0.60/vérif. À 800/mois × 30% SN = ~$144/mois rien que pour SN.
- ⚠️ Pas de SDK Flutter officiel — coding maison via HTTP + Cloud Function.
- ⚠️ Onboarding compliance (Toll-Free numbers, A2P 10DLC pour US, registrations FR) — lourdeur admin.

### Use case idéal
Volume conséquent, exigence de délivrabilité maximale, marché développé, voice fallback critique, budget pas un blocker.

---

## Fiche C — Vonage Verify v2

### Description
API Verify v2 avec modèle **"conversion-based"** : on paie au succès. Workflow multi-canaux configurable (essayer SMS puis Voice puis WhatsApp). Authentification dans une seule API.

### Tarifs (mai 2026)
- **Verify v2 success fee** : $0.0572 (€0.052) par vérification réussie.
- **+ Channel fees par tentative** (SMS / TTS / WhatsApp / Email / Silent Auth), basés sur la destination.
  - SMS France : ~$0.06/message (pricing similaire à Twilio)
  - SMS Sénégal : ~$0.15–0.25/message (généralement moins cher que Twilio mais à confirmer en dashboard)
- **Pricing per destination** : que tu utilises 1 ou 3 canaux pour le même utilisateur, le success fee reste fixe ; seuls les channel attempts s'ajoutent.
- **Trial credit** : ~€2 (modeste).
- **Silent Authentication** disponible (vérif via opérateur sans SMS) — révolutionnaire mais couverture limitée hors Europe.

### Forces
- ✅ **Voice fallback automatique** dans le workflow Verify (on configure : tente SMS, si pas de réponse en X secondes → bascule en Voice).
- ✅ **Modèle "pay per success"** — tentatives qui ne se transforment pas (utilisateur abandonne) → moins facturé que Twilio.
- ✅ Pricing plus bas que Twilio sur l'Afrique en général.
- ✅ Doc claire, support correct.
- ✅ Silent Authentication (vérification carrier sans SMS visible) — feature tueuse si elle marche au SN/FR.

### Faiblesses
- ⚠️ Pas de SDK Flutter officiel — REST + Cloud Function comme Twilio.
- ⚠️ Couverture SN bonne mais pas autant que Twilio (différence à mesurer en tests réels).
- ⚠️ Le pricing "complet" demande une console pour voir les channel fees exact par pays.
- ⚠️ Silent Auth pas dispo au Sénégal (vérifier).

### Use case idéal
Marché mixte Europe/Afrique, voice fallback important, budget plus tendu que Twilio, on accepte de coder un peu.

---

## Fiche D — Africa's Talking

### Description
Provider focalisé sur l'Afrique avec connexions directes aux carriers (Orange SN, Free SN, Expresso, etc.). API REST simple, SDKs dans plusieurs langages (pas Dart officiel). Leur grande valeur : **prix locaux et délivrabilité africaine inégalée**.

### Tarifs (mai 2026)
- **Sénégal** : ~$0.02–0.04 / SMS (à confirmer après création de compte, prix non publics).
- **France** : pas leur marché core ; on peut envoyer mais à des tarifs internationaux non compétitifs.
- **Voice** : disponible aux mêmes tarifs locaux compétitifs au SN.
- **Sandbox gratuit** pour tester.
- **Pas de modèle Verify/per-success** : on paie chaque SMS/appel.

### Forces
- ✅ **Sénégal optimisé** : connexions carriers directes, délivrabilité top, prix imbattables.
- ✅ Voice à prix raisonnables au SN.
- ✅ Support local en français.
- ✅ Pas de reCAPTCHA, on contrôle le UX entièrement.

### Faiblesses
- ❌ **Pas adapté pour la France** : routes internationales chères, pas leur core business.
- ❌ Pas d'API "Verify" packagée — il faut générer le code, le stocker (Redis/Firestore TTL), comparer soi-même. Plus de code à écrire.
- ❌ Compliance/onboarding moins automatisé qu'avec Twilio/Vonage.
- ⚠️ Stratégie hybride nécessaire (A.T. pour SN + autre provider pour FR) → double intégration.

### Use case idéal
- App focalisée 90% Afrique → A.T. seul.
- Outalma 50/50 FR/SN → A.T. uniquement comme **provider secondaire pour le SN**, en routing intelligent.

---

## Tableau de scoring desk

Pondération : couverture SN ×3, Firebase int. ×2, coût ×2, voice ×1, web UX ×2, latence ×2, DX ×1.
Notes 1 à 5 (5 = excellent). À compléter avec tests réels en Phase 2-3.

| Critère | Pond. | Firebase | Twilio | Vonage | Africa's Talking |
|---|---|---|---|---|---|
| Couverture FR + SN (présumée) | 3 | 3 (SN incertain) | **5** | 4 | 4 (SN excellent, FR faible) |
| Multi-plateforme natif | 2 | **5** | 3 (REST) | 3 (REST) | 3 (REST) |
| Voice fallback | 1 | 1 (absent) | **5** | **5** | 4 (à coder soi-même) |
| Coût (FR + SN à 800/mois) | 2 | **5** (free tier) | 2 (cher SN) | 4 | **5** (SN cheap) |
| Intégration Firebase Auth | 2 | **5** (native) | 3 (custom token) | 3 (custom token) | 3 (custom token) |
| Web UX (sans reCAPTCHA) | 2 | 2 (reCAPTCHA visible) | **5** | **5** | **5** |
| Latence/DX | 2 | 4 | **5** | 4 | 3 |
| **Total pondéré** | | **51** | **52** | **47** | **48** |

### Lecture du tableau
- **Firebase et Twilio sont au coude à coude** sur le scoring desk.
- **Firebase gagne sur le coût et l'intégration**, perd sur Voice et Web UX.
- **Twilio gagne sur la couverture, voice et web**, perd sur le coût SN et l'intégration.
- **Vonage** est l'option équilibrée mais pas leader.
- **Africa's Talking** seul pour FR+SN n'est pas viable, mais en complément il devient pertinent.

---

## Hypothèse de stratégie (à valider en Phase 2-3)

Trois scénarios possibles selon les résultats des tests réels :

### Scénario 1 — Firebase suffit (le plus probable au stade MVP)
- Firebase Phone Auth pour les 3 plateformes.
- Web : on accepte le reCAPTCHA visible (un mal pour un bien).
- Voice fallback : pas critique au lancement, on ajoute plus tard si besoin.
- **Coût mensuel estimé** : $0 jusqu'à 300/mois, puis $0.06 × ~500 = **~$30/mois** à 800/mois.

### Scénario 2 — Hybride Firebase + Twilio Voice
- Firebase pour SMS principal (tous les marchés).
- Twilio Voice **uniquement** comme fallback "Renvoyer par appel" si l'utilisateur clique après timeout.
- Cloud Function `requestVoiceFallback` qui appelle Twilio Voice → custom token Firebase à la fin.
- **Coût** : Firebase ~$30 + Twilio voice estimé ~$5-10/mois si 5% des users tombent en fallback.

### Scénario 3 — Vonage en remplacement total
- Si la délivrabilité Firebase au SN est mauvaise en tests réels et que Vonage tient ses promesses.
- Cloud Function unique `sendOtp` + `verifyOtp` côté Vonage → custom token.
- Voice intégré dans le workflow Verify v2.
- **Coût** : ~$50–80/mois à 800 vérifs.

---

## Prochaines étapes

| Phase | Livrable | Effort |
|---|---|---|
| **2. Spike technique** | Cloud Functions de test + écran Flutter `_otp_lab/` testant Firebase + Twilio | 2-3 jours |
| **3. Délivrabilité réelle** | Tests SMS/Voice sur 3 numéros FR (Orange, SFR, Free) + 3 numéros SN (Orange, Free, Expresso) | 1 jour étalé |
| **4. Coût** | Simulation détaillée à 800/mois et 8 000/mois | ½ jour |
| **5. Décision** | Choix final + plan d'implémentation séparé | ½ jour |

## Sources

- [Firebase Auth Pricing 2026 (Metacto)](https://www.metacto.com/blogs/the-complete-guide-to-firebase-auth-costs-setup-integration-and-maintenance)
- [Firebase Phone Number Verification pricing](https://firebase.google.com/docs/phone-number-verification/pricing)
- [Identity Platform pricing — Google Cloud](https://cloud.google.com/identity-platform/pricing)
- [Twilio Verify Pricing](https://www.twilio.com/en-us/verify/pricing)
- [Twilio SMS Pricing — Senegal](https://www.twilio.com/en-us/sms/pricing/sn)
- [Twilio SMS Pricing — France](https://www.twilio.com/en-us/sms/pricing/fr)
- [Twilio Voice Pricing — Senegal](https://www.twilio.com/voice/pricing/sn)
- [Vonage Verify API pricing](https://www.vonage.com/communications-apis/verify/pricing/)
- [Vonage Verify V2 charges (support)](https://api.support.vonage.com/hc/en-us/articles/14842100202268-What-are-the-charges-for-using-Verify-API-V2)
- [Africa's Talking Pricing](https://africastalking.com/pricing)

## Risques / notes

- Tous les prix sont **indicatifs mai 2026**. À reverifier en console au moment de l'implémentation.
- Le pricing "real-world" SN dépend des accords carrier — un même provider peut changer ses tarifs sans notice. Prévoir un suivi mensuel des coûts.
- Apple a tightened les règles Phone Auth en 2024 — si on retient Firebase, **valider tôt** que la config APNs + App Attest est OK avant submission App Store.
