# Spec: article-like-button

## Summary

This feature adds a "Curtir" button to the article view so readers can register appreciation for the content by increasing a visible like counter. The goal is to provide a lightweight interaction that is easy to understand, accessible, and immediately visible to the user without leaving the article page.

## Acceptance criteria

- **EARS-1** (Event-driven): WHEN a visitor clicks the "Curtir" button on an article, THE system SHALL increment the article's like counter by one and update the displayed count immediately.
- **EARS-2** (State-driven): WHILE the article is loaded and the counter is available, THE system SHALL render the current like count beside the "Curtir" button using the latest known value.
- **EARS-3** (Unwanted behaviour): IF the like counter has not been initialized yet, THEN THE system SHALL show the default value as 0 instead of leaving the count blank, undefined, or invalid.
- **EARS-4** (Optional feature): IF the article view is rendered on a page that does not support likes, THEN THE system SHALL hide or disable the "Curtir" control without breaking the rest of the article layout.

## Critical flows

- None.

## Out of scope

- Creating a user account, authentication, or authorization flow for likes.
- Allowing users to unlike, undo, or toggle a like after it has been counted.
- Persisting likes in a real backend or database; this feature is limited to the in-memory UI state in the current app.
- Styling the article page beyond the like button and counter placement required for this feature.
- Analytics, social-sharing, or notifications triggered by likes.
