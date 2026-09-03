# Plan: newsletter-signup

## Open questions

- None.

## Technical approach

- **Routing** (`routing-tanstack-router` skill): rendered from the existing `/` route
  (`src/routes/index.tsx`), no new route needed.
- **Server state** (`server-state-tanstack-query` skill): `useSuspenseQuery` for the
  subscriber count, `useMutation` for subscribing, both in `src/lib/queries.ts`, backed by
  MSW handlers in `src/mocks/handlers.ts` (`GET /api/subscribers`, `POST /api/subscribers`).
- **Client state** (`client-state-zustand` skill): dialog open/closed lives in `useUiStore`
  (`src/lib/store.ts`) — read by both the trigger button and the dialog.
- **Validation** (`forms-validation` skill): `subscribeSchema` in `src/lib/schemas.ts`, reused
  by both the submit-time client check and the mutation's `mutationFn`.
- **Component** (`component-conventions` skill): `SubscribeDialog` built on
  `@radix-ui/react-dialog` for focus trap / `aria-modal` correctness.

## Files to touch

- `src/lib/schemas.ts` — `subscribeSchema`, `subscriberCountSchema`
- `src/lib/store.ts` — `useUiStore` (dialog open state)
- `src/mocks/handlers.ts` — GET/POST `/api/subscribers`
- `src/lib/queries.ts` — `useSubscriberCount`, `useSubscribeMutation`
- `src/components/SubscribeDialog.tsx` — the dialog + form
- `src/routes/index.tsx` — renders the count + dialog

## Risks

- None — this is the template's own reference feature, built alongside the harness itself.
