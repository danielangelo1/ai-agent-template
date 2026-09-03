# Tasks: newsletter-signup

- [x] **T1** — Subscribe with a valid email
  - Covers: EARS-1
  - critical: true
  - Test: `tests/unit/subscribe-dialog.test.tsx` (unit) + `tests/e2e/subscribe.spec.ts` (e2e,
    `@critical`)

- [x] **T2** — Reject an invalid email without calling the API
  - Covers: EARS-2
  - critical: false
  - Test: `tests/unit/subscribe-dialog.test.tsx`

All tasks GREEN — `scripts/verify.sh` exits 0 for this feature (see repository root for the
full pyramid run). This file was completed by walking through the same RED→GREEN sequence
`/implement` automates, while the harness itself was being built (roadmap step 11).
