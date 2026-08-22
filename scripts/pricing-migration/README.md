# Pricing migration (encadre pricing)

One-shot migration aligning `services` to the encadre pricing model: whole FCFA
(no cents), `fixed` -> `daily`, out-of-range prices clamped to the nearest
bound, `extraTasks` initialised, sentinel `pricingSchema: 2`. Design: archi
section 6. Acceptance: scenarios SC-32..SC-40.

## Why two passes

The cents and whole-FCFA populations overlap numerically, so no automatic unit
classification is safe (archi section 6.1). The script proposes and logs; a
human decides.

## Pass 1 - inventory (never writes)

```
node scripts/pricing-migration/migrate.js --pass=1 --out=./out
```

Produces `out/inventory.csv` (one row per document, with the proposed
convention and reason, the proposed price, and whether it would fall out of
range) and `out/summary.json`.

## Human checkpoint

Amath reviews `inventory.csv` and writes a classification file, one entry per
document id:

```json
{
  "seed_svc_29": "fcfa",
  "abc123appdoc": "cents"
}
```

Only `"fcfa"` and `"cents"` are accepted. Any document absent from the file is
left untouched and reported as `unclassified` (the script never guesses).

## Pass 2 - apply

Simulation by default (writes nothing), producing `journal.simulation.json`:

```
node scripts/pricing-migration/migrate.js --pass=2 \
  --classification=./out/classification.json --out=./out
```

For real, with the explicit `--apply` flag, producing `journal.apply.json` and
mutating Firestore:

```
node scripts/pricing-migration/migrate.js --pass=2 \
  --classification=./out/classification.json --out=./out --apply
```

The two journals are identical except for the `mode` marker (SC-32). A document
already at `pricingSchema: 2` is skipped, so an interrupted run is safe to
relaunch (SC-38/40).

## Credentials

`GOOGLE_APPLICATION_CREDENTIALS`, or `scripts/service-account.json`. Against the
Firestore emulator (SCRIPT acceptance scenarios), set `FIRESTORE_EMULATOR_HOST`.

## Deployment order (archi section 7, non-negotiable)

1. Create `config/pricing` in production.
2. Run this migration (pass 1, review, pass 2 apply).
3. Deploy `firestore.rules`.
4. Publish the app version.

## Tests

Pure decision core (no emulator):

```
node --test scripts/pricing-migration/core.test.js
```
