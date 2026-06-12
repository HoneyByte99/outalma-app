# CLAUDE.md

Outalma is a mobile-first service marketplace MVP for France and Senegal. One account can operate in client mode and provider mode.

The first objective is simple: ship a clean, trustworthy MVP. Do not optimize for the full company vision yet. Build the shortest path to a robust product, then expand step by step.

## Core mission

Prioritize these outcomes:
- Reliable booking flow
- Trust and safety
- Strong mobile UX
- Clean architecture
- Fast iteration without chaos
- High confidence in critical logic

## MVP rule

When several options are possible, always prefer the one that:
1. ships the MVP sooner,
2. keeps the codebase clean,
3. preserves future scalability,
4. avoids unnecessary complexity.

## Canonical product scope

The MVP must support these end-to-end flows:
- Authentication
- Client/provider mode switching
- Provider onboarding basics
- Service listing and discovery
- Booking request lifecycle
- Accept/reject workflow
- Chat after acceptance
- Reviews after completion (bilateral — client rates provider, provider rates client)
- Basic notifications

Not in MVP unless explicitly requested:
- Full payments rollout
- AI features
- Advanced admin tooling
- Growth loops and referrals
- Premium subscriptions
- Fancy optimization before usage proves the need

## Execution mode

For any non-trivial task:
1. Inspect the current implementation.
2. Explain the current state briefly.
3. Propose a small implementation plan.
4. Implement in safe increments.
5. Run relevant validations.
6. Summarize what changed, risks, and next step.

For large changes, plan first. Do not jump straight into code.

## Architecture invariants

- domain/ stays pure Dart.
- data/ owns Firebase-specific details.
- application/ owns orchestration and state logic.
- features/ owns UI only.
- Critical booking transitions are server-authoritative.
- Firestore schema, Dart models, and Cloud Functions contracts must stay aligned.
- If TypeScript and Dart disagree, stop and align them before building more.

## Known gaps (audited 2026-06-12)

The original "critical known risks" list (model/enum mismatches, missing
repositories, no navigation, no notifications) is fully resolved. The current
prioritized gap inventory lives in docs/known-gaps.md — read it before starting
work on bookings, blocking, reviews, or notifications. Headlines:

- Provider mode has no view of done/cancelled/rejected bookings (router redirect
  blocks `/bookings`, which is already mode-aware) — also starves the
  provider→client review flow.
- Blocking is inconsistent: a blocked client can still book (and an accepted
  booking then gets an unusable chat), can still review, and stays discoverable.
- Moderation outcomes (service approve/reject) and received reviews trigger no
  notification; booking reminders have no deep-link.
- A service can be published without an active provider profile (no server check).

Keep docs/known-gaps.md current: remove items when fixed.

## Git autonomy

Claude has Git access and should work like an autonomous engineer.

Rules:
- Make small, logical commits.
- Keep commits reviewable.
- Do not mix unrelated concerns without reason.
- Summarize validation before proposing a commit or push.
- Use clear conventional commit messages.

## Definition of done

A task is not done until all relevant items are true:
- Correct layer boundaries are respected.
- If freezed is used, generated code is refreshed (currently: manual serialization, no generation).
- Relevant lint/analyze commands pass.
- Tests are added or updated for critical logic.
- Empty/loading/error states are handled for UI work.
- Documentation is updated when behavior or architecture changes.
- Remaining risks are stated clearly.

## Quality bar

### Design
The app should feel polished, deliberate, and launchable. Avoid generic scaffold-looking UI.

### Testing
Aim for 90% coverage on critical logic:
- domain rules
- booking lifecycle
- repositories
- Cloud Functions
- Riverpod notifiers / use cases

Broad UI coverage is secondary to strong business-logic confidence.

## Imports

@./.claude/rules/mvp-priority.md
@./.claude/rules/architecture-boundaries.md
@./.claude/rules/booking-invariants.md
@./.claude/rules/firebase-safety.md
@./.claude/rules/testing-bar.md
@./.claude/rules/git-autonomy.md
@./.claude/rules/design-bar.md
@./.claude/rules/flutterflow-usage.md
@./.claude/rules/docs-maintenance.md

## Reference docs

Use these as reference material when relevant:
- docs/PROJECT_SPEC.md — product decisions, Firestore schema, flows (source of truth)
- docs/domain-model-canonical.md — canonical models, field names, enums (align code here)
- docs/ARCHITECTURE.md — layer structure, patterns, naming conventions
- docs/mvp-roadmap.md — phased delivery plan with concrete tasks
- docs/known-gaps.md — prioritized inventory of open logic gaps (audited 2026-06-12)
- docs/release-readiness.md — launch checklist
- docs/flutterflow-migration.md — how to reuse the FlutterFlow reference app
