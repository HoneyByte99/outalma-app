'use strict';

// Unit tests for the pure migration core (no emulator, no Firestore).
// Run: node --test scripts/pricing-migration/core.test.js
// Covers the T4 core of scenarios SC-33..SC-38: unit conversion, fixed->daily,
// clamp to nearest bound, extraTasks init, idempotence sentinel, and the
// pass-1 convention proposal.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  capFor,
  proposeConvention,
  toWholeFcfa,
  migratePriceType,
  clampToBounds,
  planDocument,
} = require('./core');

const CONFIG = {
  boundedCategories: ['menage', 'cuisine', 'gardeEnfants', 'repassage'],
  maxExtraTasks: 3,
  modes: {
    hourly: { min: 1000, max: 3500, extraBonusPercent: 25 },
    daily: { min: 2000, max: 10000, extraBonusPercent: 25 },
    monthly: { min: 50000, max: 150000, extraBonusPercent: 0, isRange: true },
  },
};

test('capFor matches the integer ceiling formula', () => {
  assert.equal(capFor(3500, 25, 0), 3500);
  assert.equal(capFor(3500, 25, 1), 4375);
  assert.equal(capFor(3500, 25, 3), 6125);
  assert.equal(capFor(10000, 25, 3), 17500);
});

test('proposeConvention: seeded marker -> fcfa', () => {
  assert.deepEqual(proposeConvention({ _seeded: true, price: 15000 }), {
    convention: 'fcfa',
    reason: 'seeded_marker',
  });
});

test('proposeConvention: non-multiple of 100 -> fcfa', () => {
  assert.equal(proposeConvention({ price: 1250 }).convention, 'fcfa');
});

test('proposeConvention: multiple of 100 is ambiguous (overlap)', () => {
  assert.equal(proposeConvention({ price: 250000 }).convention, 'ambiguous');
  assert.equal(proposeConvention({ price: 2500 }).convention, 'ambiguous');
});

test('toWholeFcfa converts cents, leaves fcfa', () => {
  assert.equal(toWholeFcfa(250000, 'cents'), 2500);
  assert.equal(toWholeFcfa(15000, 'fcfa'), 15000);
});

test('migratePriceType rewrites fixed to daily only', () => {
  assert.equal(migratePriceType('fixed'), 'daily');
  assert.equal(migratePriceType('hourly'), 'hourly');
  assert.equal(migratePriceType('monthly'), 'monthly');
});

test('clampToBounds raises below floor, caps above ceiling (SC-36)', () => {
  assert.deepEqual(clampToBounds(1000, 'hourly', 0, CONFIG, true), {
    value: 1000,
    reason: null,
  });
  assert.deepEqual(clampToBounds(500, 'hourly', 0, CONFIG, true), {
    value: 1000,
    reason: 'raised_to_floor',
  });
  assert.deepEqual(clampToBounds(15000, 'daily', 0, CONFIG, true), {
    value: 10000,
    reason: 'clamped_to_ceiling',
  });
});

test('clampToBounds never touches non-launch categories (archi 6.3)', () => {
  assert.deepEqual(clampToBounds(90000000, 'daily', 0, CONFIG, false), {
    value: 90000000,
    reason: null,
  });
});

test('planDocument: seeded fixed 15000 -> daily 10000 clamp (SC-33)', () => {
  const plan = planDocument(
    { id: 'seed_svc_29', _seeded: true, categoryId: 'menage', priceType: 'fixed', price: 15000 },
    'fcfa',
    CONFIG,
  );
  assert.equal(plan.skipped, false);
  assert.equal(plan.changes.priceType, 'daily');
  assert.equal(plan.changes.price, 10000);
  assert.deepEqual(plan.changes.extraTasks, []);
  assert.equal(plan.changes.pricingSchema, 2);
  const reasons = plan.journal.map((j) => j.reason);
  assert.ok(reasons.includes('price_type_fixed_to_daily'));
  assert.ok(reasons.includes('clamped_to_ceiling'));
});

test('planDocument: app cents 250000 -> 2500, price unchanged display (SC-34)', () => {
  const plan = planDocument(
    { id: 'fx-app', categoryId: 'menage', priceType: 'hourly', price: 250000 },
    'cents',
    CONFIG,
  );
  assert.equal(plan.changes.price, 2500);
  const reasons = plan.journal.map((j) => j.reason);
  assert.ok(reasons.includes('unit_conversion'));
});

test('planDocument: app-low 50000 cents (500 F) raised to 1000 floor', () => {
  const plan = planDocument(
    { id: 'fx-app-low', categoryId: 'menage', priceType: 'hourly', price: 50000 },
    'cents',
    CONFIG,
  );
  assert.equal(plan.changes.price, 1000);
  const reasons = plan.journal.map((j) => j.reason);
  assert.ok(reasons.includes('unit_conversion'));
  assert.ok(reasons.includes('raised_to_floor'));
});

test('planDocument: plomberie fixed cents -> daily, no clamp (non-launch)', () => {
  const plan = planDocument(
    { id: 'fx-plomberie', categoryId: 'plomberie', priceType: 'fixed', price: 4000000 },
    'cents',
    CONFIG,
  );
  assert.equal(plan.changes.priceType, 'daily');
  assert.equal(plan.changes.price, 40000);
  const reasons = plan.journal.map((j) => j.reason);
  assert.ok(!reasons.includes('clamped_to_ceiling'));
  assert.ok(!reasons.includes('raised_to_floor'));
});

test('planDocument: in-range hourly seed is only stamped, value unchanged', () => {
  const plan = planDocument(
    { id: 'fx-seed-py-inrange', _seeded: true, categoryId: 'menage', priceType: 'hourly', price: 3500, extraTasks: [] },
    'fcfa',
    CONFIG,
  );
  assert.equal(plan.changes.price, undefined); // unchanged
  assert.equal(plan.changes.pricingSchema, 2);
});

test('planDocument is idempotent: pricingSchema 2 is skipped (SC-38)', () => {
  const plan = planDocument(
    { id: 'already', categoryId: 'menage', priceType: 'daily', price: 5000, pricingSchema: 2 },
    'fcfa',
    CONFIG,
  );
  assert.equal(plan.skipped, true);
  assert.deepEqual(Object.keys(plan.changes), []);
  assert.equal(plan.journal[0].reason, 'already_migrated');
});
