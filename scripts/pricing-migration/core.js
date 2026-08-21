/**
 * Pure, side-effect-free core of the encadre-pricing migration.
 *
 * These functions carry the whole decision logic (unit convention proposal,
 * conversion, priceType rewrite, clamping to the grid) with no Firestore and
 * no I/O, so they are unit-testable directly (grille de budgets T4) and shared
 * by both passes of migrate.js. See archi section 6 and the acceptance
 * scenarios SC-32..SC-40.
 *
 * The migration NEVER auto-classifies a document's unit convention (archi
 * section 6.1: the cents and whole-FCFA populations overlap numerically).
 * proposeConvention() only produces a *proposal with a reason* for the pass-1
 * inventory; pass 2 applies the human-reviewed classification file, not the
 * proposal.
 */

'use strict';

/**
 * Effective ceiling, in whole FCFA, mirroring EXACTLY the integer arithmetic of
 * firestore.rules and the Dart cap(): max * (100 + bonus*n) / 100, truncated.
 */
function capFor(max, bonusPercent, extraCount) {
  return Math.floor((max * (100 + bonusPercent * extraCount)) / 100);
}

/**
 * Proposes a unit convention for the pass-1 inventory only. Deterministic, and
 * honest about ambiguity rather than guessing on client prices.
 *
 * - `_seeded` present  -> 'fcfa'      (the Python seed writes whole FCFA)
 * - price not a multiple of 100 -> 'fcfa' (cents are always FCFA*100, i.e. a
 *   multiple of 100; app-written cents can never land here)
 * - otherwise          -> 'ambiguous' (multiple of 100 fits both populations;
 *   archi section 6.1: no automatic rule is safe here)
 *
 * @returns {{convention: 'fcfa'|'ambiguous', reason: string}}
 */
function proposeConvention(doc) {
  if (doc._seeded === true) {
    return { convention: 'fcfa', reason: 'seeded_marker' };
  }
  const price = doc.price;
  if (typeof price === 'number' && Number.isFinite(price) && price % 100 !== 0) {
    return { convention: 'fcfa', reason: 'not_multiple_of_100' };
  }
  return { convention: 'ambiguous', reason: 'multiple_of_100_overlap' };
}

/**
 * Converts a stored price to whole FCFA given the (human-decided) convention.
 * 'cents' divides by 100 (integer); 'fcfa' is already whole FCFA.
 */
function toWholeFcfa(price, convention) {
  if (convention === 'cents') {
    return Math.trunc(price / 100);
  }
  return price;
}

/**
 * Rewrites the legacy `fixed` mode to `daily` (spec decision 11). Any other
 * mode is returned unchanged.
 */
function migratePriceType(priceType) {
  return priceType === 'fixed' ? 'daily' : priceType;
}

/**
 * Clamps a whole-FCFA price to the mode's bounds for a launch category
 * (spec decision 7: bring an out-of-range price to the nearest bound). The
 * five non-launch categories are never clamped (archi section 6.3).
 *
 * @param {number} price whole FCFA
 * @param {string} mode 'hourly'|'daily'|'monthly'
 * @param {number} extraCount number of extra tasks (0 for a fresh migration)
 * @param {object} config the config/pricing grid
 * @param {boolean} isBounded whether the category is in config.boundedCategories
 * @returns {{value: number, reason: string|null}}
 */
function clampToBounds(price, mode, extraCount, config, isBounded) {
  if (!isBounded) return { value: price, reason: null };
  const b = config.modes[mode];
  if (!b) return { value: price, reason: null };
  if (price < b.min) return { value: b.min, reason: 'raised_to_floor' };
  const cap = capFor(b.max, b.extraBonusPercent || 0, extraCount);
  if (price > cap) return { value: cap, reason: 'clamped_to_ceiling' };
  return { value: price, reason: null };
}

/**
 * Computes the full migration plan for one document, given its human-decided
 * convention. Pure: returns the target fields plus a machine-readable journal
 * of every change (id, field, old, new, reason). A document already at
 * pricingSchema 2 is reported as skipped (idempotence, archi section 6.2).
 *
 * @param {object} doc the raw Firestore document data, plus an `id`
 * @param {'fcfa'|'cents'} convention
 * @param {object} config the config/pricing grid
 * @returns {{skipped: boolean, changes: object, journal: Array}}
 */
function planDocument(doc, convention, config) {
  const journal = [];
  if (doc.pricingSchema === 2) {
    return {
      skipped: true,
      changes: {},
      journal: [{ id: doc.id, field: null, old: null, new: null, reason: 'already_migrated' }],
    };
  }

  const isBounded = (config.boundedCategories || []).includes(doc.categoryId);
  const changes = {};

  // 1. Unit conversion.
  const oldPrice = doc.price;
  let price = toWholeFcfa(oldPrice, convention);
  if (price !== oldPrice) {
    journal.push({ id: doc.id, field: 'price', old: oldPrice, new: price, reason: 'unit_conversion' });
  }

  // 2. priceType: fixed -> daily.
  const newType = migratePriceType(doc.priceType);
  if (newType !== doc.priceType) {
    changes.priceType = newType;
    journal.push({ id: doc.id, field: 'priceType', old: doc.priceType, new: newType, reason: 'price_type_fixed_to_daily' });
  }

  // 3. extraTasks initialised to the empty list when absent.
  if (!Array.isArray(doc.extraTasks)) {
    changes.extraTasks = [];
    journal.push({ id: doc.id, field: 'extraTasks', old: doc.extraTasks ?? null, new: [], reason: 'extra_tasks_init' });
  }

  // 4. Clamp to the nearest bound (launch categories only), on the final unit
  //    and mode, with zero extra tasks.
  const clamp = clampToBounds(price, newType, 0, config, isBounded);
  if (clamp.reason) {
    journal.push({ id: doc.id, field: 'price', old: price, new: clamp.value, reason: clamp.reason });
    price = clamp.value;
  }

  if (price !== oldPrice) changes.price = price;
  // The sentinel is always stamped so a re-run recognises the document.
  changes.pricingSchema = 2;

  return { skipped: false, changes, journal };
}

module.exports = {
  capFor,
  proposeConvention,
  toWholeFcfa,
  migratePriceType,
  clampToBounds,
  planDocument,
};
