// One-shot script — backfill addressSnapshot.lat / .lng on existing bookings.
//
// Iterates over every booking in Firestore. For bookings whose addressSnapshot
// has a non-empty `address` but no `lat`/`lng`, it geocodes the address text
// via the Google Maps Geocoding API and writes the coordinates back.
//
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json \
//   GEOCODING_API_KEY=AIza... \
//   node scripts/backfill_booking_coords.mjs [--dry-run]
//
// Requirements:
//   - Service-account JSON with read+write access to Firestore
//   - Google Maps API key with the "Geocoding API" enabled
//
// Notes:
//   - Bookings already containing lat/lng are skipped.
//   - Bookings without an addressSnapshot or with an empty address are skipped.
//   - On geocode failure (ZERO_RESULTS, OVER_QUERY_LIMIT, etc.) the booking is
//     skipped and the failure is logged. Re-run the script later to retry.
//   - Throttles to ~5 requests/second to stay well under Geocoding quotas.

import { readFileSync } from 'fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const dryRun = process.argv.includes('--dry-run');

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!keyPath) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json');
  process.exit(1);
}
const apiKey = process.env.GEOCODING_API_KEY;
if (!apiKey) {
  console.error('Set GEOCODING_API_KEY=<google-maps-geocoding-key>');
  process.exit(1);
}

const serviceAccount = JSON.parse(readFileSync(keyPath, 'utf8'));
initializeApp({ credential: cert(serviceAccount) });

const db = getFirestore();

async function geocode(address) {
  const url = new URL('https://maps.googleapis.com/maps/api/geocode/json');
  url.searchParams.set('address', address);
  url.searchParams.set('key', apiKey);
  url.searchParams.set('language', 'fr');

  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}`);
  }
  const json = await res.json();
  if (json.status !== 'OK' || !Array.isArray(json.results) || json.results.length === 0) {
    throw new Error(`status=${json.status}`);
  }
  const loc = json.results[0].geometry?.location;
  if (typeof loc?.lat !== 'number' || typeof loc?.lng !== 'number') {
    throw new Error('no location in response');
  }
  return { lat: loc.lat, lng: loc.lng };
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const snap = await db.collection('bookings').get();
  console.log(`Found ${snap.size} bookings total.`);

  let scanned = 0;
  let skipped = 0;
  let updated = 0;
  let failed = 0;

  for (const doc of snap.docs) {
    scanned += 1;
    const data = doc.data();
    const addressSnapshot = data.addressSnapshot;

    if (!addressSnapshot || typeof addressSnapshot !== 'object') {
      skipped += 1;
      continue;
    }
    const address = addressSnapshot.address;
    if (typeof address !== 'string' || address.trim().length === 0) {
      skipped += 1;
      continue;
    }
    if (
      typeof addressSnapshot.lat === 'number' &&
      typeof addressSnapshot.lng === 'number'
    ) {
      // Already has coords.
      skipped += 1;
      continue;
    }

    try {
      const { lat, lng } = await geocode(address);
      if (dryRun) {
        console.log(`[dry-run] ${doc.id} → ${address}  →  (${lat}, ${lng})`);
      } else {
        await doc.ref.update({
          'addressSnapshot.lat': lat,
          'addressSnapshot.lng': lng,
        });
        console.log(`✓ ${doc.id} → ${address}  →  (${lat}, ${lng})`);
      }
      updated += 1;
      // Stay under quota — ~5 req/s.
      await sleep(220);
    } catch (e) {
      failed += 1;
      console.warn(`✗ ${doc.id} (${address}): ${e.message}`);
    }
  }

  console.log('---');
  console.log(`Scanned: ${scanned}`);
  console.log(`Skipped: ${skipped}`);
  console.log(`Updated: ${updated}${dryRun ? ' (dry-run, nothing written)' : ''}`);
  console.log(`Failed:  ${failed}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
