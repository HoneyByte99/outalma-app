# Build Report — 2026-05-24

## Statut

- `flutter analyze` : 13 warnings/infos (aucune erreur bloquante)
- `flutter test` : 635 tests passent (0 échec) — pas de fix nécessaire
- `pubspec.yaml` : déjà à `1.0.0+4` (bumpé dans le commit précédent `82d0d50`)
- `flutter build ipa --release` : archive Xcode créée, **export IPA échoué** (no signing certificate)

## Détails build

### Archive Xcode
- Path : `build/ios/archive/Runner.xcarchive`
- Créée à 01:25 le 2026-05-24
- Statut : compilation OK, archive complète

### Export IPA — échec
Erreur répétée pendant `xcodebuild -exportArchive` :
```
error: exportArchive No signing certificate "iOS Distribution" found
error: exportArchive No Accounts
```

Identités codesign disponibles dans le keychain :
- `Apple Development: amathba2@gmail.com (P7J5S74HBQ)` ← cert dev uniquement
- ❌ Aucun cert `Apple Distribution` / `iOS Distribution`

### IPA pré-existant
Un IPA traîne dans `build/ios/ipa/Outalma Service.ipa` (56 MB, daté 00:12).
- ⚠️ `codesign -dv` : **pas signé** (`code object is not signed at all`)
- `CFBundleVersion` : `7` (incohérent avec pubspec `+4` — probablement résidu d'un essai antérieur)
- **Inutilisable pour TestFlight en l'état.**

## Clés ASC

- ✅ Clé API trouvée : `~/.appstoreconnect/private_keys/AuthKey_KD833A3W9V.p8`
  - Key ID : `KD833A3W9V`
- ❌ Issuer ID introuvable (pas dans env, pas dans `.env`, pas dans le repo)

## Action requise (humain)

Le build ne peut pas être uploadé automatiquement. Deux blocages :
1. **Pas de cert Apple Distribution** dans le keychain local
2. **Issuer ID ASC manquant**

### Option A — Xcode (recommandé, plus rapide)
```bash
open /Users/amathba/clawd/projects/outalma/outalma-app/build/ios/archive/Runner.xcarchive
```
Puis dans Organizer : *Distribute App* → *App Store Connect* → *Upload*.
Xcode gérera signing + upload automatiquement (Apple ID `amathba2@gmail.com` doit avoir accès à l'équipe de distribution).

### Option B — CLI complète (après setup)
1. Télécharger le cert Apple Distribution depuis developer.apple.com et l'installer dans le keychain
2. Récupérer l'Issuer ID dans App Store Connect → Users and Access → Keys
3. Relancer :
   ```bash
   flutter build ipa --release
   xcrun altool --upload-app -f "build/ios/ipa/Outalma Service.ipa" \
       -t ios \
       --apiKey KD833A3W9V \
       --apiIssuer <ISSUER_ID>
   ```

### Option C — Transporter app
Si l'IPA est signé manuellement via Xcode (Option A jusqu'à l'export local), il peut être glissé dans l'app **Transporter** (Mac App Store).

## Notes

- Aucun commit nécessaire : pubspec déjà à `+4`, tests verts, code identique au commit `82d0d50`.
- Le fichier `Outalma Service.ipa` existant doit être **supprimé ou ignoré** — pas signé, version désynchronisée.
