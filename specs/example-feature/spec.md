# Spec: newsletter-signup

## Summary

A visitor on the home page can see the current subscriber count and subscribe with their
email address through a dialog, without leaving the page. This is the template's example
feature — a small but real vertical slice (route, server state, client state, validation,
an accessible dialog) that exercises the whole harness end to end.

## Acceptance criteria

- **EARS-1** (Event-driven): WHEN a visitor submits the subscribe form with a syntactically
  valid email address, THE system SHALL record the subscription, increment the displayed
  subscriber count, and close the dialog.
- **EARS-2** (Unwanted behaviour): IF a visitor submits the subscribe form with an invalid
  email address, THEN THE system SHALL show an accessible inline error message, SHALL NOT
  call the subscribe API, and SHALL keep the dialog open.

## Critical flows

- **Newsletter subscription (EARS-1)** — it is the only user-facing conversion flow in the
  example app, so it is marked `critical: true` and requires Playwright `@critical` coverage
  in addition to unit coverage (see `tests/e2e/subscribe.spec.ts`).

## Out of scope

- Persisting subscriptions anywhere real — `src/mocks/handlers.ts` (MSW) is the entire
  "backend" for this example, by design (SPEC.md §1 — the template ships no real backend).
- Unsubscribe flow, email confirmation, duplicate-email handling.
